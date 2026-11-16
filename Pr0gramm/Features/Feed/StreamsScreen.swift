import SwiftUI

/// Feed tab: the stream grid with a floating glass capsule for beliebt · neu · müll (· abos)
/// and the user's own feeds. Opens on the default feed from the settings.
struct StreamsScreen: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    /// `nil` until the user picks something, so the tab follows changes to the default feed.
    @State private var selection: FeedSource?
    @State private var cache = FeedCache()
    @State private var collapse = ScrollCollapse()
    @State private var switcherHeight: CGFloat = 56

    private var sources: [FeedSource] {
        app.feedSources(for: session.flags, includesSubscriptions: session.isLoggedIn)
    }

    private var current: FeedSource {
        let source = selection ?? app.defaultSource(for: session.flags)
        return sources.contains(source) ? source : .stream(.top)
    }

    var body: some View {
        // Pages span the whole screen so posts scroll under the toolbar, the floating switcher and
        // the tab bar; margins keep the first and last rows clear of them. A paging scroll view
        // rather than a page-style TabView, whose pages come with insets of their own.
        GeometryReader { outer in
            let insets = outer.safeAreaInsets
            // Leading and trailing too: the closed iPhone Duo keeps its tab bar along the right edge.
            let margins = EdgeInsets(top: insets.top + switcherHeight, leading: insets.leading,
                                     bottom: insets.bottom, trailing: insets.trailing)
            GeometryReader { proxy in
                ScrollView(.horizontal) {
                    // Not lazy, so every feed keeps its scroll position.
                    HStack(spacing: 0) {
                        ForEach(sources, id: \.self) { source in
                            let query = app.query(for: source) ?? .top
                            FeedGrid(model: cache.model(for: query), onScroll: collapse.scrolled(to:))
                                .contentMargins(.all, margins, for: .scrollContent)
                                .contentMargins(.all, margins, for: .scrollIndicators)
                                .id(query)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .id(source)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .modifier(FeedPaging(current: current) { selection = $0 })
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .ignoresSafeArea()
        }
        .background(Color.pr0Background)
        .onChange(of: current) { collapse.reset() }
        .overlay(alignment: .top) {
            CollapsingSegmentCapsule(options: sources, selection: Binding(get: { current }, set: { selection = $0 }),
                                     title: app.title(for:), isCollapsed: collapse.isCollapsed, onExpand: collapse.expand)
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

/// Collapses a bar after scrolling down a bit and brings it back after scrolling up a bit,
/// like the tab bar's minimize behavior. Only `isCollapsed` is observed, so scrolling itself
/// doesn't re-render anything.
@Observable
final class ScrollCollapse {
    private(set) var isCollapsed = false
    /// Offset where the current direction started: the lowest point while expanded, the highest while collapsed.
    /// `nil` after switching feeds, until the new feed reports its offset.
    @ObservationIgnored private var anchor: CGFloat?
    @ObservationIgnored private var offset: CGFloat = 0

    private static let threshold: CGFloat = 24
    /// Always expanded this close to the top.
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

    /// Expands for a newly selected feed, whose scroll position is unrelated to the last one's.
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
