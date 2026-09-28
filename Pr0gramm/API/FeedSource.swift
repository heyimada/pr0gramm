import Foundation

/// A saved tag search that shows up next to beliebt · neu · müll, e.g. "Katzen" for `kadse -süßvieh`.
struct CustomFeed: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    /// Tags as typed in the search, optionally in extended syntax (`! kadse s:1000`).
    var tags: String
    var stream: FeedStream = .top
    /// Content filters the feed is bound to; empty means always shown.
    var flags: ContentFlags = []
    /// Hidden everywhere until unlocked with Face ID, see `AppState.unlockProtectedFeeds()`.
    var isProtected = false

    /// Shown only while every active filter is one of its own, e.g. an NSFW-bound feed while NSFW
    /// is the only filter on, but not with SFW on as well.
    func isVisible(with active: ContentFlags) -> Bool {
        let switchable: ContentFlags = [.sfw, .nsfw, .nsfl, .pol]
        return flags.isEmpty || flags.isSuperset(of: active.intersection(switchable))
    }

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

    private enum CodingKeys: String, CodingKey {
        case id, name, tags, stream, flags, isProtected
    }

    /// Feeds saved before `flags` and `isProtected` existed decode as always shown.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tags = try container.decode(String.self, forKey: .tags)
        stream = try container.decode(FeedStream.self, forKey: .stream)
        flags = try container.decodeIfPresent(ContentFlags.self, forKey: .flags) ?? []
        isProtected = try container.decodeIfPresent(Bool.self, forKey: .isProtected) ?? false
    }
}

/// One entry of the Feed tab's switcher and of the "Standard-Feed" setting.
nonisolated enum FeedSource: Hashable, Codable, Sendable {
    case stream(FeedStream)
    case custom(CustomFeed.ID)
}
