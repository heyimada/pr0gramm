import SwiftUI

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
