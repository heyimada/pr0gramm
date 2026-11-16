import Observation

/// Tags and comments of one post, fetched on demand and shared by every view that shows them.
@Observable
final class ItemDetails {
    let itemID: Int
    private(set) var info: ItemInfo?
    private(set) var error: Error?

    init(itemID: Int) {
        self.itemID = itemID
    }

    func load() async {
        do {
            info = try await APIClient.shared.itemInfo(itemID)
            error = nil
        } catch is CancellationError {
        } catch {
            self.error = error
        }
    }

    func loadIfNeeded() async {
        guard info == nil else { return }
        await load()
    }

    /// After posting a comment: swaps in the returned comment list, or reloads when there is none.
    func apply(postedComments comments: [Comment]?) async {
        if let comments, info != nil {
            info?.comments = comments
        } else {
            await load()
        }
    }
}
