import Foundation

/// Content rating bitmask used by the `flags` query parameter.
struct ContentFlags: OptionSet, Hashable, Codable, Sendable {
    let rawValue: Int

    static let sfw = ContentFlags(rawValue: 1)
    static let nsfw = ContentFlags(rawValue: 2)
    static let nsfl = ContentFlags(rawValue: 4)
    static let nsfp = ContentFlags(rawValue: 8)
    static let pol = ContentFlags(rawValue: 16)

    /// The filters a user can switch, in the order the settings show them.
    static let filters: [(flag: ContentFlags, title: String, subtitle: String)] = [
        (.sfw, "SFW", "Safe for work"),
        (.nsfw, "NSFW", "Nackte Haut, Pornos und leicht offensiver Kram"),
        (.nsfl, "NSFL", "Alles. Gewalt, ekliger Scheiß"),
        (.pol, "POL", "Politik, Wirtschaft, Kriminalität, Konflikte"),
    ]

    static let switchable = filters.reduce(into: ContentFlags()) { $0.formUnion($1.flag) }

    static func filterTitles(in flags: ContentFlags) -> [String] {
        filters.filter { flags.contains($0.flag) }.map(\.title)
    }
}

struct FeedResponse: Decodable {
    let atEnd: Bool
    let error: String?
    let items: [FeedItem]
}

struct FeedItem: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let promoted: Int
    let userId: Int
    let up: Int
    let down: Int
    let created: Int
    let image: String
    let thumb: String
    let fullsize: String
    let preview: String?
    let width: Int
    let height: Int
    let audio: Bool
    let source: String?
    let flags: Int
    let user: String
    let mark: Int
    let variants: [MediaVariant]?

    var score: Int { up - down }
    var createdAt: Date { Date(timeIntervalSince1970: TimeInterval(created)) }
    var contentFlags: ContentFlags { ContentFlags(rawValue: flags) }
    var aspectRatio: CGFloat { height > 0 ? CGFloat(width) / CGFloat(height) : 1 }

    var isVideo: Bool {
        let ext = (image as NSString).pathExtension.lowercased()
        return ext == "mp4" || ext == "webm"
    }

    var thumbnailURL: URL { MediaHost.thumb.url(thumb) }

    var mediaURL: URL {
        if isVideo {
            // AVPlayer can't decode VP9/WebM, so prefer the best H.264 variant when the default isn't one.
            let h264 = variants?.filter { $0.codec == "h264" }.max { $0.width < $1.width }
            if image.hasSuffix(".webm"), let h264 { return MediaHost.video.url(h264.path) }
            return MediaHost.video.url(image)
        }
        return MediaHost.image.url(image)
    }

    var webURL: URL { Site.post(id) }

    var fullsizeURL: URL? { fullsize.isEmpty ? nil : MediaHost.full.url(fullsize) }

    var sourceURL: URL? {
        guard let source,
              let url = URL(string: source.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

struct MediaVariant: Codable, Hashable, Sendable {
    let name: String
    let path: String
    let codec: String?
    let width: Int
    let height: Int
}

struct ItemInfo: Decodable {
    /// Highest confidence first.
    let tags: [Tag]
    var comments: [Comment]

    private enum CodingKeys: String, CodingKey { case tags, comments }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tags = try container.decode([Tag].self, forKey: .tags).sorted { $0.confidence > $1.confidence }
        comments = try container.decode([Comment].self, forKey: .comments)
    }
}

struct Tag: Decodable, Identifiable, Hashable {
    let id: Int
    let confidence: Double
    let tag: String
}

struct Comment: Decodable, Identifiable, Hashable {
    let id: Int
    let parent: Int
    let content: String
    let created: Int
    let up: Int
    let down: Int
    let confidence: Double
    let name: String
    let mark: Int

    var score: Int { up - down }
    var createdAt: Date { Date(timeIntervalSince1970: TimeInterval(created)) }
}

struct Profile: Decodable {
    struct User: Decodable {
        let id: Int
        let name: String
        let registered: Int
        let score: Int
        let mark: Int
        let banned: Int?

        var registeredAt: Date { Date(timeIntervalSince1970: TimeInterval(registered)) }
    }

    struct Badge: Decodable, Hashable {
        let image: String
        let description: String?
        var imageURL: URL { Site.badge(image) }
    }

    let user: User
    let commentCount: Int?
    let uploadCount: Int?
    let tagCount: Int?
    let badges: [Badge]?
}

struct Captcha: Decodable {
    let token: String
    /// `data:image/png;base64,...` URL of the captcha image.
    let captcha: String

    var imageData: Data? {
        guard let comma = captcha.firstIndex(of: ",") else { return nil }
        return Data(base64Encoded: String(captcha[captcha.index(after: comma)...]))
    }
}

struct LoginResponse: Decodable {
    let success: Bool
    let error: String?
}

struct SyncResponse: Decodable {
    let log: String?
    let logLength: Int?
}

struct PostCommentResponse: Decodable {
    let commentId: Int?
    let comments: [Comment]?
}

struct EmptyResponse: Decodable {}

enum MediaHost: String {
    case image = "img"
    case video = "vid"
    case thumb = "thumb"
    case full = "full"

    func url(_ path: String) -> URL {
        URL(string: "https://\(rawValue).\(Site.host)/")!.appending(path: path)
    }
}

/// Official user ranks (`mark` field): colors and names.
enum UserMark {
    private static let ranks: [Int: (name: String, color: UInt32)] = [
        1: ("Neuschwuchtel", 0xE108E9),
        2: ("Altschwuchtel", 0x5BB91C),
        3: ("Admin", 0xFF9900),
        4: ("Gesperrt", 0x444444),
        5: ("Moderator", 0x008FFF),
        6: ("Fliesentischbesitzer", 0x6C432B),
        7: ("Lebende Legende", 0x1CB992),
        8: ("Wichtler", 0xD23C22),
        9: ("Edler Spender", 0x1CB992),
        10: ("Mittelaltschwuchtel", 0xADDC8D),
        11: ("Alt-Moderator", 0x7FC7FF),
        12: ("Communityhelfer", 0xC52B2F),
        13: ("Nutzer-Bot", 0x10366F),
        14: ("System-Bot", 0xFFC166),
        15: ("Alt-Helfer", 0xEA9FA1),
    ]
    private static let fallback: (name: String, color: UInt32) = ("Schwuchtel", 0xFFFFFF)

    static func name(_ mark: Int) -> String { (ranks[mark] ?? fallback).name }

    static func hex(_ mark: Int) -> UInt32 { (ranks[mark] ?? fallback).color }
}
