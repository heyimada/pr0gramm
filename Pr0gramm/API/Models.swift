import Foundation

/// Content rating bitmask used by the `flags` query parameter.
struct ContentFlags: OptionSet, Hashable, Codable, Sendable {
    let rawValue: Int

    static let sfw = ContentFlags(rawValue: 1)
    static let nsfw = ContentFlags(rawValue: 2)
    static let nsfl = ContentFlags(rawValue: 4)
    static let nsfp = ContentFlags(rawValue: 8)
    static let pol = ContentFlags(rawValue: 16)

    /// Label of the most severe rating contained in the set, as shown on items.
    var badge: String? {
        if contains(.nsfl) { return "NSFL" }
        if contains(.nsfw) { return "NSFW" }
        if contains(.pol) { return "POL" }
        if contains(.nsfp) { return "NSFP" }
        return nil
    }
}

struct FeedResponse: Decodable {
    let atEnd: Bool
    let atStart: Bool
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

    var fullsizeURL: URL? { fullsize.isEmpty ? nil : MediaHost.full.url(fullsize) }
}

struct MediaVariant: Codable, Hashable, Sendable {
    let name: String
    let path: String
    let codec: String?
    let width: Int
    let height: Int
}

struct ItemInfo: Decodable {
    let tags: [Tag]
    let comments: [Comment]
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
        var imageURL: URL { URL(string: "https://pr0gramm.com/media/badges/")!.appending(path: image) }
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
        URL(string: "https://\(rawValue).pr0gramm.com/")!.appending(path: path)
    }
}

/// Official user ranks (`mark` field): colors and names.
enum UserMark {
    static func name(_ mark: Int) -> String {
        switch mark {
        case 1: "Neuschwuchtel"
        case 2: "Altschwuchtel"
        case 3: "Admin"
        case 4: "Gesperrt"
        case 5: "Moderator"
        case 6: "Fliesentischbesitzer"
        case 7: "Lebende Legende"
        case 8: "Wichtler"
        case 9: "Edler Spender"
        case 10: "Mittelaltschwuchtel"
        case 11: "Alt-Moderator"
        case 12: "Communityhelfer"
        case 13: "Nutzer-Bot"
        case 14: "System-Bot"
        case 15: "Alt-Helfer"
        default: "Schwuchtel"
        }
    }

    static func hex(_ mark: Int) -> UInt32 {
        switch mark {
        case 1: 0xE108E9 // Neuschwuchtel
        case 2: 0x5BB91C // Altschwuchtel
        case 3: 0xFF9900 // Admin
        case 4: 0x444444 // Gesperrt
        case 5: 0x008FFF // Moderator
        case 6: 0x6C432B // Fliesentischbesitzer
        case 7: 0x1CB992 // Lebende Legende
        case 8: 0xD23C22 // Wichtler
        case 9: 0x1CB992 // Edler Spender
        case 10: 0xADDC8D // Mittelaltschwuchtel
        case 11: 0x7FC7FF // Alt-Moderator
        case 12: 0xC52B2F // Communityhelfer
        case 13: 0x10366F // Nutzer-Bot
        case 14: 0xFFC166 // System-Bot
        case 15: 0xEA9FA1 // Alt-Helfer
        default: 0xFFFFFF // Schwuchtel
        }
    }
}
