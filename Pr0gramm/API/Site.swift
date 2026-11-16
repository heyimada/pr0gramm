import Foundation

enum Site {
    static let host = "pr0gramm.com"
    static let origin = URL(string: "https://\(host)")!
    static let api = origin.appending(path: "api/")

    static func post(_ id: Int) -> URL {
        origin.appending(path: "new").appending(path: String(id))
    }

    static func user(_ name: String) -> URL {
        origin.appending(path: "user").appending(path: name)
    }

    static func badge(_ image: String) -> URL {
        origin.appending(path: "media/badges").appending(path: image)
    }

    static func isOwn(_ url: URL) -> Bool {
        guard let host = url.host() else { return false }
        return host == Self.host || host.hasSuffix(".\(Self.host)") || host == "pr0.app"
    }
}
