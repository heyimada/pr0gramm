import SwiftUI

struct FeedGrid<Header: View>: View {
    @Environment(Session.self) private var session
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.bookPages) private var bookPages
    @Namespace private var namespace
    @State private var gridFrame = CGRect.zero
    @State private var contentMinX: CGFloat = 0
    let model: FeedModel
    var showsBackground = true
    var onScroll: ((CGFloat) -> Void)?
    @ViewBuilder var header: Header

    var body: some View {
        ScrollView {
            header

            grid

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
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { gridFrame = $0 }
        .refreshable { await model.reload(flags: session.flags) }
        .task(id: session.flags) { await model.loadIfNeeded(flags: session.flags) }
        .background(showsBackground ? Color.pr0Background : .clear)
    }
}

extension FeedGrid {
    @ViewBuilder
    private var grid: some View {
        if let pages = bookPages, let layout = BookGridLayout(pages: pages, gridFrame: gridFrame) {
            thumbnails(columns: layout.columns)
                .frame(width: layout.width)
                .padding(.leading, max(layout.minX - contentMinX, 0))
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self, of: { $0.frame(in: .global).minX }) { contentMinX = $0 }
        } else {
            thumbnails(columns: ThumbnailView.thumbnailColumns(compact: sizeClass == .compact))
        }
    }

    private func thumbnails(columns: [GridItem]) -> some View {
        LazyVGrid(columns: columns, spacing: ThumbnailView.spacing) {
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
    }
}

/// Fixed columns placed symmetrically around the fold: as many per page as fit the narrower page,
/// with the gap between the two pages' columns sitting on the fold.
private struct BookGridLayout {
    let columns: [GridItem]
    let width: CGFloat
    /// Global x of the grid's leading edge.
    let minX: CGFloat

    init?(pages: BookPages, gridFrame: CGRect) {
        let pageWidth = min(pages.leading.width, gridFrame.maxX - pages.trailing.minX)
        guard pageWidth > 0 else { return nil }
        let spacing = ThumbnailView.spacing
        let count = max(2, Int(pageWidth / 150))
        let side = (pageWidth - CGFloat(count - 1) * spacing) / CGFloat(count)
        let page = Array(repeating: GridItem(.fixed(side), spacing: spacing), count: count - 1)
        columns = page + [GridItem(.fixed(side), spacing: pages.gap)] + page + [GridItem(.fixed(side), spacing: spacing)]
        width = 2 * pageWidth + pages.gap
        minX = pages.leading.maxX - pageWidth
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
            Button("Erneut versuchen") { Task { await model.loadMore(flags: session.flags) } }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}
