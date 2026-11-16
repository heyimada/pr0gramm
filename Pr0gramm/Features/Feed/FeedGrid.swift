import SwiftUI

struct FeedGrid<Header: View>: View {
    @Environment(Session.self) private var session
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Namespace private var namespace
    let model: FeedModel
    var showsBackground = true
    var onScroll: ((CGFloat) -> Void)?
    @ViewBuilder var header: Header

    var body: some View {
        ScrollView {
            header

            LazyVGrid(columns: ThumbnailView.thumbnailColumns(compact: sizeClass == .compact), spacing: ThumbnailView.spacing) {
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
                    .onAppear { model.loadMoreIfNeeded(after: item, flags: session.flags) }
                }
            }
            #if os(visionOS)
            .padding(ThumbnailView.spacing)
            #endif

            if model.isLoading {
                ProgressView().padding()
            } else {
                PagingRetry(model: model).padding()
            }

            // Inline rather than an overlay so a header (e.g. on profiles) stays visible.
            FeedStatus(model: model, emptySymbol: "magnifyingglass", topInset: 100)
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
            onScroll?(offset)
        }
        .refreshable { await model.reload(flags: session.flags) }
        .task(id: session.flags) { await model.loadIfNeeded(flags: session.flags) }
        .background(showsBackground ? Color.pr0Background : .clear)
    }
}

struct FeedStatus: View {
    @Environment(Session.self) private var session
    let model: FeedModel
    let emptySymbol: String
    var topInset: CGFloat = 0

    var body: some View {
        if model.items.isEmpty {
            Group {
                if let error = model.error {
                    ErrorView(error: error) { await model.reload(flags: session.flags) }
                } else if !model.atEnd {
                    ProgressView()
                } else {
                    ContentUnavailableView("Nichts gefunden", systemImage: emptySymbol)
                }
            }
            .padding(.top, topInset)
        }
    }
}

extension FeedGrid where Header == EmptyView {
    init(model: FeedModel, onScroll: ((CGFloat) -> Void)? = nil) {
        self.init(model: model, onScroll: onScroll) { EmptyView() }
    }
}

/// Offered after loading the next page failed, since nothing else asks for it again.
struct PagingRetry: View {
    @Environment(Session.self) private var session
    let model: FeedModel

    var body: some View {
        if model.pagingFailed && !model.items.isEmpty {
            Button("Erneut versuchen") { Task { await model.retryPaging(flags: session.flags) } }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}
