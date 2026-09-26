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

/// Grid plus, for tag searches, a glass stream switcher on top.
struct FeedScreenContent: View {
    let model: FeedModel
    let onSelectStream: (FeedStream) -> Void

    var body: some View {
        FeedGrid(model: model) {
            if let tags = model.query.tags {
                VStack(spacing: 12) {
                    Text(tags)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    SegmentCapsule(
                        options: FeedStream.searchable,
                        selection: Binding(get: { model.query.stream }, set: { onSelectStream($0) }),
                        title: \.title
                    )
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
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

/// Feed tab: the stream grid with a floating glass capsule for beliebt · neu · müll (· abos).
struct StreamsScreen: View {
    @Environment(Session.self) private var session
    @State private var stream: FeedStream = .top
    @State private var cache = FeedCache()

    private var streams: [FeedStream] {
        FeedStream.searchable + (session.isLoggedIn ? [.subscribed] : [])
    }

    var body: some View {
        FeedGrid(model: cache.model(for: stream))
            .id(stream)
            .safeAreaInset(edge: .top) {
                SegmentCapsule(options: streams, selection: $stream, title: \.title)
                    .padding(.bottom, 8)
            }
            .onChange(of: session.isLoggedIn) {
                if !session.isLoggedIn, stream == .subscribed { stream = .top }
            }
    }
}

/// One model per stream so switching back keeps loaded items.
final class FeedCache {
    private var models: [FeedStream: FeedModel] = [:]

    func model(for stream: FeedStream) -> FeedModel {
        if let model = models[stream] { return model }
        let model = FeedModel(query: FeedQuery(stream: stream))
        models[stream] = model
        return model
    }
}
