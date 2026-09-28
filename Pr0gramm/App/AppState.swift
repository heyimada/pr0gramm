import LocalAuthentication
import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case top, new, junk, subscribed, home, feed, reels, profile, downloads, search

    static let defaultOrder: [AppTab] = [.home, .feed, .reels, .search]
    /// More than this on an iPhone and UIKit folds the rest into a "More" tab.
    static let compactLimit = 5

    var id: Self { self }

    var title: String {
        switch self {
        case .top: "Beliebt"
        case .new: "Neu"
        case .junk: "Müll"
        case .subscribed: "Abos"
        case .home: "Start"
        case .feed: "Feed"
        case .reels: "Reels"
        case .profile: "Profil"
        case .downloads: "Downloads"
        case .search: "Suche"
        }
    }

    var symbol: String {
        switch self {
        case .top: "megaphone.fill"
        case .new: "clock.fill"
        case .junk: "trash.fill"
        case .subscribed: "photo.on.rectangle.angled"
        case .home: "house.fill"
        case .feed: "square.grid.3x3.fill"
        case .reels: "play.rectangle.on.rectangle.fill"
        case .profile: "person.crop.circle.fill"
        case .downloads: "arrow.down.circle.fill"
        case .search: "magnifyingglass"
        }
    }

    var summary: String {
        switch self {
        case .top: "Promoted Posts"
        case .new: "Alle neuen Posts"
        case .junk: "Posts, die es nicht nach beliebt geschafft haben"
        case .subscribed: "Posts von Leuten, denen du folgst (nur angemeldet)"
        case .home: "Nr. 1 heute, Top 10 und beliebt"
        case .feed: "Alle Streams mit Umschalter"
        case .reels: "Vollbild-Feed zum Durchwischen"
        case .profile: "Dein Profil"
        case .downloads: "Offline gespeicherte Posts"
        case .search: "Tag-Suche mit erweiterten Optionen"
        }
    }

    /// The stream shown by the single-stream tabs.
    var stream: FeedStream? {
        switch self {
        case .top: .top
        case .new: .new
        case .junk: .junk
        case .subscribed: .subscribed
        default: nil
        }
    }
}

/// Selected tab, the user's tab bar configuration, one navigation path per tab, and app-wide sheets.
@Observable
final class AppState {
    var tab: AppTab
    var showsLogin = false
    var showsSettings = false
    var search = SearchOptions()

    /// Tabs shown in the tab bar, in order. Configured under Einstellungen › Navigation.
    var tabOrder: [AppTab] {
        didSet { UserDefaults.standard.set(tabOrder.map(\.rawValue), forKey: Self.tabOrderKey) }
    }

    /// Feed that Start, the Feed tab and Reels open with. Configured under Einstellungen › Feeds.
    var defaultSource: FeedSource {
        didSet {
            UserDefaults.standard.set(try? JSONEncoder().encode(defaultSource), forKey: Self.defaultSourceKey)
            search.stream = defaultStream
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

    /// Versioned so a changed default reaches everyone once; older configurations are ignored.
    private static let tabOrderKey = "tabOrder.v2"
    private static let defaultSourceKey = "defaultFeed"
    private static let customFeedsKey = "customFeeds"

    let routers: [AppTab: Router] = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, Router()) })

    var router: Router { routers[tab]! }

    init() {
        let stored = (UserDefaults.standard.stringArray(forKey: Self.tabOrderKey) ?? []).compactMap(AppTab.init(rawValue:))
        let order = stored.isEmpty ? AppTab.defaultOrder : stored
        tab = order.first ?? .top
        tabOrder = order

        let defaults = UserDefaults.standard
        let feeds = defaults.data(forKey: Self.customFeedsKey)
            .flatMap { try? JSONDecoder().decode([CustomFeed].self, from: $0) } ?? []
        customFeeds = feeds
        let source = defaults.data(forKey: Self.defaultSourceKey)
            .flatMap { try? JSONDecoder().decode(FeedSource.self, from: $0) } ?? .stream(.top)
        defaultSource = source
        search.stream = defaultStream
    }

    func customFeed(_ id: CustomFeed.ID) -> CustomFeed? {
        customFeeds.first { $0.id == id }
    }

    /// `nil` for a custom feed that has since been deleted.
    func query(for source: FeedSource) -> FeedQuery? {
        switch source {
        case .stream(let stream): FeedQuery(stream: stream)
        case .custom(let id): customFeed(id)?.query
        }
    }

    func title(for source: FeedSource) -> String {
        switch source {
        case .stream(let stream): stream.title
        case .custom(let id): customFeed(id)?.name ?? ""
        }
    }

    var defaultQuery: FeedQuery { query(for: defaultSource) ?? .top }

    /// The switcher's entries: beliebt · neu · müll, abos if wanted, then the visible custom feeds.
    func feedSources(for flags: ContentFlags, includesSubscriptions: Bool) -> [FeedSource] {
        FeedStream.searchable.map(FeedSource.stream)
            + (includesSubscriptions ? [.stream(.subscribed)] : [])
            + visibleCustomFeeds(for: flags).map { .custom($0.id) }
    }

    /// Custom feeds bound to filters that are all off, and locked protected feeds, are left out.
    func visibleCustomFeeds(for flags: ContentFlags) -> [CustomFeed] {
        customFeeds.filter { $0.isVisible(with: flags) && isAccessible($0) }
    }

    /// The default feed, or its stream while the custom default is hidden by the content filter
    /// or locked.
    func defaultSource(for flags: ContentFlags) -> FeedSource {
        if case .custom(let id) = defaultSource, let feed = customFeed(id),
           !feed.isVisible(with: flags) || !isAccessible(feed) {
            return .stream(feed.stream)
        }
        return defaultSource
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

    /// Stream that tag feeds and searches start in: the default feed's.
    var defaultStream: FeedStream { defaultQuery.stream }

    /// "Abos" needs an account, so it's left out while logged out.
    func visibleTabs(isLoggedIn: Bool) -> [AppTab] {
        let tabs = tabOrder.filter { $0 != .subscribed || isLoggedIn }
        return tabs.isEmpty ? [.top] : tabs
    }

    func open(_ route: Route) {
        router.push(route)
    }
}
