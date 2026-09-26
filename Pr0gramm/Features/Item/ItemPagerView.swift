import SwiftUI

/// Horizontally paging item viewer over a feed; loads more items as you approach the end.
struct ItemPagerView: View {
    @Environment(Session.self) private var session
    let model: FeedModel
    @State private var currentID: Int?
    @State private var pageHeight: CGFloat = 0

    init(model: FeedModel, initialID: Int) {
        self.model = model
        _currentID = State(initialValue: initialID)
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(model.items) { item in
                    ItemDetailView(item: item, isActive: item.id == currentID, pageHeight: pageHeight,
                                   step: { step(from: item, by: $0) })
                        .containerRelativeFrame([.horizontal, .vertical])
                        .task { await model.loadMoreIfNeeded(after: item, flags: session.flags) }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { pageHeight = $0 }
        .background(Color.pr0Background)
        .navigationTitle(model.items.first { $0.id == currentID }?.user ?? "")
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
    }

    /// Moves to the neighbouring item; `nil` if there is none in that direction.
    private func step(from item: FeedItem, by offset: Int) -> (() -> Void)? {
        guard let index = model.items.firstIndex(of: item),
              model.items.indices.contains(index + offset) else { return nil }
        let target = model.items[index + offset].id
        return { withAnimation(.snappy) { currentID = target } }
    }
}

/// Item opened from a link: loads the item by id and shows it on its own.
struct SingleItemScreen: View {
    @Environment(Session.self) private var session
    let id: Int
    @State private var item: FeedItem?
    @State private var error: Error?
    @State private var pageHeight: CGFloat = 0

    var body: some View {
        Group {
            if let item {
                ItemDetailView(item: item, isActive: true, pageHeight: pageHeight)
            } else if let error {
                ErrorView(error: error, retry: load)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { pageHeight = $0 }
        .background(Color.pr0Background)
        .task { await load() }
    }

    private func load() async {
        do {
            // `id` returns a page of items around the requested one; the new stream contains everything.
            let response = try await APIClient.shared.items(.new, flags: session.flags, around: id)
            guard let match = response.items.first(where: { $0.id == id }) else {
                throw APIError.server("Dieser Post ist nicht (mehr) verfügbar oder dein Filter blendet ihn aus.")
            }
            item = match
            error = nil
        } catch {
            self.error = error
        }
    }
}
