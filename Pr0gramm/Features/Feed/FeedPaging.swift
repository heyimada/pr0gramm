import SwiftUI

/// Keeps a horizontal paging scroll view of feeds on `current`, including on first appearance,
/// where `scrollPosition(id:)` would leave it on the first page, and reports swipes to another feed.
struct FeedPaging: ViewModifier {
    let current: FeedSource
    let onSwipe: (FeedSource) -> Void
    @State private var position = ScrollPosition(idType: FeedSource.self)

    private var shown: FeedSource? { position.viewID(type: FeedSource.self) }

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onAppear { position.scrollTo(id: current) }
            .onChange(of: current) {
                guard shown != current else { return }
                withAnimation(.snappy) { position.scrollTo(id: current) }
            }
            .onChange(of: shown) {
                if let shown, shown != current { onSwipe(shown) }
            }
    }
}
