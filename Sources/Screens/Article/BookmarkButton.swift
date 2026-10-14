import SwiftUI

private enum Constants {
    static var savePage: String { AppText.localized("Save page") }
    static var removeBookmark: String { AppText.localized("Remove bookmark") }
    static var couldNotSaveBookmark: String { AppText.localized("Could not save bookmark") }
    static var ok: String { AppText.localized("OK") }
}

struct BookmarkButton: View {
    @Bindable var page: ContentPage
    @Environment(\.modelContext) private var context
    @State private var saveFailed = false

    var body: some View {
        Button {
            let previous = page.bookmarkedAt
            page.bookmarkedAt = previous == nil ? .now : nil
            do {
                try context.save()
            } catch {
                page.bookmarkedAt = previous
                saveFailed = true
            }
        } label: {
            Label(page.bookmarkedAt == nil ? Constants.savePage : Constants.removeBookmark,
                  systemImage: page.bookmarkedAt == nil ? "bookmark" : "bookmark.fill")
        }
        .help(page.bookmarkedAt == nil ? Constants.savePage : Constants.removeBookmark)
        .alert(Constants.couldNotSaveBookmark, isPresented: $saveFailed) {
            Button(Constants.ok, role: .cancel) { }
        }
    }
}
