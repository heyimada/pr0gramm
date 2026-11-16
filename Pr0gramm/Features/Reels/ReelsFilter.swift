import SwiftUI

/// What the Reels tab narrows every feed to: media type and tags to include or exclude. Persisted.
struct ReelsFilter: Codable, Equatable {
    var onlyVideos = true
    var includedTags: [String] = []
    var excludedTags: [String] = []

    var hasTagFilter: Bool { !includedTags.isEmpty || !excludedTags.isEmpty }

    /// `feed` narrowed down as an extended search, e.g. `! video kadse "steile frise" -"süßvieh"`.
    func query(for feed: FeedQuery) -> FeedQuery {
        func quoted(_ tag: String) -> String {
            tag.contains(where: \.isWhitespace) ? "\"\(tag)\"" : tag
        }
        var terms = onlyVideos ? ["video"] : []
        if var tags = feed.tags?.trimmingCharacters(in: .whitespaces), !tags.isEmpty {
            if tags.hasPrefix("!") { tags.removeFirst() }
            terms.append(tags.trimmingCharacters(in: .whitespaces))
        }
        terms += includedTags.map(quoted)
        terms += excludedTags.map { "-\"\($0)\"" }
        return FeedQuery(stream: feed.stream, tags: terms.isEmpty ? nil : "! " + terms.joined(separator: " "))
    }

    mutating func include(_ tag: String) {
        let tag = tag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !includedTags.contains(tag) else { return }
        excludedTags.removeAll { $0 == tag }
        includedTags.append(tag)
    }

    mutating func exclude(_ tag: String) {
        let tag = tag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !excludedTags.contains(tag) else { return }
        includedTags.removeAll { $0 == tag }
        excludedTags.append(tag)
    }

    static func load() -> ReelsFilter {
        guard let data = UserDefaults.standard.data(forKey: "reelsFilter"),
              let filter = try? JSONDecoder().decode(ReelsFilter.self, from: data) else { return ReelsFilter() }
        return filter
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: "reelsFilter")
    }
}
