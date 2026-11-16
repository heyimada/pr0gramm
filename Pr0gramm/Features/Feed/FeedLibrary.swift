import LocalAuthentication
import Observation
import SwiftUI

/// The user's saved tag feeds and the default feed, with the protected-feeds lock.
@Observable
final class FeedLibrary {
    private let session: Session

    /// Feed that Start, the Feed tab and Reels open with. Configured under Einstellungen › Feeds.
    var defaultSource: FeedSource {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(defaultSource), forKey: Self.defaultSourceKey)
        }
    }

    /// Saved tag searches, in the order they appear in the Feed tab.
    var customFeeds: [CustomFeed] {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(customFeeds), forKey: Self.customFeedsKey)
            if case .custom(let id) = defaultSource, customFeed(id) == nil { defaultSource = .stream(.top) }
        }
    }

    /// Whether protected custom feeds are shown. Never stored: every launch starts locked, and the
    /// app locks again whenever it goes to the background.
    private(set) var protectedFeedsUnlocked = false

    private static let defaultSourceKey = "defaultFeed"
    private static let customFeedsKey = "customFeeds"

    init(session: Session) {
        self.session = session
        let defaults = UserDefaults.standard
        customFeeds = defaults.data(forKey: Self.customFeedsKey)
            .flatMap { try? JSONDecoder().decode([CustomFeed].self, from: $0) } ?? []
        defaultSource = defaults.data(forKey: Self.defaultSourceKey)
            .flatMap { try? JSONDecoder().decode(FeedSource.self, from: $0) } ?? .stream(.top)
    }

    func customFeed(_ id: CustomFeed.ID) -> CustomFeed? {
        customFeeds.first { $0.id == id }
    }

    /// `.top` for a custom feed that has since been deleted.
    func query(for source: FeedSource) -> FeedQuery {
        switch source {
        case .stream(let stream): FeedQuery(stream: stream)
        case .custom(let id): customFeed(id)?.query ?? .top
        }
    }

    func title(for source: FeedSource) -> String {
        switch source {
        case .stream(let stream): stream.title
        case .custom(let id): customFeed(id)?.name ?? ""
        }
    }

    /// Stream that tag feeds and searches start in: the default feed's.
    var defaultStream: FeedStream { query(for: defaultSource).stream }

    /// The switcher's entries: beliebt · neu · müll, abos if wanted and logged in, then the visible
    /// custom feeds. Feeds bound to filters that are all off, and locked protected feeds, are left out.
    func sources(withSubscriptions: Bool) -> [FeedSource] {
        FeedStream.searchable.map(FeedSource.stream)
            + (withSubscriptions && session.isLoggedIn ? [.stream(.subscribed)] : [])
            + customFeeds.filter { $0.isVisible(with: session.flags) && isAccessible($0) }.map { .custom($0.id) }
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

    /// What a screen shows: the user's pick, else the default feed, else beliebt when that isn't offered.
    func currentSource(picked: FeedSource?, in sources: [FeedSource]) -> FeedSource {
        let source = picked ?? effectiveDefaultSource
        return sources.contains(source) ? source : .stream(.top)
    }

    // MARK: Protected feeds

    var hasProtectedFeeds: Bool { customFeeds.contains(where: \.isProtected) }

    func isAccessible(_ feed: CustomFeed) -> Bool {
        !feed.isProtected || protectedFeedsUnlocked
    }

    /// Custom feeds that may be shown right now, ignoring the content filter; used for managing them.
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
