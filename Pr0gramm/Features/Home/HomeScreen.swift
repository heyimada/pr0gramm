import SwiftUI

/// Start tab: today's top post as a hero, a "Top 10 heute" rail, then everything else from the
/// default feed (beliebt unless changed in the settings).
struct HomeScreen: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    @State private var cache = FeedCache()

    /// Posts from the last 24 hours with visible scores, best first. Falls back to all loaded posts.
    private func ranked(_ feed: FeedModel) -> [FeedItem] {
        let cutoff = Date(timeIntervalSinceNow: -86_400)
        let visible = feed.items.filter { !$0.createdAt.isScoreHidden }
        let today = visible.filter { $0.createdAt > cutoff }
        return (today.count >= 5 ? today : visible).sorted { $0.score > $1.score }
    }

    private var sectionTitle: String {
        switch (app.query(for: source) ?? .top).stream {
        case .top: "Frisch promoted"
        case .new: "Frisch hochgeladen"
        case .junk: "Frisch im Müll"
        case .subscribed: "Von deinen Abos"
        }
    }

    private var source: FeedSource { app.defaultSource(for: session.flags) }

    var body: some View {
        let query = app.query(for: source) ?? .top
        let feed = cache.model(for: query)
        let top = Array(ranked(feed).prefix(11))
        let topModel = FeedModel(items: top, query: query)
        FeedGrid(model: feed, showsBackground: false) {
            if let hero = top.first {
                VStack(alignment: .leading, spacing: 28) {
                    HeroCard(item: hero, route: .pager(PagerRoute(model: topModel, itemID: hero.id, transitionNamespace: nil)))
                    if top.count > 1 {
                        TopRail(items: Array(top.dropFirst()), model: topModel)
                    }
                    SectionTitle(kicker: app.title(for: source), title: sectionTitle)
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
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

/// The hero post, blurred and huge, behind the whole screen.
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
    let item: FeedItem
    let route: Route
    @State private var info: ItemInfo?
    @State private var looping: LoopingPlayer?

    private var tags: [Tag] {
        (info?.tags ?? []).sorted { $0.confidence > $1.confidence }
    }

    var body: some View {
        NavigationLink(value: route) {
            ZStack(alignment: .bottomLeading) {
                Color.pr0Pill
                media
                LinearGradient(stops: [.init(color: .clear, location: 0.35),
                                       .init(color: .black.opacity(0.6), location: 0.65),
                                       .init(color: .black.opacity(0.92), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                details.padding(20)
            }
            .aspectRatio(4 / 5, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.08)))
            .contentShape(.rect(cornerRadius: 28))
        }
        .buttonStyle(CardPressStyle())
        .padding(.horizontal, 16)
        .task(id: item.id) { info = try? await APIClient.shared.itemInfo(item.id) }
        .onAppear {
            guard item.isVideo, looping == nil else { return }
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
                        PlayerLayerView(player: looping?.player, gravity: .resizeAspectFill)
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

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nr. 1 heute".uppercased())
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
                Text("\(item.score.formatted()) Benis")
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

/// Horizontal rail of the next best posts with big rank numerals.
private struct TopRail: View {
    let items: [FeedItem]
    let model: FeedModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(kicker: "Trending", title: "Top 10 heute")
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

private struct RailCard: View {
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
                    Text("\(item.score.formatted()) Benis").font(.caption).foregroundStyle(Color.pr0Secondary)
                }
            }
            .frame(width: 170, alignment: .leading)
        }
        .foregroundStyle(Color.pr0Text)
    }
}

/// Slight shrink and fade while a card is pressed.
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
