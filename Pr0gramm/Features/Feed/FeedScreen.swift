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
        .refreshable { await model.reload(flags: session.flags) }
        .task(id: session.flags) { await model.loadIfNeeded(flags: session.flags) }
        .background(showsBackground ? Color.pr0Background : .clear)
    }
}

extension FeedGrid where Header == EmptyView {
    init(model: FeedModel) {
        self.init(model: model) { EmptyView() }
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

    private var sources: [FeedSource] {
        FeedStream.searchable.map(FeedSource.stream)
            + (session.isLoggedIn ? [.stream(.subscribed)] : [])
            + app.customFeeds.map { .custom($0.id) }
    }

    private var current: FeedSource {
        let source = selection ?? app.defaultSource
        return sources.contains(source) ? source : .stream(.top)
    }

    var body: some View {
        let query = app.query(for: current) ?? .top
        FeedGrid(model: cache.model(for: query))
            .id(query)
            .safeAreaInset(edge: .top) {
                SegmentCapsule(options: sources, selection: Binding(get: { current }, set: { selection = $0 }),
                               title: app.title(for:))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
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
