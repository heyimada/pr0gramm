import SwiftUI

/// Full-size pages of feeds side by side in a horizontal paging scroll view that follows `current`
/// and reports swipes to another feed.
struct FeedPager<Page: View>: View {
    let sources: [FeedSource]
    let current: FeedSource
    let onSwipe: (FeedSource) -> Void
    @ViewBuilder let page: (FeedSource) -> Page

    var body: some View {
        // A paging scroll view rather than a page-style TabView, whose pages come with insets of
        // their own and whose pan gesture leaves vertical reels stuck between pages.
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                // Not lazy, so every feed keeps its scroll position.
                HStack(spacing: 0) {
                    ForEach(sources, id: \.self) { source in
                        page(source)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .id(source)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .modifier(FeedPaging(current: current, onSwipe: onSwipe))
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .ignoresSafeArea()
    }
}
/// Keeps a horizontal paging scroll view of feeds on `current`, including on first appearance,
/// where `scrollPosition(id:)` would leave it on the first page, and reports swipes to another feed.
private struct FeedPaging: ViewModifier {
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
