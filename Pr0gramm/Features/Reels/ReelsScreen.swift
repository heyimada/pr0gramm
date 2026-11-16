import SwiftUI

struct ReelsScreen: View {
    @Environment(FeedLibrary.self) private var library
    @State private var store = ReelsFilterStore()
    @State private var selection: FeedSource?
    @State private var pool = ReelPlayerPool()
    @State private var insets = EdgeInsets()
    @State private var showsFilter = false

    private var sources: [FeedSource] {
        library.sources(withSubscriptions: false)
    }

    private var current: FeedSource {
        library.currentSource(picked: selection, in: sources)
    }

    var body: some View {
        ZStack(alignment: .top) {
            FeedPager(sources: sources, current: current, onSwipe: { selection = $0 }) { source in
                let query = store.filter.query(for: library.query(for: source))
                ReelsFeed(query: query, isSelected: source == current, pool: pool, insets: insets)
                    .id(query)
            }

            LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 140)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)

            controls
        }
        .background(Color.black)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onGeometryChange(for: EdgeInsets.self, of: \.safeAreaInsets) { insets = $0 }
        .environment(store)
        .sheet(isPresented: $showsFilter) { ReelsFilterSheet() }
        .onAppear { pool.resume() }
        .onDisappear { pool.pauseAll() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button { showsFilter = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(store.filter.hasTagFilter ? Color.pr0Orange : .white)
                        .frame(width: 36, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reels-Filter")

                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 14) {
                            ForEach(sources, id: \.self) { source in
                                let isOn = source == current
                                Button {
                                    withAnimation(.snappy(duration: 0.25)) { selection = source }
                                } label: {
                                    Text(library.title(for: source))
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.white.opacity(isOn ? 1 : 0.5))
                                        .lineLimit(1)
                                        .padding(.vertical, 6)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(isOn ? .isSelected : [])
                                .id(source)
                            }
                        }
                        .padding(.trailing, 8)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear { proxy.scrollTo(current, anchor: .center) }
                    .onChange(of: current) { withAnimation { proxy.scrollTo(current, anchor: .center) } }
                }

                // SFW / NSFW / NSFL / POL, which the hidden toolbar would otherwise hold.
                FilterMenu {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .shadow(color: .black.opacity(0.4), radius: 6)

            if store.filter.hasTagFilter {
                Button { showsFilter = true } label: {
                    HStack(spacing: 8) {
                        Text(filterSummary).lineLimit(1)
                        Button {
                            withAnimation { store.filter.clearTags() }
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.pr0Secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Tag-Filter entfernen")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.pr0Text)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .frame(height: 30)
                    .glassCapsule()
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.snappy, value: store.filter.hasTagFilter)
    }

    /// "#kadse +2" or "ohne #süßvieh".
    private var filterSummary: String {
        let filter = store.filter
        let count = filter.includedTags.count + filter.excludedTags.count
        let first = filter.includedTags.first.map { "#\($0)" } ?? filter.excludedTags.first.map { "ohne #\($0)" } ?? ""
        return count > 1 ? "\(first) +\(count - 1)" : first
    }
}

/// One feed's vertical reels. Only the selected feed drives the shared player pool.
private struct ReelsFeed: View {
    @Environment(Session.self) private var session
    let query: FeedQuery
    let isSelected: Bool
    let pool: ReelPlayerPool
    let insets: EdgeInsets
    @State private var model: FeedModel
    @State private var currentID: Int?

    init(query: FeedQuery, isSelected: Bool, pool: ReelPlayerPool, insets: EdgeInsets) {
        self.query = query
        self.isSelected = isSelected
        self.pool = pool
        self.insets = insets
        _model = State(initialValue: FeedModel(query: query))
    }

    var body: some View {
        // Pages span the whole screen, under the status and tab bars; `containerRelativeFrame`
        // would stop at the safe area.
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(model.items) { item in
                        ReelPage(item: item, isActive: isSelected && item.id == currentID, pool: pool, insets: insets)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .task { await model.loadMoreIfNeeded(after: item, flags: session.flags) }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .pagePosition($currentID)
            .scrollIndicators(.hidden)
        }
        .ignoresSafeArea()
        .overlay { FeedStatus(model: model, emptySymbol: "play.slash") }
        .task(id: session.flags) {
            await model.loadIfNeeded(flags: session.flags)
            if currentID == nil || !model.items.contains(where: { $0.id == currentID }) {
                currentID = model.items.first?.id
            }
            focus()
        }
        .onChange(of: currentID) { focus() }
        .onChange(of: isSelected) { focus() }
    }

    private func focus() {
        guard isSelected else { return }
        pool.focus(on: currentID, in: model.items)
    }
}

private struct ReelPage: View {
    @Environment(Session.self) private var session
    @Environment(PlaybackSettings.self) private var playback
    @Environment(AppState.self) private var app
    @Environment(ReelsFilterStore.self) private var store
    let item: FeedItem
    let isActive: Bool
    let pool: ReelPlayerPool
    let insets: EdgeInsets

    @State private var details: ItemDetails
    @State private var showsComments = false
    @GestureState private var pinch: CGFloat = 1

    init(item: FeedItem, isActive: Bool, pool: ReelPlayerPool, insets: EdgeInsets) {
        self.item = item
        self.isActive = isActive
        self.pool = pool
        self.insets = insets
        _details = State(initialValue: ItemDetails(itemID: item.id))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            media
            LinearGradient(stops: [.init(color: .clear, location: 0.55), .init(color: .black.opacity(0.75), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            HStack(alignment: .bottom, spacing: 12) {
                caption
                Spacer(minLength: 0)
                actions
            }
            // Each side on its own: the closed iPhone Duo keeps its tab bar along the right edge.
            .padding(.leading, insets.leading + 16)
            .padding(.trailing, insets.trailing + 16)
            .padding(.bottom, insets.bottom + 12)
        }
        .clipped()
        .task(id: isActive) {
            guard isActive else { return }
            await details.loadIfNeeded()
        }
        .sheet(isPresented: $showsComments) {
            ReelCommentsSheet(item: item, details: details)
        }
    }

    private var media: some View {
        GeometryReader { proxy in
            let fill = max(proxy.size.width / CGFloat(max(item.width, 1)), proxy.size.height / CGFloat(max(item.height, 1)))
            let fit = min(proxy.size.width / CGFloat(max(item.width, 1)), proxy.size.height / CGFloat(max(item.height, 1)))
            let fillsScreen = !playback.reelsShowWhole || 1 - fit / fill <= playback.reelsFillTolerance
            // Laid out at fill size and scaled down, so the video layer animates as one transform.
            Group {
                if item.isVideo {
                    PlayerLayerView(player: pool.players[item.id]?.player)
                } else {
                    RemoteImage(url: item.mediaURL)
                }
            }
            .frame(width: CGFloat(item.width) * fill, height: CGFloat(item.height) * fill)
            .scaleEffect((fillsScreen ? 1 : fit / fill) * pinch)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background {
            AsyncImage(url: item.thumbnailURL) { $0.resizable().scaledToFill() } placeholder: { Color.black }
                .blur(radius: 40)
                .opacity(0.5)
        }
        .clipped()
        .contentShape(.rect)
        .onTapGesture { if item.isVideo { pool.isMuted.toggle() } }
        .simultaneousGesture(
            MagnifyGesture()
                .updating($pinch) { value, pinch, _ in
                    pinch = min(max(value.magnification, 0.6), 1.5)
                }
                .onEnded { value in
                    if value.magnification < 0.95 { playback.reelsShowWhole = true }
                    if value.magnification > 1.05 { playback.reelsShowWhole = false }
                }
        )
        .animation(.spring(duration: 0.35, bounce: 0.2), value: playback.reelsShowWhole)
        .animation(.interactiveSpring, value: pinch)
        .accessibilityLabel(item.isVideo ? "Video von \(item.user)" : "Bild von \(item.user)")
        .accessibilityAction(named: playback.reelsShowWhole ? "Bildschirm füllen" : "Ganz anzeigen") { playback.reelsShowWhole.toggle() }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: Route.user(item.user)) {
                HStack(spacing: 8) {
                    Text("@\(item.user)").font(.headline)
                    MarkDot(mark: item.mark)
                }
            }
            .buttonStyle(.plain)

            if let tags = details.info?.tags.prefix(4), !tags.isEmpty {
                FlowLayout(spacing: 10) {
                    ForEach(Array(tags)) { tag in
                        NavigationLink(value: Route.tag(tag.tag)) {
                            Text("#\(tag.tag)").font(.subheadline.weight(.semibold)).lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("In Reels filtern", systemImage: "line.3.horizontal.decrease") { store.filter.include(tag.tag) }
                            Button("In Reels ausblenden", systemImage: "eye.slash") { store.filter.exclude(tag.tag) }
                        }
                    }
                }
            }

            HStack(spacing: 4) {
                Text(item.createdAt.pr0Age)
                Text("·")
                ItemScore(item: item)
                if !item.createdAt.isScoreHidden { Text("Benis") }
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.5), radius: 4)
    }

    private var actions: some View {
        let vote = session.vote(for: .item, id: item.id)
        return VStack(spacing: 18) {
            NavigationLink(value: Route.user(item.user)) {
                Avatar(name: item.user, size: 46)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profil von \(item.user)")

            action(vote == 1 ? "plus.circle.fill" : "plus.circle", "Plus", tint: vote == 1 ? .pr0Orange : .white) {
                cast(1)
            }
            action(vote == -1 ? "minus.circle.fill" : "minus.circle", "Minus", tint: vote == -1 ? .pr0Orange : .white) {
                cast(-1)
            }
            action("bubble.right.fill", details.info.map { "\($0.comments.count)" } ?? "Kommentare") {
                showsComments = true
            }
            if item.isVideo {
                action(pool.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", pool.isMuted ? "Stumm" : "Ton") {
                    pool.isMuted.toggle()
                }
            }
            ReelDownloadAction(item: item)
            ShareLink(item: item.webURL) {
                actionLabel("arrowshape.turn.up.right.fill", "Teilen", tint: .white)
            }
            .buttonStyle(.plain)
        }
        .shadow(color: .black.opacity(0.5), radius: 4)
    }

    private func action(_ symbol: String, _ title: String, tint: Color = .white, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { actionLabel(symbol, title, tint: tint) }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: symbol)
    }

    private func actionLabel(_ symbol: String, _ title: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 30)).foregroundStyle(tint)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white)
        }
        .frame(minWidth: 56)
        .contentShape(.rect)
    }

    private func cast(_ value: Int) {
        Task { await app.toggleVote(.item, id: item.id, value, in: session) }
    }
}

private struct ReelCommentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: FeedItem
    let details: ItemDetails

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let info = details.info {
                        TagsSection(tags: info.tags)
                        CommentsSection(item: item, details: details)
                    } else if let error = details.error {
                        ErrorView(error: error, retry: details.load)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .background(Color.pr0Background)
            .inlineNavigationTitle("Kommentare")
            .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig", role: .confirm) { dismiss() }
                }
            }
            .task { await details.loadIfNeeded() }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.pr0Background)
    }
}

private struct ReelDownloadAction: View {
    @Environment(DownloadStore.self) private var store
    let item: FeedItem

    var body: some View {
        let state = store.state(for: item.id)
        let isSaved = state == .saved
        let isLoading = state == .loading
        Button {
            Task { try? await store.save(item) }
        } label: {
            VStack(spacing: 4) {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: isSaved ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .foregroundStyle(isSaved ? Color.upvoteGreen : .white)
                    }
                }
                .font(.system(size: 30))
                .frame(height: 34)
                Text(isSaved ? "Gespeichert" : "Laden").font(.caption.weight(.semibold)).foregroundStyle(.white)
            }
            .frame(minWidth: 56)
        }
        .buttonStyle(.plain)
        .disabled(isSaved || isLoading)
    }
}
