import Foundation
import Observation

/// Paginated list of items for one `FeedQuery`. Shared between the grid and the item pager
/// so both see the same items and paging state.
@Observable
final class FeedModel {
    let query: FeedQuery
    private(set) var items: [FeedItem] = []
    private(set) var isLoading = false
    private(set) var atEnd = false
    private(set) var pagingFailed = false
    private(set) var error: Error?

    @ObservationIgnored private var loadedFlags: ContentFlags?
    @ObservationIgnored private var generation = 0

    init(query: FeedQuery) {
        self.query = query
    }

    init(items: [FeedItem], query: FeedQuery) {
        self.query = query
        self.items = items
        atEnd = true
    }

    func loadIfNeeded(flags: ContentFlags) async {
        guard items.isEmpty || loadedFlags != flags else { return }
        await reload(flags: flags)
    }

    func reload(flags: ContentFlags) async {
        generation += 1
        let started = generation
        do {
            let response = try await APIClient.shared.items(query, flags: flags)
            guard started == generation else { return }
            items = response.items
            atEnd = response.atEnd
            loadedFlags = flags
            error = nil
            pagingFailed = false
        } catch is CancellationError {
        } catch {
            guard started == generation else { return }
            self.error = error
        }
    }

    private func loadMore(flags: ContentFlags) async {
        guard !isLoading, !atEnd, let last = items.last else { return }
        let started = generation
        isLoading = true
        pagingFailed = false
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.items(query, flags: flags, older: query.cursor(for: last))
            guard started == generation else { return }
            let known = Set(items.map(\.id))
            items.append(contentsOf: response.items.filter { !known.contains($0.id) })
            atEnd = response.atEnd || response.items.isEmpty
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            guard started == generation else { return }
            pagingFailed = true
        }
    }

    func retryPaging(flags: ContentFlags) async {
        await loadMore(flags: flags)
    }

    func loadMoreIfNeeded(after item: FeedItem, flags: ContentFlags) async {
        guard let index = items.firstIndex(of: item), index >= items.count - 12 else { return }
        await loadMore(flags: flags)
    }
}

final class FeedCache {
    private var models: [FeedQuery: FeedModel] = [:]

    func model(for query: FeedQuery) -> FeedModel {
        if let model = models[query] { return model }
        let model = FeedModel(query: query)
        models[query] = model
        return model
    }
}
