import Foundation
import ImageIO
import UniformTypeIdentifiers

private enum Constants {
    static let minimumBytes = 150_000
    static let maxPixelSize = 3_200
    static let quality = 0.82
    static let minimumSaving = 0.10
}

private func optimizedJPEG(_ data: Data) -> Data? {
    guard data.count >= Constants.minimumBytes,
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Constants.maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
          ] as CFDictionary) else { return nil }

    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(destination, image, [
        kCGImageDestinationLossyCompressionQuality: Constants.quality
    ] as CFDictionary)
    guard CGImageDestinationFinalize(destination),
          Double(output.length) <= Double(data.count) * (1 - Constants.minimumSaving)
    else { return nil }
    return output as Data
}

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: optimize_build_assets <input.jsonl> <output.jsonl>\n", stderr)
    exit(2)
}

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let target = URL(fileURLWithPath: CommandLine.arguments[2])
let input = try FileHandle(forReadingFrom: source)
FileManager.default.createFile(atPath: target.path, contents: nil)
let output = try FileHandle(forWritingTo: target)
defer { try? input.close(); try? output.close() }

var buffer = Data()
let newline = Data([10])
var count = 0
var changed = 0
var saved = 0

func process(_ line: Data) throws {
    guard !line.isEmpty else { return }
    var record = try JSONSerialization.jsonObject(with: line) as! [String: Any]
    if let url = record["url"] as? String,
       url.localizedCaseInsensitiveContains("/gallery/"),
       record["mimeType"] as? String == "image/jpeg",
       let base64 = record["dataBase64"] as? String,
       let original = Data(base64Encoded: base64),
       let reduced = optimizedJPEG(original) {
        record["dataBase64"] = reduced.base64EncodedString()
        changed += 1
        saved += original.count - reduced.count
    }
    let result = try JSONSerialization.data(withJSONObject: record, options: [.fragmentsAllowed])
    try output.write(contentsOf: result)
    try output.write(contentsOf: newline)
    count += 1
}

while true {
    let chunk = try input.read(upToCount: 1_048_576) ?? Data()
    if chunk.isEmpty && buffer.isEmpty { break }
    buffer.append(chunk)
    while let range = buffer.range(of: newline) {
        try process(Data(buffer[..<range.lowerBound]))
        buffer.removeSubrange(..<range.upperBound)
    }
    if chunk.isEmpty { try process(buffer); break }
}

print("\(source.lastPathComponent): \(count) assets, \(changed) optimized, \(saved) bytes saved")
