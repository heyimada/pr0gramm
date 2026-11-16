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
    /// Bumped when a reload replaces `items`; a page load that started before is discarded.
    @ObservationIgnored private var listVersion = 0
    @ObservationIgnored private var latestReload = 0

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
        latestReload += 1
        let reload = latestReload
        do {
            let response = try await APIClient.shared.items(query, flags: flags)
            guard reload == latestReload else { return }
            listVersion += 1
            items = response.items
            atEnd = response.atEnd
            loadedFlags = flags
            error = nil
            pagingFailed = false
        } catch where error.isCancellation {
        } catch {
            guard reload == latestReload else { return }
            self.error = error
        }
    }

    func loadMore(flags: ContentFlags) async {
        guard !isLoading, !atEnd, let last = items.last else { return }
        let version = listVersion
        isLoading = true
        pagingFailed = false
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.items(query, flags: flags, older: query.cursor(for: last))
            guard version == listVersion else { return }
            let known = Set(items.map(\.id))
            items.append(contentsOf: response.items.filter { !known.contains($0.id) })
            atEnd = response.atEnd || response.items.isEmpty
        } catch where error.isCancellation {
        } catch {
            guard version == listVersion else { return }
            pagingFailed = true
        }
    }

    /// Starts the next page without tying it to the caller's task: lazy stacks cancel a page's
    /// task when it scrolls away, and a cancelled page load would never be asked for again.
    func loadMoreIfNeeded(after item: FeedItem, flags: ContentFlags) {
        guard let index = items.firstIndex(of: item), index >= items.count - 12 else { return }
        Task { await loadMore(flags: flags) }
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
