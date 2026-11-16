import Observation

@Observable
final class ItemDetails {
    let itemID: Int
    private(set) var info: ItemInfo?
    private(set) var error: Error?
    var replyTarget: ReplyTarget?

    init(itemID: Int) {
        self.itemID = itemID
    }

    func load() async {
        do {
            info = try await APIClient.shared.itemInfo(itemID)
            error = nil
        } catch where error.isCancellation {
        } catch {
            self.error = error
        }
    }

    func loadIfNeeded() async {
        guard info == nil else { return }
        await load()
    }

    func apply(postedComments comments: [Comment]?) async {
        if let comments, info != nil {
            info?.comments = comments
        } else {
            await load()
        }
    }
}
