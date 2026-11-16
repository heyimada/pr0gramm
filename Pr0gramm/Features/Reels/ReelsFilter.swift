import Observation
import SwiftUI

struct ReelsFilter: Codable, Equatable {
    var onlyVideos = true
    var includedTags: [String] = []
    var excludedTags: [String] = []

    var hasTagFilter: Bool { !includedTags.isEmpty || !excludedTags.isEmpty }

    /// Extended search syntax, e.g. `! video kadse "steile frise" -"süßvieh"`.
    func query(for feed: FeedQuery) -> FeedQuery {
        func quoted(_ tag: String) -> String {
            tag.contains(where: \.isWhitespace) ? "\"\(tag)\"" : tag
        }
        var terms = onlyVideos ? ["video"] : []
        let body = TagQuery(feed.tags ?? "").body
        if !body.isEmpty { terms.append(body) }
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

    mutating func clearTags() {
        includedTags = []
        excludedTags = []
    }
}

@Observable
final class ReelsFilterStore {
    var filter: ReelsFilter {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(filter), forKey: Self.key) }
    }

    private static let key = "reelsFilter"

    init() {
        filter = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(ReelsFilter.self, from: $0) } ?? ReelsFilter()
    }
}
