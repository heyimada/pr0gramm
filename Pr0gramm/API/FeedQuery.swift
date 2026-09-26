import Foundation

/// The site's streams. "beliebt · neu · müll" are also the categories you can search in.
enum FeedStream: String, Hashable, Codable, CaseIterable, Identifiable {
    case top
    case new
    case junk
    /// Uploads of users you follow ("Abos"); requires login.
    case subscribed

    static let searchable: [FeedStream] = [.top, .new, .junk]

    var id: Self { self }

    var title: String {
        switch self {
        case .new: "neu"
        case .top: "beliebt"
        case .junk: "müll"
        case .subscribed: "abos"
        }
    }
}

/// Describes one stream of items, e.g. "beliebt", a tag search, or a user's uploads.
struct FeedQuery: Hashable, Codable {
    var stream: FeedStream = .top
    var tags: String?
    var user: String?

    static let top = FeedQuery(stream: .top)
    static let new = FeedQuery(stream: .new)

    var title: String { tags ?? user ?? stream.title }

    /// Query parameters as the website sends them for this stream.
    var parameters: [String: String?] {
        var params: [String: String?] = ["tags": tags, "user": user]
        switch stream {
        case .top:
            params["promoted"] = "1"
            params["show_junk"] = "0"
        case .junk:
            params["show_junk"] = "1"
        case .subscribed:
            params["following"] = "1"
        case .new:
            break
        }
        return params
    }

    /// Paging cursor: promoted streams are ordered by promotion id, everything else by item id.
    func cursor(for item: FeedItem) -> Int {
        stream == .top ? item.promoted : item.id
    }
}
