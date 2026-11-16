import SwiftUI

struct StreamsScreen: View {
    @Environment(FeedLibrary.self) private var library
    @State private var selection: FeedSource?
    @State private var cache = FeedCache()
    @State private var collapse = ScrollCollapse()
    @State private var switcherHeight: CGFloat = 56

    private var sources: [FeedSource] {
        library.sources(withSubscriptions: true)
    }

    private var current: FeedSource {
        library.currentSource(picked: selection, in: sources)
    }

    var body: some View {
        // Pages span the whole screen so posts scroll under the toolbar, the floating switcher and
        // the tab bar; margins keep the first and last rows clear of them.
        GeometryReader { outer in
            let insets = outer.safeAreaInsets
            // Leading and trailing too: the closed iPhone Duo keeps its tab bar along the right edge.
            let margins = EdgeInsets(top: insets.top + switcherHeight, leading: insets.leading,
                                     bottom: insets.bottom, trailing: insets.trailing)
            FeedPager(sources: sources, current: current, onSwipe: { selection = $0 }) { source in
                let query = library.query(for: source)
                FeedGrid(model: cache.model(for: query), onScroll: collapse.scrolled(to:))
                    .contentMargins(.all, margins, for: .scrollContent)
                    .contentMargins(.all, margins, for: .scrollIndicators)
                    .id(query)
            }
        }
        .background(Color.pr0Background)
        .onChange(of: current) { collapse.reset() }
        .overlay(alignment: .top) {
            CollapsingSegmentCapsule(options: sources, selection: Binding(get: { current }, set: { selection = $0 }),
                                     title: library.title(for:), isCollapsed: collapse.isCollapsed, collapsedHint: "Feeds anzeigen", onExpand: collapse.expand)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                    // Only the expanded height counts, so collapsing doesn't shift the posts.
                    if !collapse.isCollapsed { switcherHeight = height }
                }
        }
    }
}

@Observable
final class ScrollCollapse {
    private(set) var isCollapsed = false
    @ObservationIgnored private var anchor: CGFloat?
    @ObservationIgnored private var offset: CGFloat = 0

    private static let threshold: CGFloat = 24
    private static let topZone: CGFloat = 40

    func scrolled(to offset: CGFloat) {
        self.offset = offset
        if offset < Self.topZone {
            set(collapsed: false)
            return
        }
        guard let start = anchor else {
            anchor = offset
            return
        }
        let delta = offset - start
        if isCollapsed ? delta > 0 : delta < 0 {
            anchor = offset
        } else if abs(delta) > Self.threshold {
            set(collapsed: !isCollapsed)
        }
    }

    func expand() {
        set(collapsed: false)
    }

    func reset() {
        anchor = nil
        guard isCollapsed else { return }
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) { isCollapsed = false }
    }

    private func set(collapsed: Bool) {
        anchor = offset
        guard collapsed != isCollapsed else { return }
        withAnimation(.spring(duration: 0.4, bounce: 0.2)) { isCollapsed = collapsed }
    }
}
