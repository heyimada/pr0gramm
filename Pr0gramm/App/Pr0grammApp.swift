import AVFoundation
import SwiftUI

@main
struct Pr0grammApp: App {
    @State private var session = Session()
    @State private var app = AppState()
    @State private var downloads = DownloadStore()

    init() {
        // Thumbnails and images are loaded through URLSession.shared (AsyncImage); give it room to cache.
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(app)
                .environment(downloads)
                .tint(.pr0Orange)
                .preferredColorScheme(.dark)
        }
        #if os(visionOS)
        .defaultSize(width: 1100, height: 800)
        #endif

        #if os(visionOS)
        // Detached media viewer, so a picture or video can be placed and scaled on its own in the room.
        WindowGroup(id: MediaWindow.id, for: FeedItem.self) { $item in
            if let item {
                MediaWindow(item: item)
                    .environment(session)
                    .environment(app)
                    .environment(downloads)
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 700)
        #endif
    }
}

/// System tab bar with one navigation stack per stream, plus a search tab.
struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app
        let tabs = app.visibleTabs(isLoggedIn: session.isLoggedIn)
        TabView(selection: $app.tab) {
            ForEach(tabs) { tab in
                if tab == .search {
                    Tab(value: tab, role: .search) {
                        TabStack(tab: tab)
                    }
                } else {
                    Tab(tab.title, systemImage: tab.symbol, value: tab) {
                        TabStack(tab: tab)
                    }
                }
            }
        }
        #if os(iOS)
        .tabViewSearchActivation(.searchTabSelection)
        .tabBarMinimizeBehavior(.onScrollDown)
        #else
        .tabViewStyle(.sidebarAdaptable)
        #endif
        .onChange(of: tabs, initial: true) {
            if !tabs.contains(app.tab), let first = tabs.first { app.tab = first }
        }
        .sheet(isPresented: $app.showsLogin) { LoginView() }
        .sheet(isPresented: $app.showsSettings) { SettingsView() }
        .task { await session.sync() }
        .onChange(of: scenePhase) {
            // Protected feeds need Face ID again after leaving the app.
            if scenePhase == .background { app.lockProtectedFeeds() }
        }
    }
}

private struct TabStack: View {
    @Environment(AppState.self) private var app
    let tab: AppTab

    var body: some View {
        RoutedStack(router: app.routers[tab]!) {
            Group {
                switch tab {
                case .top, .new, .junk, .subscribed: StreamFeed(stream: tab.stream!)
                case .profile: AccountScreen()
                case .downloads: DownloadsScreen()
                case .home: HomeScreen()
                case .feed: StreamsScreen()
                case .reels: ReelsScreen()
                case .search: SearchScreen()
                }
            }
            #if os(iOS)
            .navigationTitle(tab == .search ? tab.title : "")
            .navigationBarTitleDisplayMode(.inline)
            #else
            .navigationTitle(tab.title)
            #endif
            .toolbar { MainToolbar() }
        }
    }
}

/// Root feed of a single-stream tab; keeps its model (and scroll position) for the tab's lifetime.
private struct StreamFeed: View {
    @State private var model: FeedModel

    init(stream: FeedStream) {
        _model = State(initialValue: FeedModel(query: FeedQuery(stream: stream)))
    }

    var body: some View {
        FeedGrid(model: model)
    }
}
