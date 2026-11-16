import AVFoundation
import SwiftUI

@main
struct Pr0grammApp: App {
    @State private var session: Session
    @State private var library: FeedLibrary
    @State private var playback: PlaybackSettings
    @State private var app: AppState
    @State private var downloads = DownloadStore()

    init() {
        let session = Session()
        _session = State(initialValue: session)
        _playback = State(initialValue: PlaybackSettings())
        _app = State(initialValue: AppState(session: session))
        _library = State(initialValue: FeedLibrary(session: session))
        // Thumbnails and images are loaded through URLSession.shared (AsyncImage); give it room to cache.
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .pr0Environment(session: session, app: app, library: library, downloads: downloads, playback: playback)
        }
        #if os(visionOS)
        .defaultSize(width: 1100, height: 800)
        #endif

        #if os(visionOS)
        WindowGroup(id: MediaWindow.id, for: FeedItem.self) { $item in
            if let item {
                MediaWindow(item: item)
                    .pr0Environment(session: session, app: app, library: library, downloads: downloads, playback: playback)
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 700)
        #endif
    }
}

private extension View {
    func pr0Environment(
        session: Session, app: AppState, library: FeedLibrary, downloads: DownloadStore, playback: PlaybackSettings
    ) -> some View {
        environment(session)
            .environment(app)
            .environment(library)
            .environment(downloads)
            .environment(playback)
            .tint(.pr0Orange)
            .preferredColorScheme(.dark)
    }
}

struct RootView: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    @Environment(FeedLibrary.self) private var library
    @Environment(DownloadStore.self) private var downloads
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
        .tabBarMinimizeBehavior(.onScrollDown)
        #else
        .tabViewStyle(.sidebarAdaptable)
        #endif
        .onChange(of: tabs, initial: true) {
            if !tabs.contains(app.tab), let first = tabs.first { app.tab = first }
        }
        .sheet(isPresented: $app.showsSettings) { SettingsView() }
        .appPresentations()
        .task { await session.sync() }
        .onChange(of: scenePhase) {
            // Protected feeds need Face ID again after leaving the app.
            if scenePhase == .background { library.lockProtectedFeeds() }
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
                case .top: StreamFeed(stream: .top)
                case .new: StreamFeed(stream: .new)
                case .junk: StreamFeed(stream: .junk)
                case .subscribed: StreamFeed(stream: .subscribed)
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
