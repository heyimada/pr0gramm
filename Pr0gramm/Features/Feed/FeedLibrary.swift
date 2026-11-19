import LocalAuthentication
import Observation
import SwiftUI

@Observable
final class FeedLibrary {
    private let session: Session

    var defaultSource: FeedSource {
        didSet {
            UserDefaults.standard.setEncoded(defaultSource, forKey: Self.defaultSourceKey)
        }
    }

    private(set) var customFeeds: [CustomFeed] {
        didSet {
            UserDefaults.standard.setEncoded(customFeeds, forKey: Self.customFeedsKey)
            if case .custom(let id) = defaultSource, customFeed(id) == nil { defaultSource = .stream(.top) }
        }
    }

    /// Whether protected custom feeds are shown. Never stored: every launch starts locked, and the
    /// app locks again whenever it goes to the background.
    private(set) var protectedFeedsUnlocked = false

    /// Zufall's selection for this launch, so its pages keep one order while scrolling.
    private let randomSeed = Int(Date().timeIntervalSince1970)

    private static let defaultSourceKey = "defaultFeed"
    private static let customFeedsKey = "customFeeds"

    init(session: Session) {
        self.session = session
        let defaults = UserDefaults.standard
        customFeeds = defaults.decoded([CustomFeed].self, forKey: Self.customFeedsKey) ?? []
        defaultSource = defaults.decoded(FeedSource.self, forKey: Self.defaultSourceKey) ?? .stream(.top)
    }

    func customFeed(_ id: CustomFeed.ID) -> CustomFeed? {
        customFeeds.first { $0.id == id }
    }

    func query(for source: FeedSource) -> FeedQuery {
        switch source {
        case .stream(let stream): FeedQuery(stream: stream)
        case .preset(let preset): preset.query(seed: randomSeed)
        case .custom(let id): customFeed(id)?.query ?? .top
        }
    }

    func title(for source: FeedSource) -> String {
        switch source {
        case .stream(let stream): stream.title
        case .preset(let preset): preset.title
        case .custom(let id): customFeed(id)?.name ?? ""
        }
    }

    var defaultStream: FeedStream { query(for: defaultSource).stream }

    /// The switcher's entries: beliebt · neu · müll, abos if wanted and logged in, then the visible
    /// custom feeds. Feeds bound to filters that are all off, and locked protected feeds, are left out.
    ///
    /// The presets are picked from the feed menu only. The last picked preset is appended as the last
    /// page, because the pager builds every page up front and each one loads its feed.
    func sources(withSubscriptions: Bool, picked: FeedSource? = nil) -> [FeedSource] {
        let base = (FeedStream.searchable + (withSubscriptions ? [.subscribed] : []))
            .filter { session.isLoggedIn || !$0.requiresLogin }.map(FeedSource.stream)
            + customFeeds.filter { $0.isVisible(with: session.flags) && isAccessible($0) }.map { .custom($0.id) }
        guard let picked, case .preset = picked else { return base }
        return base + [picked]
    }

    /// The default feed, or its stream while the custom default is hidden by the content filter
    /// or locked.
    var effectiveDefaultSource: FeedSource {
        if case .custom(let id) = defaultSource, let feed = customFeed(id),
           !feed.isVisible(with: session.flags) || !isAccessible(feed) {
            return .stream(feed.stream)
        }
        return defaultSource
    }

    func currentSource(picked: FeedSource?, in sources: [FeedSource]) -> FeedSource {
        let source = picked ?? effectiveDefaultSource
        return sources.contains(source) ? source : .stream(.top)
    }

    func save(_ feed: CustomFeed, makeDefault: Bool) {
        if let index = customFeeds.firstIndex(where: { $0.id == feed.id }) {
            customFeeds[index] = feed
        } else {
            customFeeds.append(feed)
        }
        if makeDefault {
            defaultSource = .custom(feed.id)
        } else if defaultSource == .custom(feed.id) {
            defaultSource = .stream(feed.stream)
        }
    }

    func remove(_ id: CustomFeed.ID) {
        customFeeds.removeAll { $0.id == id }
    }

    /// Moves within the shown feeds while locked protected feeds keep their places.
    func moveAccessible(from offsets: IndexSet, to offset: Int) {
        var shown = accessibleCustomFeeds
        shown.move(fromOffsets: offsets, toOffset: offset)
        var reordered = shown.makeIterator()
        customFeeds = customFeeds.map { isAccessible($0) ? reordered.next()! : $0 }
    }

    // MARK: Protected feeds

    var hasProtectedFeeds: Bool { customFeeds.contains(where: \.isProtected) }

    func isAccessible(_ feed: CustomFeed) -> Bool {
        !feed.isProtected || protectedFeedsUnlocked
    }

    var accessibleCustomFeeds: [CustomFeed] { customFeeds.filter(isAccessible) }

    /// Asks for Face ID (or the device passcode) before showing protected feeds.
    func unlockProtectedFeeds() async {
        let context = LAContext()
        let unlocked = (try? await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                          localizedReason: "Geschützte Feeds anzeigen")) ?? false
        withAnimation { protectedFeedsUnlocked = unlocked }
    }

    func lockProtectedFeeds() {
        guard protectedFeedsUnlocked else { return }
        withAnimation { protectedFeedsUnlocked = false }
    }
}
