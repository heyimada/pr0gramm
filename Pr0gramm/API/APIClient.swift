import Foundation

enum APIError: LocalizedError {
    case http(Int)
    case server(String)
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .http(429): "Zu viele Anfragen. Bitte kurz warten."
        case .http(403): "Keine Berechtigung."
        case .http(let code): "Serverfehler (\(code))."
        case .server(let message): message
        case .notLoggedIn: "Dafür musst du angemeldet sein."
        }
    }
}

/// Thin wrapper around the (unofficial) pr0gramm JSON API.
/// Authentication lives entirely in cookies (`me`, `pp`), which `HTTPCookieStorage.shared` persists.
final class APIClient {
    static let shared = APIClient()

    private let base = URL(string: "https://pr0gramm.com/api/")!
    private let session: URLSession
    private let decoder = JSONDecoder()

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    // MARK: Transport

    func get<T: Decodable>(_ path: String, _ query: [String: String?] = [:]) async throws -> T {
        var url = base.appending(path: path)
        url.append(queryItems: query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } })
        return try await send(URLRequest(url: url))
    }

    func post<T: Decodable>(_ path: String, _ form: [String: String]) async throws -> T {
        var request = URLRequest(url: base.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        // URLComponents leaves "+" unescaped, which the server would read as a space.
        request.httpBody = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
            .data(using: .utf8)
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let body = try? decoder.decode(ServerError.self, from: data), let message = body.message {
                throw APIError.server(message)
            }
            throw APIError.http(http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }

    private struct ServerError: Decodable {
        let error: String?
        let msg: String?
        var message: String? { msg ?? error }
    }

    // MARK: Endpoints

    func items(_ query: FeedQuery, flags: ContentFlags, older: Int? = nil, around id: Int? = nil) async throws -> FeedResponse {
        var params = query.parameters
        params["flags"] = String(flags.rawValue)
        params["older"] = older.map(String.init)
        params["id"] = id.map(String.init)
        let response: FeedResponse = try await get("items/get", params)
        if let error = response.error { throw APIError.server(Self.describe(feedError: error)) }
        return response
    }

    func itemInfo(_ id: Int) async throws -> ItemInfo {
        try await get("items/info", ["itemId": String(id)])
    }

    func profile(_ name: String, flags: ContentFlags) async throws -> Profile {
        try await get("profile/info", ["name": name, "flags": String(flags.rawValue)])
    }

    func captcha() async throws -> Captcha {
        try await get("user/captcha")
    }

    func login(name: String, password: String, captcha: String, token: String) async throws -> LoginResponse {
        try await post("user/login", ["name": name, "password": password, "captcha": captcha, "token": token])
    }

    func logout(id: String, nonce: String) async throws {
        let _: EmptyResponse = try await post("user/logout", ["id": id, "_nonce": nonce])
    }

    func vote(_ target: VoteTarget, id: Int, vote: Int, nonce: String) async throws {
        let _: EmptyResponse = try await post("\(target.rawValue)/vote", ["id": String(id), "vote": String(vote), "_nonce": nonce])
    }

    func postComment(itemId: Int, parentId: Int, text: String, nonce: String) async throws -> PostCommentResponse {
        try await post("comments/post", [
            "itemId": String(itemId), "parentId": String(parentId), "comment": text, "_nonce": nonce,
        ])
    }

    func sync(offset: Int) async throws -> SyncResponse {
        try await get("user/sync", ["offset": String(offset)])
    }

    private static func describe(feedError: String) -> String {
        switch feedError {
        case "nothingFound": "Nichts gefunden."
        case "tooShort": "Suchbegriff zu kurz."
        case "limitReached": "Suchlimit erreicht."
        default: feedError
        }
    }
}

enum VoteTarget: String {
    case item = "items"
    case comment = "comments"
    case tag = "tags"
}
