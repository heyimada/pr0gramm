import Foundation
import Observation

/// Login state, content settings and the user's votes.
@Observable
final class Session {
    private(set) var userName: String?
    /// The logged-in user's Benis, shown in the side menu.
    private(set) var userScore: Int?
    private(set) var isSyncing = false

    /// Content ratings the user wants to see. Only applied while logged in; guests always get SFW.
    var selectedFlags: ContentFlags {
        didSet { defaults.set(selectedFlags.rawValue, forKey: Keys.flags) }
    }

    /// Starts every launch with only SFW, whatever was selected before.
    var resetsFlagsOnLaunch: Bool {
        didSet { defaults.set(resetsFlagsOnLaunch, forKey: Keys.resetsFlags) }
    }

    var autoplayVideos: Bool {
        didSet { defaults.set(autoplayVideos, forKey: Keys.autoplay) }
    }

    var startMuted: Bool {
        didSet { defaults.set(startMuted, forKey: Keys.muted) }
    }

    private(set) var itemVotes: [Int: Int] = [:]
    private(set) var commentVotes: [Int: Int] = [:]
    private(set) var tagVotes: [Int: Int] = [:]

    private let api: APIClient
    private let defaults: UserDefaults
    private var syncOffset: Int

    var isLoggedIn: Bool { userName != nil }
    var flags: ContentFlags { isLoggedIn && !selectedFlags.isEmpty ? selectedFlags : .sfw }

    init(api: APIClient = .shared, defaults: UserDefaults = .standard) {
        self.api = api
        self.defaults = defaults
        let resetsFlags = defaults.bool(forKey: Keys.resetsFlags)
        resetsFlagsOnLaunch = resetsFlags
        selectedFlags = resetsFlags
            ? .sfw
            : ContentFlags(rawValue: defaults.object(forKey: Keys.flags) as? Int ?? ContentFlags.sfw.rawValue)
        autoplayVideos = defaults.object(forKey: Keys.autoplay) as? Bool ?? true
        startMuted = defaults.object(forKey: Keys.muted) as? Bool ?? true
        syncOffset = defaults.integer(forKey: Keys.syncOffset)
        loadVotes()
        refreshFromCookie()
    }

    // MARK: Auth

    /// The `me` cookie is URL-encoded JSON like `{"n":"name","id":"<32 hex chars>",...}`.
    private var meCookie: (name: String, id: String)? {
        guard let cookie = HTTPCookieStorage.shared.cookies(for: URL(string: "https://pr0gramm.com")!)?
            .first(where: { $0.name == "me" }),
            let json = cookie.value.removingPercentEncoding?.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
            let name = object["n"] as? String,
            let id = object["id"] as? String
        else { return nil }
        return (name, id)
    }

    /// CSRF token the API expects as `_nonce` on every mutating request.
    private var nonce: String? { meCookie.map { String($0.id.prefix(16)) } }

    func refreshFromCookie() {
        userName = meCookie?.name
    }

    func captcha() async throws -> Captcha {
        try await api.captcha()
    }

    func login(name: String, password: String, captcha: String, token: String) async throws {
        let response = try await api.login(name: name, password: password, captcha: captcha, token: token)
        guard response.success else {
            let message = switch response.error {
            case "invalidCaptcha": "Das Captcha war falsch."
            case "invalidLogin": "Benutzername oder Passwort falsch."
            case "banned": "Dieser Account ist gesperrt."
            default: response.error ?? "Anmeldung fehlgeschlagen."
            }
            throw APIError.server(message)
        }
        refreshFromCookie()
        await sync()
    }

    func logout() async {
        if let me = meCookie, let nonce {
            try? await api.logout(id: me.id, nonce: nonce)
        }
        let storage = HTTPCookieStorage.shared
        storage.cookies(for: URL(string: "https://pr0gramm.com")!)?.forEach(storage.deleteCookie)
        userName = nil
        userScore = nil
        itemVotes = [:]
        commentVotes = [:]
        tagVotes = [:]
        syncOffset = 0
        saveVotes()
    }

    // MARK: Votes

    func vote(for target: VoteTarget, id: Int) -> Int {
        switch target {
        case .item: itemVotes[id] ?? 0
        case .comment: commentVotes[id] ?? 0
        case .tag: tagVotes[id] ?? 0
        }
    }

    /// Casts `value` (-1, 0, 1), updating local state optimistically and rolling back on failure.
    func vote(_ target: VoteTarget, id: Int, value: Int) async throws {
        guard let nonce else { throw APIError.notLoggedIn }
        let previous = vote(for: target, id: id)
        setVote(target, id: id, value: value)
        do {
            try await api.vote(target, id: id, vote: value, nonce: nonce)
            saveVotes()
        } catch {
            setVote(target, id: id, value: previous)
            throw error
        }
    }

    func postComment(itemId: Int, parentId: Int, text: String) async throws -> [Comment]? {
        guard let nonce else { throw APIError.notLoggedIn }
        return try await api.postComment(itemId: itemId, parentId: parentId, text: text, nonce: nonce).comments
    }

    private func setVote(_ target: VoteTarget, id: Int, value: Int) {
        switch target {
        case .item: itemVotes[id] = value
        case .comment: commentVotes[id] = value
        case .tag: tagVotes[id] = value
        }
    }

    /// Pulls the vote log the server keeps for this account, so votes cast elsewhere show up here.
    /// The log is a sequence of 5-byte records: little-endian Int32 id followed by an action byte.
    func sync() async {
        guard let userName, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        userScore = try? await api.profile(userName, flags: flags).user.score
        guard let response = try? await api.sync(offset: syncOffset) else { return }
        if let log = response.log, let data = Data(base64Encoded: log) {
            let bytes = [UInt8](data)
            for start in stride(from: 0, to: bytes.count - 4, by: 5) {
                let id = Int(UInt32(bytes[start]) | UInt32(bytes[start + 1]) << 8
                    | UInt32(bytes[start + 2]) << 16 | UInt32(bytes[start + 3]) << 24)
                apply(action: bytes[start + 4], id: id)
            }
        }
        if let length = response.logLength { syncOffset = length }
        saveVotes()
    }

    private func apply(action: UInt8, id: Int) {
        switch action {
        case 1...3: itemVotes[id] = Int(action) - 2
        case 4...6: commentVotes[id] = Int(action) - 5
        case 7...9: tagVotes[id] = Int(action) - 8
        default: break
        }
    }

    // MARK: Persistence

    private struct StoredVotes: Codable {
        var items: [Int: Int]
        var comments: [Int: Int]
        var tags: [Int: Int]
    }

    private func loadVotes() {
        guard let data = defaults.data(forKey: Keys.votes),
              let stored = try? JSONDecoder().decode(StoredVotes.self, from: data) else { return }
        itemVotes = stored.items
        commentVotes = stored.comments
        tagVotes = stored.tags
    }

    private func saveVotes() {
        let stored = StoredVotes(items: itemVotes, comments: commentVotes, tags: tagVotes)
        defaults.set(try? JSONEncoder().encode(stored), forKey: Keys.votes)
        defaults.set(syncOffset, forKey: Keys.syncOffset)
    }

    private enum Keys {
        static let flags = "contentFlags"
        static let resetsFlags = "resetsFlagsOnLaunch"
        static let autoplay = "autoplayVideos"
        static let muted = "startMuted"
        static let votes = "votes"
        static let syncOffset = "syncOffset"
    }
}
