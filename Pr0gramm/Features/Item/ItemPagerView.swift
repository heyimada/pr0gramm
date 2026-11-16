import SwiftUI

struct ItemPagerView: View {
    @Environment(Session.self) private var session
    let model: FeedModel
    @State private var currentID: Int?
    @State private var pageSize: CGSize = .zero

    init(model: FeedModel, initialID: Int) {
        self.model = model
        _currentID = State(initialValue: initialID)
    }

    var body: some View {
        // Pages span the full width, including what's under a vertical bar (iPhone Duo closed, or
        // opened in landscape); narrower pages would let the next post show there. Each page keeps
        // its content clear of the bar itself.
        GeometryReader { outer in
            let insets = outer.safeAreaInsets
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(model.items) { item in
                        ItemDetailView(item: item, isActive: item.id == currentID, pageSize: pageSize,
                                       sideInsets: insets,
                                       previous: step(from: item, by: -1), next: step(from: item, by: 1))
                            .containerRelativeFrame([.horizontal, .vertical])
                            .onAppear { model.loadMoreIfNeeded(after: item, flags: session.flags) }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .pagePosition($currentID, anchor: .center)
            .scrollIndicators(.hidden)
            .onGeometryChange(for: CGSize.self, of: \.size) { pageSize = $0 }
            .ignoresSafeArea(edges: .horizontal)
        }
        .overlay(alignment: .bottom) { PagingRetry(model: model).padding(.bottom, 24) }
        .background(Color.pr0Background)
        .navigationTitle(model.items.first { $0.id == currentID }?.user ?? "")
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
    }

    private func step(from item: FeedItem, by offset: Int) -> (() -> Void)? {
        guard let index = model.items.firstIndex(of: item),
              model.items.indices.contains(index + offset) else { return nil }
        let target = model.items[index + offset].id
        return { withAnimation(.snappy) { currentID = target } }
    }
}

struct SingleItemScreen: View {
    @Environment(Session.self) private var session
    let id: Int
    @State private var item: FeedItem?
    @State private var error: Error?
    @State private var pageSize: CGSize = .zero

    var body: some View {
        Group {
            if let item {
                ItemDetailView(item: item, isActive: true, pageSize: pageSize)
            } else if let error {
                ErrorView(error: error, retry: load)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self, of: \.size) { pageSize = $0 }
        .background(Color.pr0Background)
        .task { await load() }
    }

    private func load() async {
        do {
            // `id` returns a page of items around the requested one; the new stream contains everything.
            let response = try await APIClient.shared.items(.new, flags: session.flags, around: id)
            guard let match = response.items.first(where: { $0.id == id }) else {
                throw APIError.message("Dieser Post ist nicht (mehr) verfügbar oder dein Filter blendet ihn aus.")
            }
            item = match
            error = nil
        } catch where error.isCancellation {
        } catch {
            self.error = error
        }
    }
}
