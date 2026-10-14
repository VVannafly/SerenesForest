import SerenesParsing
import Foundation
import SwiftUI
import SwiftData
import ImageIO

final class ArticleThumbnail: NSObject {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

enum ArticleThumbnailCache {
    static let images: NSCache<NSString, ArticleThumbnail> = {
        let cache = NSCache<NSString, ArticleThumbnail>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()
}

actor ArticleDecodeLimiter {
    static let shared = ArticleDecodeLimiter()
    private var active = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if active < 3 {
            active += 1
        } else {
            await withCheckedContinuation { waiting.append($0) }
        }
    }

    func release() {
        if waiting.isEmpty {
            active -= 1
        } else {
            waiting.removeFirst().resume()
        }
    }
}

actor ArticleDownloadLimiter {
    static let shared = ArticleDownloadLimiter()
    private var active = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if active < 3 { active += 1 }
        else { await withCheckedContinuation { waiting.append($0) } }
    }

    func release() {
        if waiting.isEmpty { active -= 1 }
        else { waiting.removeFirst().resume() }
    }
}

actor LocalImageLoader {
    static let shared = LocalImageLoader()
    private struct Flight {
        let task: Task<CGImage?, Never>
        var waiters: Set<UUID>
    }
    private var inFlight: [String: Flight] = [:]
    private var failedDownloads: [String: Date] = [:]

    func assetImage(assetURL: String, fetchedAt: Date, maxPixelSize: Int, container: ModelContainer) async -> CGImage? {
        let key = "asset:\(assetURL)|\(fetchedAt.timeIntervalSinceReferenceDate)|\(maxPixelSize)"
        return await load(key: key) {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<ContentAsset>(predicate: #Predicate { $0.url == assetURL })
            guard let data = try? context.fetch(descriptor).first?.data,
                  !Task.isCancelled,
                  let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
            else { return nil }
            return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary)
        }
    }

    func missingAssetImage(assetURL: String, maxPixelSize: Int, container: ModelContainer) async -> CGImage? {
        guard let url = URL(string: assetURL), SiteScope.canonical(url) != nil,
              SiteScope.isAsset(url),
              failedDownloads[assetURL].map({ Date.now.timeIntervalSince($0) > 3600 }) ?? true else { return nil }
        return await loadRemote(key: "remote:\(assetURL)|\(maxPixelSize)", assetURL: assetURL) {
            await ArticleDownloadLimiter.shared.acquire()
            defer { Task { await ArticleDownloadLimiter.shared.release() } }
            guard !Task.isCancelled else { return nil }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 15
                let (file, response) = try await URLSession.shared.download(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let mime = response.mimeType, mime.hasPrefix("image/"),
                      let size = (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.int64Value,
                      size > 0, size <= 20_000_000 else { return nil }
                let data = try Data(contentsOf: file, options: .mappedIfSafe)
                guard let source = CGImageSourceCreateWithData(data as CFData,
                    [kCGImageSourceShouldCache: false] as CFDictionary),
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                        kCGImageSourceShouldCacheImmediately: true
                      ] as CFDictionary) else { return nil }
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<ContentAsset>(predicate: #Predicate { $0.url == assetURL })
                let asset: ContentAsset
                if let existing = try context.fetch(descriptor).first {
                    asset = existing
                } else {
                    asset = ContentAsset(url: assetURL, title: url.lastPathComponent, sourcePageURL: "")
                    context.insert(asset)
                }
                asset.data = data
                asset.mimeType = mime
                asset.fetchedAt = .now
                asset.lastAttempt = .now
                asset.lastError = nil
                try context.save()
                return image
            } catch {
                return nil
            }
        }
    }

    private func loadRemote(key: String, assetURL: String,
                            fetch: @escaping @Sendable () async -> CGImage?) async -> CGImage? {
        let cacheKey = key as NSString
        if let cached = ArticleThumbnailCache.images.object(forKey: cacheKey) { return cached.image }
        guard !Task.isCancelled else { return nil }
        let token = UUID()
        let task: Task<CGImage?, Never>
        if var running = inFlight[key] {
            running.waiters.insert(token)
            inFlight[key] = running
            task = running.task
        } else {
            task = Task.detached(priority: .utility) { await fetch() }
            inFlight[key] = Flight(task: task, waiters: [token])
        }
        let image = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            Task { await self.drop(key: key, token: token) }
        }
        if let image, !Task.isCancelled {
            ArticleThumbnailCache.images.setObject(ArticleThumbnail(image), forKey: cacheKey,
                                                   cost: image.bytesPerRow * image.height)
        } else if !Task.isCancelled {
            failedDownloads[assetURL] = .now
        }
        drop(key: key, token: token)
        return image
    }

    func bundleImage(named name: String, maxPixelSize: Int) async -> CGImage? {
        guard let url = ["jpg", "png"].compactMap({
            Bundle.main.url(forResource: name, withExtension: $0, subdirectory: "GameCovers")
        }).first else { return nil }
        return await load(key: "bundle:\(name)|\(maxPixelSize)") {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
            else { return nil }
            return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary)
        }
    }

    private func load(key: String, decode: @escaping @Sendable () -> CGImage?) async -> CGImage? {
        let cacheKey = key as NSString
        if let cached = ArticleThumbnailCache.images.object(forKey: cacheKey) { return cached.image }
        guard !Task.isCancelled else { return nil }
        let token = UUID()
        let task: Task<CGImage?, Never>
        if var running = inFlight[key] {
            running.waiters.insert(token)
            inFlight[key] = running
            task = running.task
        } else {
            task = Task.detached(priority: .utility) { () -> CGImage? in
                await ArticleDecodeLimiter.shared.acquire()
                guard !Task.isCancelled else {
                    await ArticleDecodeLimiter.shared.release()
                    return nil
                }
                let image = decode()
                await ArticleDecodeLimiter.shared.release()
                return image
            }
            inFlight[key] = Flight(task: task, waiters: [token])
        }
        let image = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            Task { await self.drop(key: key, token: token) }
        }
        if let image, !Task.isCancelled {
            ArticleThumbnailCache.images.setObject(ArticleThumbnail(image), forKey: cacheKey,
                                                   cost: image.bytesPerRow * image.height)
        }
        drop(key: key, token: token)
        return image
    }

    private func drop(key: String, token: UUID) {
        guard var flight = inFlight[key], flight.waiters.remove(token) != nil else { return }
        if flight.waiters.isEmpty {
            flight.task.cancel()
            inFlight[key] = nil
        } else {
            inFlight[key] = flight
        }
    }
}
