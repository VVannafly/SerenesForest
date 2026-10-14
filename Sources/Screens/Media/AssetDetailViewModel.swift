import Foundation
import Observation
import SwiftUI
import AVKit
import SwiftData

@MainActor @Observable
final class AssetDetailViewModel {
    var localFile: URL?
    var player: AVPlayer?
    var image: CGImage?
    var pdfData: Data?
    var loadFailed = false

    func load(asset: ContentAsset, context: ModelContext) async {
            image = nil
            pdfData = nil
            localFile = nil
            player = nil
            loadFailed = false
            guard let fetchedAt = asset.fetchedAt else { return }
            let assetURL = asset.url
            let mimeType = asset.mimeType ?? ""
            let container = context.container
            let fileTask = Task.detached(priority: .utility) { () -> (Data?, URL?) in
                let context = ModelContext(container)
                let descriptor = FetchDescriptor<ContentAsset>(predicate: #Predicate { $0.url == assetURL })
                guard let data = try? context.fetch(descriptor).first?.data,
                      !Task.isCancelled, let source = URL(string: assetURL) else { return (nil, nil) }
                let file = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(source.pathExtension)
                guard (try? data.write(to: file, options: .atomic)) != nil else { return (nil, nil) }
                return (mimeType == "application/pdf" ? data : nil, file)
            }
            if mimeType.hasPrefix("image/") {
                let loaded = await LocalImageLoader.shared.assetImage(
                    assetURL: assetURL, fetchedAt: fetchedAt, maxPixelSize: 2400, container: container
                )
                guard !Task.isCancelled else { fileTask.cancel(); return }
                image = loaded
            }
            let (loadedPDF, file) = await withTaskCancellationHandler {
                await fileTask.value
            } onCancel: {
                fileTask.cancel()
            }
            guard !Task.isCancelled else { return }
            pdfData = loadedPDF
            localFile = file
            if let file, mimeType.hasPrefix("audio/") || mimeType.hasPrefix("video/") {
                player = AVPlayer(url: file)
            }
            loadFailed = file == nil || (mimeType.hasPrefix("image/") && image == nil)
    }
}
