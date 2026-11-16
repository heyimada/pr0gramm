import SwiftUI

enum Route: Hashable {
    case feed(FeedQuery)
    case tag(String)
    case user(String)
    case item(Int)
    case pager(PagerRoute)
    case download(Int)
}

struct PagerRoute: Hashable {
    let model: FeedModel
    let itemID: Int
    let transitionNamespace: Namespace.ID?

    static func == (lhs: PagerRoute, rhs: PagerRoute) -> Bool {
        lhs.model === rhs.model && lhs.itemID == rhs.itemID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(model))
        hasher.combine(itemID)
    }
}

@Observable
final class Router {
    var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    /// Maps links like `pr0gramm.com/top/123`, `/new/katze/123`, `/user/name` or `pr0.app/...` to routes.
    static func route(for url: URL) -> Route? {
        guard Site.isOwn(url) else { return nil }
        // Old-style links keep the path in the fragment: `pr0gramm.com/#top/123`.
        let path = url.fragment.map { "/" + $0 } ?? url.path()
        let parts = path.split(separator: "/").map { String($0).removingPercentEncoding ?? String($0) }
        if let first = parts.first, first == "user", parts.count >= 2 {
            if parts.count > 2, let id = parts.last.flatMap({ Int($0) }) { return .item(id) }
            return .user(parts[1])
        }
        if let last = parts.last, let id = Int(last.split(separator: ":").first ?? "") { return .item(id) }
        if parts.count == 2, let stream = FeedStream(rawValue: parts[0]) {
            return .feed(FeedQuery(stream: stream, tags: parts[1]))
        }
        return nil
    }
}

struct RoutedStack<Root: View>: View {
    @Bindable var router: Router
    @ViewBuilder var root: Root

    var body: some View {
        NavigationStack(path: $router.path) {
            root
                .navigationDestination(for: Route.self) { route in
                    RouteDestination(route: route)
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                }
        }
        .environment(\.openURL, OpenURLAction { url in
            guard let route = Router.route(for: url) else { return .systemAction }
            router.push(route)
            return .handled
        })
    }
}

struct RouteDestination: View {
    @Environment(FeedLibrary.self) private var library
    let route: Route

    var body: some View {
        switch route {
        case .feed(let query):
            FeedScreen(query: query)
        case .tag(let tag):
            FeedScreen(query: FeedQuery(stream: library.defaultStream, tags: tag))
        case .user(let name):
            ProfileScreen(name: name)
        case .item(let id):
            SingleItemScreen(id: id)
        case .download(let id):
            DownloadViewer(id: id)
        case .pager(let pager):
            ItemPagerView(model: pager.model, initialID: pager.itemID)
                #if os(iOS)
                .modifier(ZoomTransition(sourceID: pager.itemID, namespace: pager.transitionNamespace))
                #endif
        }
    }
}

#if os(iOS)
private struct ZoomTransition: ViewModifier {
    let sourceID: Int
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            content
        }
    }
}
#endif
