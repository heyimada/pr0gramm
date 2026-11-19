import SwiftUI

struct FeedGrid<Header: View>: View {
    @Environment(Session.self) private var session
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.bookPages) private var bookPages
    @Namespace private var namespace
    @State private var contentFrame = CGRect.zero
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
        .refreshable { await model.reload(flags: session.flags) }
        .task(id: session.flags) { await model.loadIfNeeded(flags: session.flags) }
        .background(showsBackground ? Color.pr0Background : .clear)
    }
}

extension FeedGrid {
    @ViewBuilder
    private var grid: some View {
        Group {
            if let pages = bookPages, let layout = BookGridLayout(pages: pages, content: contentFrame) {
                thumbnails(columns: layout.columns)
                    .frame(width: layout.width)
                    .padding(.leading, max(layout.minX - contentFrame.minX, 0))
            } else {
                thumbnails(columns: ThumbnailView.thumbnailColumns(compact: sizeClass == .compact))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { contentFrame = $0 }
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

/// Square tiles of one size on both pages, with the gap between the pages' columns sitting on the
/// fold. Each page takes as many columns as fit it, so the wider page isn't cut to the narrower
/// one; any leftover goes to the page's outer edge.
private struct BookGridLayout {
    let columns: [GridItem]
    let width: CGFloat
    /// Global x of the grid's leading edge.
    let minX: CGFloat

    private static let sides: ClosedRange<CGFloat> = 100...150

    /// `content` is the grid's area inside the screen's content margins (e.g. the side tab bar).
    init?(pages: BookPages, content: CGRect) {
        let widths = [pages.leading.maxX - content.minX, content.maxX - pages.trailing.minX]
        guard widths.allSatisfy({ $0 > 0 }) else { return nil }
        let spacing = ThumbnailView.spacing
        let fit = { (width: CGFloat, side: CGFloat) in max(1, Int((width + spacing) / (side + spacing))) }
        let used = { (count: Int, side: CGFloat) in CGFloat(count) * side + CGFloat(count - 1) * spacing }

        // Sizes that fill one page exactly; keep the one that leaves the least over on the other.
        let candidates = widths.flatMap { width in
            (2...8).map { (width - CGFloat($0 - 1) * spacing) / CGFloat($0) }
        }
        // A size no page can hold a single column of would push the grid past the fold.
        let inRange = candidates.filter { side in Self.sides.contains(side) && widths.allSatisfy { $0 >= side } }
        let waste = { (side: CGFloat) in widths.reduce(0) { $0 + $1 - used(fit($1, side), side) } }
        let side = inRange.min { waste($0) < waste($1) } ?? min(candidates.max() ?? 0, Self.sides.upperBound)
        guard side > 0 else { return nil }

        let counts = widths.map { fit($0, side) }
        func page(_ count: Int, trailingSpacing: CGFloat) -> [GridItem] {
            Array(repeating: GridItem(.fixed(side), spacing: spacing), count: count - 1)
                + [GridItem(.fixed(side), spacing: trailingSpacing)]
        }
        columns = page(counts[0], trailingSpacing: pages.gap) + page(counts[1], trailingSpacing: spacing)
        let leadingWidth = used(counts[0], side)
        width = leadingWidth + pages.gap + used(counts[1], side)
        minX = pages.leading.maxX - leadingWidth
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
