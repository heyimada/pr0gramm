import SwiftUI

struct ThumbnailView: View {
    let item: FeedItem

    #if os(visionOS)
    static let spacing: CGFloat = 8
    #else
    static let spacing: CGFloat = 2
    #endif

    static func thumbnailColumns(compact: Bool) -> [GridItem] {
        compact
            ? Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
            : [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: spacing)]
    }

    var body: some View {
        Color.pr0Pill
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AsyncImage(url: item.thumbnailURL, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else if phase.error != nil {
                        Image(systemName: "photo").foregroundStyle(Color.pr0Secondary)
                    }
                }
            }
            .clipped()
            .contentShape(.rect)
            .accessibilityElement()
            .accessibilityLabel("Post \(String(item.id)) von \(item.user) öffnen")
    }
}
