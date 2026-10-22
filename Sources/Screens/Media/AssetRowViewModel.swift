import Foundation

private enum Constants {
    static let imageMime = "image/"
    static let audioMime = "audio/"
    static let videoMime = "video/"
    static let pdfMime = "application/pdf"
    static let image = "Image"
    static let audio = "Audio"
    static let video = "Video"
    static let pdf = "PDF"
    static let mediaFile = "Media file"
    static let imageSymbol = "photo"
    static let fileSymbol = "doc.fill"
}

struct AssetRowViewModel {
    let kind: String
    let symbol: String

    init(asset: MediaAsset) {
        let mime = asset.mimeType ?? ""
        symbol = mime.hasPrefix(Constants.imageMime) ? Constants.imageSymbol : Constants.fileSymbol
        if mime.hasPrefix(Constants.imageMime) { kind = Constants.image }
        else if mime.hasPrefix(Constants.audioMime) { kind = Constants.audio }
        else if mime.hasPrefix(Constants.videoMime) { kind = Constants.video }
        else if mime == Constants.pdfMime { kind = Constants.pdf }
        else { kind = Constants.mediaFile }
    }
}
