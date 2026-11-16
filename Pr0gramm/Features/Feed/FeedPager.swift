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
            .pagePosition(Binding(get: { current }, set: { if let source = $0 { onSwipe(source) } }))
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .ignoresSafeArea()
    }
}
