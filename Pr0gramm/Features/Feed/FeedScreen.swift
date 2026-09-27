import SwiftUI

/// A feed pushed from a tag or link. Tag feeds can switch between beliebt, neu and müll.
struct FeedScreen: View {
    @State private var model: FeedModel

    init(query: FeedQuery) {
        _model = State(initialValue: FeedModel(query: query))
    }

    var body: some View {
        FeedScreenContent(model: model) { stream in
            var query = model.query
            query.stream = stream
            model = FeedModel(query: query)
        }
        .id(ObjectIdentifier(model))
        .navigationTitle(model.query.tags == nil ? model.query.title : "Suche")
    }
}

/// Grid plus, for tag searches, a glass stream switcher and a button to save the search as a feed.
struct FeedScreenContent: View {
    @Environment(AppState.self) private var app
    let model: FeedModel
    let onSelectStream: (FeedStream) -> Void
    @State private var newFeed: CustomFeed?

    private var savedFeed: CustomFeed? {
        app.customFeeds.first { $0.query == model.query }
    }

    var body: some View {
        FeedGrid(model: model) {
            if let tags = model.query.tags {
                VStack(spacing: 12) {
                    Text(tags)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        SegmentCapsule(
                            options: FeedStream.searchable,
                            selection: Binding(get: { model.query.stream }, set: { onSelectStream($0) }),
                            title: \.title
                        )
                        saveButton
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $newFeed) { feed in
            CustomFeedEditor(feed: feed, isNew: true)
        }
    }

    private var saveButton: some View {
        Button {
            if let savedFeed {
                withAnimation { app.customFeeds.removeAll { $0.id == savedFeed.id } }
            } else {
                newFeed = CustomFeed(query: model.query)
            }
        } label: {
            Image(systemName: savedFeed == nil ? "bookmark" : "bookmark.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(savedFeed == nil ? Color.pr0Text : Color.pr0Orange)
                .frame(width: 40, height: 40)
                .contentShape(.circle)
                .glassCircle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(savedFeed == nil ? "Als Feed speichern" : "Gespeicherten Feed entfernen")
    }
}

struct FeedGrid<Header: View>: View {
    @Environment(Session.self) private var session
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Namespace private var namespace
    let model: FeedModel
    var showsBackground = true
    /// Called with the vertical scroll offset, measured from the top of the content.
    var onScroll: ((CGFloat) -> Void)?
    @ViewBuilder var header: Header

    #if os(visionOS)
    private static var spacing: CGFloat { 8 }
    #else
    private static var spacing: CGFloat { 2 }
    #endif

    /// Three columns on phones like pr0.app; more on wider screens.
    private var columns: [GridItem] {
        if sizeClass == .compact {
            Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: 3)
        } else {
            [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: Self.spacing)]
        }
    }

    var body: some View {
        ScrollView {
            header

            LazyVGrid(columns: columns, spacing: Self.spacing) {
                ForEach(model.items) { item in
                    NavigationLink(value: Route.pager(PagerRoute(model: model, itemID: item.id, transitionNamespace: namespace))) {
                        ThumbnailView(item: item)
                    }
                    .buttonStyle(.plain)
                    #if os(visionOS)
                    .clipShape(.rect(cornerRadius: 10))
                    .hoverEffect()
                    #else
                    .matchedTransitionSource(id: item.id, in: namespace)
                    #endif
                    .task { await model.loadMoreIfNeeded(after: item, flags: session.flags) }
                }
            }
            #if os(visionOS)
            .padding(Self.spacing)
            #endif

            if model.isLoading {
                ProgressView().padding()
            }

            // Inline rather than an overlay so a header (e.g. on profiles) stays visible.
            if model.items.isEmpty {
                Group {
                    if let error = model.error {
                        ErrorView(error: error) { await model.reload(flags: session.flags) }
                    } else if !model.atEnd {
                        ProgressView()
                    } else {
                        ContentUnavailableView("Nichts gefunden", systemImage: "magnifyingglass")
                    }
                }
                .padding(.top, 100)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
            onScroll?(offset)
        }
        .refreshable { await model.reload(flags: session.flags) }
        .task(id: session.flags) { await model.loadIfNeeded(flags: session.flags) }
        .background(showsBackground ? Color.pr0Background : .clear)
    }
}

extension FeedGrid where Header == EmptyView {
    init(model: FeedModel, onScroll: ((CGFloat) -> Void)? = nil) {
        self.init(model: model, onScroll: onScroll) { EmptyView() }
    }
}

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
        FeedStream.searchable.map(FeedSource.stream)
            + (session.isLoggedIn ? [.stream(.subscribed)] : [])
            + app.visibleCustomFeeds(for: session.flags).map { .custom($0.id) }
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
            let top = outer.safeAreaInsets.top + switcherHeight
            let bottom = outer.safeAreaInsets.bottom
            GeometryReader { proxy in
                ScrollView(.horizontal) {
                    // Not lazy, so every feed keeps its scroll position.
                    HStack(spacing: 0) {
                        ForEach(sources, id: \.self) { source in
                            let query = app.query(for: source) ?? .top
                            FeedGrid(model: cache.model(for: query), onScroll: collapse.scrolled(to:))
                                .contentMargins(.top, top, for: .scrollContent)
                                .contentMargins(.bottom, bottom, for: .scrollContent)
                                .contentMargins(.top, top, for: .scrollIndicators)
                                .contentMargins(.bottom, bottom, for: .scrollIndicators)
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

/// One model per query so switching back keeps loaded items.
final class FeedCache {
    private var models: [FeedQuery: FeedModel] = [:]

    func model(for query: FeedQuery) -> FeedModel {
        if let model = models[query] { return model }
        let model = FeedModel(query: query)
        models[query] = model
        return model
    }
}
