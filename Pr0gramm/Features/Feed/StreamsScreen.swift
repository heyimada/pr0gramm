import SwiftUI

struct StreamsScreen: View {
    @Environment(FeedLibrary.self) private var library
    @Environment(Session.self) private var session
    @State private var selection: FeedSource?
    /// The preset picked last, kept as the last page so swiping away from it doesn't remove it
    /// mid-swipe.
    @State private var preset: FeedSource?
    @State private var cache = FeedCache()
    @State private var collapse = ScrollCollapse()
    @State private var switcherHeight: CGFloat = 56

    private var sources: [FeedSource] {
        library.sources(withSubscriptions: true, picked: preset)
    }

    private var current: FeedSource {
        library.currentSource(picked: selection, in: sources)
    }

    private func pick(_ source: FeedSource) {
        if case .preset = source { preset = source }
        selection = source
    }

    var body: some View {
        // Pages span the whole screen so posts scroll under the toolbar, the floating title and
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
        .overlay(alignment: .topLeading) {
            StreamMenu(sources: sources, selection: Binding(get: { current }, set: { pick($0) })) {
                FeedTitle(title: library.title(for: current), subtitle: session.flags.summary,
                          isCollapsed: collapse.isCollapsed)
            }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 10)
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
                    // Only the expanded height counts, so collapsing doesn't shift the posts.
                    if !collapse.isCollapsed { switcherHeight = height }
                }
        }
    }
}

/// The feed's name as a large title over a subtitle, shrinking to a glass capsule once the grid
/// scrolls down. Both open the feed menu.
private struct FeedTitle: View {
    let title: String
    let subtitle: String
    let isCollapsed: Bool

    var body: some View {
        Group {
            if isCollapsed {
                HStack(spacing: 6) {
                    Text(title).font(.headline).lineLimit(1)
                    MenuChevron(size: 12)
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                #if os(visionOS)
                .glassBackgroundEffect(in: .capsule)
                #else
                .glassEffect(.regular.interactive(), in: .capsule)
                #endif
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.largeTitle.bold()).lineLimit(1)
                        MenuChevron(size: 18)
                    }
                    Text(subtitle).font(.subheadline).foregroundStyle(Color.pr0Secondary)
                }
                .background(alignment: .top) {
                    // Keeps the title legible when it comes back over the grid mid-scroll.
                    LinearGradient(colors: [Color.pr0Background, Color.pr0Background.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                        .padding(.horizontal, -400)
                        .padding(.top, -200)
                        .padding(.bottom, -24)
                        .allowsHitTesting(false)
                }
            }
        }
        .foregroundStyle(Color.pr0Text)
        .contentShape(.rect)
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
