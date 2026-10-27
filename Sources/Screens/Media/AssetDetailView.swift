import SwiftUI
import Observation
import PDFKit
import AVKit

private enum Constants {
    static var imageUnavailable: String { AppText.localized( "Image unavailable") }
    static var noInternetConnection: String { AppText.localized("No internet connection") }
    static var connectAndTryAgain: String { AppText.localized("Connect to the internet and try again.") }
    static var couldNotLoadImage: String { AppText.localized("Could not load this image.") }
    static var tryAgain: String { AppText.localized("Try again") }
    static var loadingImage: String { AppText.localized( "Loading image") }
    static var fileUnavailable: String { AppText.localized( "File unavailable") }
    static var loadingFile: String { AppText.localized( "Loading file") }
    static var openThisFile: String { AppText.localized( "Open this file") }
    static var useShareToOpenThis: String { AppText.localized( "Use Share to open this file in another app.") }
    static var fileNotInLibrary: String { AppText.localized( "File not in library") }
    static var useAddMissingMediaTo: String { AppText.localized( "Use Add missing media to add this file.") }
    static var shareFile: String { AppText.localized( "Share file") }
}

struct AssetDetailView: View {
    @State var viewModel = AssetDetailViewModel()
    let asset: ContentAsset
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 18) {
            if asset.fetchedAt != nil || asset.mimeType?.hasPrefix("image/") == true {
                if asset.mimeType?.hasPrefix("image/") == true {
                    if let image = viewModel.image { Image(decorative: image, scale: 1).resizable().scaledToFit() }
                    else if viewModel.loadFailed {
                        ContentUnavailableView {
                            Label(viewModel.isOffline ? Constants.noInternetConnection : Constants.imageUnavailable,
                                  systemImage: viewModel.isOffline ? "wifi.slash" : "photo")
                        } description: {
                            Text(viewModel.isOffline ? Constants.connectAndTryAgain : Constants.couldNotLoadImage)
                        } actions: {
                            Button(Constants.tryAgain) {
                                Task { await viewModel.load(asset: asset, context: modelContext, retry: true) }
                            }
                        }
                    }
                    else { ProgressView(Constants.loadingImage) }
                } else if asset.mimeType == "application/pdf" {
                    if let pdfData = viewModel.pdfData { SavedPDFView(data: pdfData) }
                    else if viewModel.loadFailed { ContentUnavailableView(Constants.fileUnavailable, systemImage: "doc") }
                    else { ProgressView(Constants.loadingFile) }
                } else if asset.mimeType?.hasPrefix("audio/") == true || asset.mimeType?.hasPrefix("video/") == true {
                    if let player = viewModel.player { VideoPlayer(player: player) }
                    else if viewModel.loadFailed { ContentUnavailableView(Constants.fileUnavailable, systemImage: "doc") }
                    else { ProgressView(Constants.loadingFile) }
                } else {
                    ContentUnavailableView(Constants.openThisFile, systemImage: "doc.fill", description: Text(Constants.useShareToOpenThis))
                }
            } else {
                ContentUnavailableView(Constants.fileNotInLibrary, systemImage: "arrow.down.circle", description: Text(Constants.useAddMissingMediaTo))
            }
            if let localFile = viewModel.localFile {
                ShareLink(item: localFile) { Label(Constants.shareFile, systemImage: "square.and.arrow.up") }
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(asset.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: asset.fetchedAt) { await viewModel.load(asset: asset, context: modelContext) }
    }
}
