import SwiftUI

/// Full-screen vertical feed, one post per page, TikTok-style. Swiping sideways switches between
/// beliebt, neu, müll and the user's own feeds, like Instagram's "Für dich" and "Freunde".
struct ReelsScreen: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    @State private var filter = ReelsFilter.load()
    /// `nil` until the user picks a feed, so Reels follows changes to the default feed.
    @State private var selection: FeedSource?
    @State private var pool = ReelPlayerPool()
    @State private var insets = EdgeInsets()
    @State private var showsFilter = false

    private var sources: [FeedSource] {
        app.feedSources(for: session.flags, includesSubscriptions: false)
    }

    private var current: FeedSource {
        let source = selection ?? app.defaultSource(for: session.flags)
        return sources.contains(source) ? source : .stream(.top)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // A paging scroll view rather than a page-style TabView, whose pan gesture leaves the
            // vertical reels stuck between pages. Not lazy, so every feed keeps its place.
            GeometryReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(sources, id: \.self) { source in
                            ReelsFeed(query: filter.query(for: app.query(for: source) ?? .top),
                                      isSelected: source == current, pool: pool, insets: insets,
                                      onFilter: { tag, include in
                                          if include { filter.include(tag) } else { filter.exclude(tag) }
                                      })
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .id(source)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .modifier(FeedPaging(current: current) { selection = $0 })
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .ignoresSafeArea()

            // Keeps the header readable over bright posts, like Instagram's.
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
        .onChange(of: filter) { filter.save() }
        .sheet(isPresented: $showsFilter) { ReelsFilterSheet(filter: $filter) }
        .onAppear { pool.resume() }
        .onDisappear { pool.pauseAll() }
    }

    /// Instagram-style header: Reels filter on the left, the feeds as plain text tabs, content filter on the right.
    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button { showsFilter = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(filter.hasTagFilter ? Color.pr0Orange : .white)
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
                                    Text(app.title(for: source))
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
                FilterMenu(plain: true)
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .shadow(color: .black.opacity(0.4), radius: 6)

            if filter.hasTagFilter {
                Button { showsFilter = true } label: {
                    HStack(spacing: 8) {
                        Text(filterSummary).lineLimit(1)
                        Button {
                            withAnimation {
                                filter.includedTags = []
                                filter.excludedTags = []
                            }
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
        .animation(.snappy, value: filter.hasTagFilter)
    }

    /// "#kadse +2" or "ohne #süßvieh".
    private var filterSummary: String {
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
    let onFilter: (String, Bool) -> Void
    @State private var model: FeedModel
    @State private var currentID: Int?

    init(query: FeedQuery, isSelected: Bool, pool: ReelPlayerPool, insets: EdgeInsets,
         onFilter: @escaping (String, Bool) -> Void) {
        self.query = query
        self.isSelected = isSelected
        self.pool = pool
        self.insets = insets
        self.onFilter = onFilter
        _model = State(initialValue: FeedModel(query: query))
    }

    var body: some View {
        // Pages span the whole screen, under the status and tab bars; `containerRelativeFrame`
        // would stop at the safe area.
        GeometryReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(model.items) { item in
                        ReelPage(item: item, isActive: isSelected && item.id == currentID, pool: pool,
                                 insets: insets, onFilter: onFilter)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .task { await model.loadMoreIfNeeded(after: item, flags: session.flags) }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .scrollIndicators(.hidden)
        }
        .ignoresSafeArea()
        .overlay {
            if model.items.isEmpty {
                Group {
                    if let error = model.error {
                        ErrorView(error: error) { await model.reload(flags: session.flags) }
                    } else if model.atEnd {
                        ContentUnavailableView("Nichts gefunden", systemImage: "play.slash")
                    } else {
                        ProgressView()
                    }
                }
            }
        }
        .task(id: "\(query.tags ?? "")-\(query.stream.rawValue)-\(session.flags.rawValue)") {
            if model.query != query {
                model = FeedModel(query: query)
                currentID = nil
            }
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

extension View {
    func glassCircle() -> some View {
        #if os(visionOS)
        glassBackgroundEffect(in: .circle)
        #else
        glassEffect(.regular, in: .circle)
        #endif
    }

    func glassCapsule() -> some View {
        #if os(visionOS)
        glassBackgroundEffect(in: .capsule)
        #else
        glassEffect(.regular, in: .capsule)
        #endif
    }
}

/// One reel: media, caption bottom-left, action column bottom-right.
private struct ReelPage: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    let item: FeedItem
    let isActive: Bool
    let pool: ReelPlayerPool
    let insets: EdgeInsets
    /// Adds a tag to the Reels filter: `true` to require it, `false` to hide it.
    let onFilter: (String, Bool) -> Void

    @State private var info: ItemInfo?
    @State private var showsComments = false
    @AppStorage("reelsFitMedia") private var fitsMedia = false
    @GestureState private var pinch: CGFloat = 1

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
            .padding(.horizontal, 16)
            .padding(.bottom, insets.bottom + 12)
        }
        .clipped()
        .task(id: isActive) {
            guard isActive, info == nil else { return }
            info = try? await APIClient.shared.itemInfo(item.id)
        }
        .sheet(isPresented: $showsComments) {
            ReelCommentsSheet(item: item, info: $info)
        }
    }

    /// Media fills the screen by default; pinching in shows it whole at its own aspect ratio,
    /// pinching out fills again. Remembered across reels.
    private var media: some View {
        GeometryReader { proxy in
            let fill = max(proxy.size.width / CGFloat(max(item.width, 1)), proxy.size.height / CGFloat(max(item.height, 1)))
            let fit = min(proxy.size.width / CGFloat(max(item.width, 1)), proxy.size.height / CGFloat(max(item.height, 1)))
            // Laid out at fill size and scaled down, so the video layer animates as one transform.
            Group {
                if item.isVideo {
                    PlayerLayerView(player: pool.players[item.id]?.player, gravity: .resizeAspectFill)
                } else {
                    RemoteImage(url: item.mediaURL)
                }
            }
            .frame(width: CGFloat(item.width) * fill, height: CGFloat(item.height) * fill)
            .scaleEffect((fitsMedia ? fit / fill : 1) * pinch)
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
                    if value.magnification < 0.95 { fitsMedia = true }
                    if value.magnification > 1.05 { fitsMedia = false }
                }
        )
        .animation(.spring(duration: 0.35, bounce: 0.2), value: fitsMedia)
        .animation(.interactiveSpring, value: pinch)
        .accessibilityLabel(item.isVideo ? "Video von \(item.user)" : "Bild von \(item.user)")
        .accessibilityAction(named: fitsMedia ? "Bildschirm füllen" : "Ganz anzeigen") { fitsMedia.toggle() }
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

            if let tags = info?.tags.sorted(by: { $0.confidence > $1.confidence }).prefix(4), !tags.isEmpty {
                FlowLayout(spacing: 10) {
                    ForEach(Array(tags)) { tag in
                        NavigationLink(value: Route.feed(FeedQuery(stream: app.defaultStream, tags: tag.tag))) {
                            Text("#\(tag.tag)").font(.subheadline.weight(.semibold)).lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("In Reels filtern", systemImage: "line.3.horizontal.decrease") { onFilter(tag.tag, true) }
                            Button("In Reels ausblenden", systemImage: "eye.slash") { onFilter(tag.tag, false) }
                        }
                    }
                }
            }

            HStack(spacing: 4) {
                Text(item.createdAt.pr0Age)
                Text("·")
                ScoreView(score: item.score + session.vote(for: .item, id: item.id), created: item.createdAt)
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
                cast(vote == 1 ? 0 : 1)
            }
            action(vote == -1 ? "minus.circle.fill" : "minus.circle", "Minus", tint: vote == -1 ? .pr0Orange : .white) {
                cast(vote == -1 ? 0 : -1)
            }
            action("bubble.right.fill", info.map { "\($0.comments.count)" } ?? "Kommentare") {
                showsComments = true
            }
            if item.isVideo {
                action(pool.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", pool.isMuted ? "Stumm" : "Ton") {
                    pool.isMuted.toggle()
                }
            }
            ReelDownloadAction(item: item)
            ShareLink(item: URL(string: "https://pr0gramm.com/new/\(item.id)")!) {
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
        guard session.isLoggedIn else { return app.showsLogin = true }
        Task { try? await session.vote(.item, id: item.id, value: value) }
    }
}

/// Tags and comments of a reel in a sheet.
private struct ReelCommentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: FeedItem
    @Binding var info: ItemInfo?
    @State private var replyTarget: Comment?
    @State private var composes = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let info {
                        TagsSection(tags: info.tags)
                        CommentsSection(item: item, comments: info.comments,
                                        onComment: { replyTarget = nil; composes = true },
                                        onReply: { replyTarget = $0; composes = true })
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .background(Color.pr0Background)
            .navigationTitle("Kommentare")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig", role: .confirm) { dismiss() }
                }
            }
            .task {
                if info == nil { info = try? await APIClient.shared.itemInfo(item.id) }
            }
            .sheet(isPresented: $composes) {
                CommentComposer(itemId: item.id, parentId: replyTarget?.id ?? 0, replyingTo: replyTarget?.name) { comments in
                    if let comments, let tags = info?.tags { info = ItemInfo(tags: tags, comments: comments) }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.pr0Background)
    }
}

/// "Laden" in the reel action column, backed by the download store.
private struct ReelDownloadAction: View {
    @Environment(DownloadStore.self) private var store
    let item: FeedItem

    var body: some View {
        let isSaved = store.download(for: item.id) != nil
        let isLoading = store.inProgress.contains(item.id)
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
