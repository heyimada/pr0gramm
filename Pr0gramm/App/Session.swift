import Foundation
import Observation
import SwiftUI

@Observable
final class Session {
    private(set) var userName: String?
    private(set) var userScore: Int?
    @ObservationIgnored private var isSyncing = false

    /// Content ratings the user wants to see. Only applied while logged in; guests always get SFW.
    var selectedFlags: ContentFlags {
        didSet { defaults.set(selectedFlags.rawValue, forKey: Keys.flags) }
    }

    /// Starts every launch with only SFW, whatever was selected before.
    var resetsFlagsOnLaunch: Bool {
        didSet { defaults.set(resetsFlagsOnLaunch, forKey: Keys.resetsFlags) }
    }

    private(set) var votes: [VoteTarget: [Int: Int]] = [:]
    /// The vote each server copy of a post (its id and counts) was first shown with.
    @ObservationIgnored private var votesWhenFirstShown: [ServerCopy: Int] = [:]
    private struct ServerCopy: Hashable { let id, up, down: Int }

    private let defaults: UserDefaults
    private var syncOffset: Int

    var isLoggedIn: Bool { userName != nil }
    var flags: ContentFlags { isLoggedIn && !selectedFlags.isEmpty ? selectedFlags : .sfw }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let resetsFlags = defaults.bool(forKey: Keys.resetsFlags)
        resetsFlagsOnLaunch = resetsFlags
        selectedFlags = resetsFlags
            ? .sfw
            : ContentFlags(rawValue: defaults.object(forKey: Keys.flags) as? Int ?? ContentFlags.sfw.rawValue)
        syncOffset = defaults.integer(forKey: Keys.syncOffset)
        loadVotes()
        refreshFromCookie()
    }

    // MARK: Auth

    /// The `me` cookie is URL-encoded JSON like `{"n":"name","id":"<32 hex chars>",...}`.
    private var meCookie: (name: String, id: String)? {
        guard let cookie = HTTPCookieStorage.shared.cookies(for: Site.origin)?
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

    private func refreshFromCookie() {
        userName = meCookie?.name
    }

    func filterBinding(_ flag: ContentFlags) -> Binding<Bool> {
        Binding {
            self.flags.contains(flag)
        } set: { isOn in
            if isOn { self.selectedFlags.insert(flag) } else { self.selectedFlags.remove(flag) }
        }
    }

    func login(name: String, password: String, captcha: String, token: String) async throws {
        let response = try await APIClient.shared.login(name: name, password: password, captcha: captcha, token: token)
        guard response.success else {
            let message = switch response.error {
            case "invalidCaptcha": "Das Captcha war falsch."
            case "invalidLogin": "Benutzername oder Passwort falsch."
            case "banned": "Dieser Account ist gesperrt."
            default: response.error ?? "Anmeldung fehlgeschlagen."
            }
            throw APIError.message(message)
        }
        refreshFromCookie()
        await sync()
    }

    func logout() async {
        if let me = meCookie, let nonce {
            try? await APIClient.shared.logout(id: me.id, nonce: nonce)
        }
        let storage = HTTPCookieStorage.shared
        storage.cookies(for: Site.origin)?.forEach(storage.deleteCookie)
        userName = nil
        userScore = nil
        votes = [:]
        votesWhenFirstShown = [:]
        syncOffset = 0
        saveVotes()
    }

    // MARK: Votes

    func vote(for target: VoteTarget, id: Int) -> Int {
        votes[target]?[id] ?? 0
    }

    /// The server's up and down counts already include the vote it had when the post was loaded,
    /// so only changes made since then are added. That vote is taken as the one this server copy
    /// of the post was first shown with; a reloaded copy with new counts starts over.
    func score(of item: FeedItem) -> Int {
        let vote = vote(for: .item, id: item.id)
        let copy = ServerCopy(id: item.id, up: item.up, down: item.down)
        let known = votesWhenFirstShown[copy] ?? vote
        votesWhenFirstShown[copy] = known
        return item.score + vote - known
    }

    func toggleVote(_ target: VoteTarget, id: Int, _ value: Int) async throws {
        try await vote(target, id: id, value: vote(for: target, id: id) == value ? 0 : value)
    }

    private func vote(_ target: VoteTarget, id: Int, value: Int) async throws {
        guard let nonce else { throw APIError.notLoggedIn }
        let previous = vote(for: target, id: id)
        votes[target, default: [:]][id] = value
        do {
            try await APIClient.shared.vote(target, id: id, vote: value, nonce: nonce)
            saveVotes()
        } catch {
            votes[target, default: [:]][id] = previous
            throw error
        }
    }

    func postComment(itemId: Int, parentId: Int, text: String) async throws -> [Comment]? {
        guard let nonce else { throw APIError.notLoggedIn }
        return try await APIClient.shared.postComment(itemId: itemId, parentId: parentId, text: text, nonce: nonce).comments
    }

    /// The vote log the server keeps is a sequence of 5-byte records: little-endian Int32 id followed by an action byte.
    func sync() async {
        guard let userName, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        if let score = try? await APIClient.shared.profile(userName, flags: flags).user.score {
            userScore = score
        }
        guard let response = try? await APIClient.shared.sync(offset: syncOffset) else { return }
        if let log = response.log, let data = Data(base64Encoded: log) {
            for entry in Self.votes(fromLog: data) {
                votes[entry.target, default: [:]][entry.id] = entry.value
            }
            // Votes learned from the log were already in the counts of every post shown so far.
            votesWhenFirstShown = [:]
        }
        if let length = response.logLength { syncOffset = length }
        saveVotes()
    }

    static func votes(fromLog data: Data) -> [(target: VoteTarget, id: Int, value: Int)] {
        let bytes = [UInt8](data)
        return stride(from: 0, to: bytes.count - 4, by: 5).compactMap { start in
            let id = Int(UInt32(bytes[start]) | UInt32(bytes[start + 1]) << 8
                | UInt32(bytes[start + 2]) << 16 | UInt32(bytes[start + 3]) << 24)
            let action = Int(bytes[start + 4])
            return switch action {
            case 1...3: (.item, id, action - 2)
            case 4...6: (.comment, id, action - 5)
            case 7...9: (.tag, id, action - 8)
            default: nil
            }
        }
    }

    // MARK: Persistence

    private struct StoredVotes: Codable {
        var items: [Int: Int]
        var comments: [Int: Int]
        var tags: [Int: Int]
    }

    private func loadVotes() {
        guard let stored = defaults.decoded(StoredVotes.self, forKey: Keys.votes) else { return }
        votes = [.item: stored.items, .comment: stored.comments, .tag: stored.tags]
    }

    private func saveVotes() {
        let stored = StoredVotes(items: votes[.item] ?? [:], comments: votes[.comment] ?? [:], tags: votes[.tag] ?? [:])
        defaults.setEncoded(stored, forKey: Keys.votes)
        defaults.set(syncOffset, forKey: Keys.syncOffset)
    }

    private enum Keys {
        static let flags = "contentFlags"
        static let resetsFlags = "resetsFlagsOnLaunch"
        static let votes = "votes"
        static let syncOffset = "syncOffset"
    }
}
