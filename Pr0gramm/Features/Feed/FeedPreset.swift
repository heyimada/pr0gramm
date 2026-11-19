import Foundation

/// Feeds from the website's sidebar that are saved searches rather than streams of their own.
nonisolated enum FeedPreset: String, Hashable, Codable, CaseIterable, Sendable {
    case bestOf
    case controversial
    case random

    var title: String {
        switch self {
        case .bestOf: "Best of"
        case .controversial: "Kontrovers"
        case .random: "Zufall"
        }
    }

    var symbol: String {
        switch self {
        case .bestOf: "trophy"
        case .controversial: "flame"
        case .random: "shuffle"
        }
    }

    /// The queries the website's sidebar links to. `seed` picks Zufall's selection, so one seed
    /// keeps its pages in a stable order while it is scrolled.
    func query(seed: Int) -> FeedQuery {
        switch self {
        case .bestOf: FeedQuery(stream: .top, tags: "! s:600")
        case .controversial: FeedQuery(stream: .new, tags: "! f:controversial")
        case .random: FeedQuery(stream: .new, tags: "!-(x:random | x:\(seed))")
        }
    }
}
