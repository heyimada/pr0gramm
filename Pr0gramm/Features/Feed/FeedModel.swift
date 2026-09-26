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
    private(set) var error: Error?

    @ObservationIgnored private let api: APIClient
    @ObservationIgnored private var loadedFlags: ContentFlags?

    init(query: FeedQuery, api: APIClient = .shared) {
        self.query = query
        self.api = api
    }

    /// A fixed list, e.g. the "Top 10 heute" rail, so it can be opened in the pager.
    init(items: [FeedItem], query: FeedQuery) {
        self.query = query
        self.api = .shared
        self.items = items
        atEnd = true
    }

    /// Loads the first page, or reloads if the content filter changed since the last load.
    func loadIfNeeded(flags: ContentFlags) async {
        guard items.isEmpty || loadedFlags != flags else { return }
        await reload(flags: flags)
    }

    func reload(flags: ContentFlags) async {
        do {
            let response = try await api.items(query, flags: flags)
            items = response.items
            atEnd = response.atEnd
            loadedFlags = flags
            error = nil
        } catch is CancellationError {
        } catch {
            self.error = error
        }
    }

    func loadMore(flags: ContentFlags) async {
        guard !isLoading, !atEnd, let last = items.last else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.items(query, flags: flags, older: query.cursor(for: last))
            let known = Set(items.map(\.id))
            items.append(contentsOf: response.items.filter { !known.contains($0.id) })
            atEnd = response.atEnd || response.items.isEmpty
        } catch {
            // Paging errors are silent; the next scroll attempt retries.
        }
    }

    /// Triggers paging when `item` is close to the end of the list.
    func loadMoreIfNeeded(after item: FeedItem, flags: ContentFlags) async {
        guard let index = items.firstIndex(of: item), index >= items.count - 12 else { return }
        await loadMore(flags: flags)
    }
}
