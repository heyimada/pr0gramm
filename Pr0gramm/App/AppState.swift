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

    /// Versioned so a changed default reaches everyone once; older configurations are ignored.
    private static let tabOrderKey = "tabOrder.v2"

    let routers: [AppTab: Router] = Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, Router()) })

    var router: Router { routers[tab]! }

    init() {
        let stored = (UserDefaults.standard.stringArray(forKey: Self.tabOrderKey) ?? []).compactMap(AppTab.init(rawValue:))
        let order = stored.isEmpty ? AppTab.defaultOrder : stored
        tab = order.first ?? .top
        tabOrder = order
    }

    /// "Abos" needs an account, so it's left out while logged out.
    func visibleTabs(isLoggedIn: Bool) -> [AppTab] {
        let tabs = tabOrder.filter { $0 != .subscribed || isLoggedIn }
        return tabs.isEmpty ? [.top] : tabs
    }

    func open(_ route: Route) {
        router.push(route)
    }
}
