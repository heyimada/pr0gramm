import SwiftUI

struct HomeScreen: View {
    @Environment(\.bookPages) private var bookPages
    @Environment(FeedLibrary.self) private var library
    @State private var cache = FeedCache()
    @State private var selection: FeedSource?

    private func ranked(_ feed: FeedModel) -> (items: [FeedItem], isToday: Bool) {
        let cutoff = Date(timeIntervalSinceNow: -86_400)
        let visible = feed.items.filter { !$0.createdAt.isScoreHidden }
        let today = visible.filter { $0.createdAt > cutoff }
        let isToday = today.count >= 5
        return ((isToday ? today : visible).sorted { $0.score > $1.score }, isToday)
    }

    private var sources: [FeedSource] {
        library.sources(withSubscriptions: true)
    }

    private var source: FeedSource {
        library.currentSource(picked: selection, in: sources)
    }

    private var sectionTitle: String {
        switch library.query(for: source).stream {
        case .top: "Frisch beliebt"
        case .new: "Frisch hochgeladen"
        case .junk: "Frischer Müll"
        case .subscribed: "Von deinen Abos"
        }
    }

    private var sectionKicker: String {
        if case .custom = source { return library.title(for: source) }
        return "Alle Posts"
    }

    var body: some View {
        let query = library.query(for: source)
        let feed = cache.model(for: query)
        let (rankedItems, isToday) = ranked(feed)
        let top = Array(rankedItems.prefix(11))
        let topModel = FeedModel(items: top, query: query)
        FeedGrid(model: feed, showsBackground: false) {
            VStack(alignment: .leading, spacing: 28) {
                SegmentCapsule(options: sources, selection: Binding(get: { source }, set: { selection = $0 }),
                               title: library.title(for:))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .centeredOnLeadingPage()
                if let hero = top.first {
                    let heroCard = HeroCard(item: hero, isToday: isToday, route: .pager(PagerRoute(model: topModel, itemID: hero.id, transitionNamespace: nil)))
                    if let pages = bookPages {
                        // The hero fills the leading page, the ranking runs down the trailing one.
                        HStack(alignment: .top, spacing: pages.gap) {
                            heroCard.id(hero.id).frame(width: pages.leading.width)
                            if top.count > 1 {
                                TopList(items: Array(top.dropFirst()), isToday: isToday, model: topModel)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    } else {
                        heroCard.id(hero.id)
                        if top.count > 1 {
                            TopRail(items: Array(top.dropFirst()), isToday: isToday, model: topModel)
                        }
                    }
                    SectionTitle(kicker: sectionKicker, title: sectionTitle)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .id(query)
        .background { AmbientBackdrop(url: top.first?.thumbnailURL) }
    }
}

struct SectionTitle: View {
    let kicker: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kicker.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Color.pr0Orange)
            Text(title).font(.title2.bold())
        }
        .padding(.horizontal, 16)
    }
}

private struct AmbientBackdrop: View {
    let url: URL?

    var body: some View {
        ZStack {
            Color.pr0Background
            #if !os(visionOS)
            if let url {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
                    .blur(radius: 70)
                    .opacity(0.55)
                    .transition(.opacity)
            }
            LinearGradient(colors: [.clear, Color.pr0Background], startPoint: .top, endPoint: .init(x: 0.5, y: 0.8))
            #endif
        }
        .ignoresSafeArea()
    }
}

private struct HeroCard: View {
    @Environment(\.bookPages) private var bookPages
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(PlaybackSettings.self) private var playback
    @Environment(Session.self) private var session
    let item: FeedItem
    let isToday: Bool
    let route: Route
    @State private var details: ItemDetails
    @State private var looping: LoopingPlayer?

    init(item: FeedItem, isToday: Bool, route: Route) {
        self.item = item
        self.isToday = isToday
        self.route = route
        _details = State(initialValue: ItemDetails(itemID: item.id))
    }

    private var tags: [Tag] { details.info?.tags ?? [] }

    var body: some View {
        NavigationLink(value: route) {
            ZStack(alignment: .bottomLeading) {
                Color.pr0Pill
                media
                LinearGradient(stops: [.init(color: .clear, location: 0.35),
                                       .init(color: .black.opacity(0.6), location: 0.65),
                                       .init(color: .black.opacity(0.92), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                caption.padding(20)
            }
            // Portrait on phones; wide on regular-width screens like the opened iPhone Duo, so the
            // rail below still shows. Portrait again on a single page of Book Mode.
            .aspectRatio(sizeClass == .regular && bookPages == nil ? 2 : 4 / 5, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.08)))
            .contentShape(.rect(cornerRadius: 28))
        }
        .buttonStyle(CardPressStyle())
        .padding(.horizontal, 16)
        .task { await details.loadIfNeeded() }
        .onAppear {
            guard item.isVideo, playback.autoplayVideos, looping == nil else { return }
            looping = LoopingPlayer(url: item.mediaURL, muted: true)
            looping?.player.play()
        }
        .onDisappear {
            looping?.player.pause()
            looping = nil
        }
    }

    @ViewBuilder
    private var media: some View {
        GeometryReader { proxy in
            Group {
                if item.isVideo {
                    ZStack {
                        AsyncImage(url: item.thumbnailURL) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
                        PlayerLayerView(player: looping?.player)
                    }
                } else {
                    AsyncImage(url: item.mediaURL) { $0.resizable().scaledToFill() } placeholder: {
                        AsyncImage(url: item.thumbnailURL) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text((isToday ? "Nr. 1 heute" : "Nr. 1").uppercased())
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(Color.pr0Orange)
            Text(tags.first?.tag ?? item.user)
                .font(.system(.largeTitle, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            HStack(spacing: 6) {
                Text(item.user)
                Text("·")
                Text("\(session.score(of: item).formatted()) Benis")
                Text("·")
                Text(item.createdAt.pr0Age)
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.75))
            .lineLimit(1)

            if tags.count > 1 {
                HStack(spacing: 8) {
                    ForEach(tags.dropFirst().prefix(3)) { tag in
                        Text(tag.tag)
                            .font(.subheadline)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .overlay(Capsule().strokeBorder(.white.opacity(0.3)))
                    }
                }
            }

            Label("Ansehen", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.white, in: .capsule)
                .padding(.top, 6)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.leading)
    }
}

private struct TopRail: View {
    let items: [FeedItem]
    let isToday: Bool
    let model: FeedModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(kicker: "Trending", title: isToday ? "Top 10 heute" : "Top 10")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(value: Route.pager(PagerRoute(model: model, itemID: item.id, transitionNamespace: nil))) {
                            RailCard(item: item, rank: index + 2)
                        }
                        .buttonStyle(CardPressStyle())
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}

private struct TopList: View {
    @Environment(Session.self) private var session
    let items: [FeedItem]
    let isToday: Bool
    let model: FeedModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(kicker: "Trending", title: isToday ? "Top 10 heute" : "Top 10")
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: Route.pager(PagerRoute(model: model, itemID: item.id, transitionNamespace: nil))) {
                        HStack(spacing: 12) {
                            Text("\(index + 2)")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.pr0Orange)
                                .frame(width: 40, alignment: .trailing)
                            ThumbnailView(item: item)
                                .frame(width: 64, height: 64)
                                .clipShape(.rect(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.user).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text("\(session.score(of: item).formatted()) Benis").font(.caption).foregroundStyle(Color.pr0Secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                        .foregroundStyle(Color.pr0Text)
                        .contentShape(.rect)
                    }
                    .buttonStyle(CardPressStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct RailCard: View {
    @Environment(Session.self) private var session
    let item: FeedItem
    let rank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThumbnailView(item: item)
                .frame(width: 170, height: 170)
                .clipShape(.rect(cornerRadius: 18))
                .overlay(alignment: .topLeading) {
                    if item.isVideo {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                            .padding(6)
                            .background(.ultraThinMaterial, in: .circle)
                            .padding(8)
                    }
                }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(rank)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.pr0Orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.user).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text("\(session.score(of: item).formatted()) Benis").font(.caption).foregroundStyle(Color.pr0Secondary)
                }
            }
            .frame(width: 170, alignment: .leading)
        }
        .foregroundStyle(Color.pr0Text)
    }
}

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
            #if os(visionOS)
            .hoverEffect()
            #endif
    }
}
