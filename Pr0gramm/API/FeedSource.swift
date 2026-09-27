import Foundation

/// A saved tag search that shows up next to beliebt · neu · müll, e.g. "Katzen" for `kadse -süßvieh`.
struct CustomFeed: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    /// Tags as typed in the search, optionally in extended syntax (`! kadse s:1000`).
    var tags: String
    var stream: FeedStream = .top

    var query: FeedQuery {
        let tags = tags.trimmingCharacters(in: .whitespaces)
        // Excluding tags only works in the extended syntax, which starts with "!".
        let needsExtended = !tags.hasPrefix("!") && tags.split(whereSeparator: \.isWhitespace).contains { $0.hasPrefix("-") }
        return FeedQuery(stream: stream, tags: needsExtended ? "! " + tags : tags)
    }

    /// A feed prefilled from a tag search, named after its tags.
    init(query: FeedQuery) {
        let tags = query.tags ?? ""
        var name = tags
        if name.hasPrefix("!") { name.removeFirst() }
        self.name = name.trimmingCharacters(in: .whitespaces)
        self.tags = tags
        stream = query.stream
    }

    init(name: String = "", tags: String = "", stream: FeedStream = .top) {
        self.name = name
        self.tags = tags
        self.stream = stream
    }
}

/// One entry of the Feed tab's switcher and of the "Standard-Feed" setting.
enum FeedSource: Hashable, Codable {
    case stream(FeedStream)
    case custom(CustomFeed.ID)
}
