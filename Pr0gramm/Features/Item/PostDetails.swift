import SwiftUI

/// A post's info bar, tags and comments, with the loading and error states of its details.
struct PostDetails: View {
    let item: FeedItem
    let details: ItemDetails

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ItemInfoBar(item: item)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)

            content.padding(.horizontal, 16)
        }
        .padding(.bottom, 40)
    }

    @ViewBuilder
    private var content: some View {
        if let info = details.info {
            TagsSection(tags: info.tags)
            CommentsSection(item: item, details: details)
                .padding(.top, 28)
        } else if let error = details.error {
            ErrorView(error: error, retry: details.load)
        } else {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
        }
    }
}
