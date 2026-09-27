import SwiftUI

/// Full-screen vertical feed, one post per page, TikTok-style.
struct ReelsScreen: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    @State private var filter: ReelsFilter
    @State private var model: FeedModel
    @State private var currentID: Int?
    @State private var pool = ReelPlayerPool()
    @State private var insets = EdgeInsets()
    @State private var showsFilter = false

    /// Tags come from the saved filter; the stream starts at the default feed's.
    init(stream: FeedStream) {
        var filter = ReelsFilter.load()
        filter.stream = stream
        _filter = State(initialValue: filter)
        _model = State(initialValue: FeedModel(query: filter.query))
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(model.items) { item in
                        ReelPage(item: item, isActive: item.id == currentID, pool: pool, insets: insets,
                                 onFilter: { tag, include in
                                     if include { filter.include(tag) } else { filter.exclude(tag) }
                                 })
                            .containerRelativeFrame([.horizontal, .vertical])
                            .task { await model.loadMoreIfNeeded(after: item, flags: session.flags) }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentID)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()

            controls

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
                .frame(maxHeight: .infinity)
            }
        }
        .background(Color.black)
        .onGeometryChange(for: EdgeInsets.self, of: \.safeAreaInsets) { insets = $0 }
        .task(id: "\(filter.query.tags ?? "")-\(filter.stream.rawValue)-\(session.flags.rawValue)") {
            let query = filter.query
            if model.query != query {
                model = FeedModel(query: query)
                currentID = nil
            }
            await model.loadIfNeeded(flags: session.flags)
            if currentID == nil || !model.items.contains(where: { $0.id == currentID }) {
                currentID = model.items.first?.id
            }
            pool.focus(on: currentID, in: model.items)
        }
        .onChange(of: currentID) { pool.focus(on: currentID, in: model.items) }
        .onChange(of: filter) { filter.save() }
        .onChange(of: app.defaultStream) { filter.stream = app.defaultStream }
        .sheet(isPresented: $showsFilter) { ReelsFilterSheet(filter: $filter) }
        .onAppear { pool.resume() }
        .onDisappear { pool.pauseAll() }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                SegmentCapsule(options: FeedStream.searchable, selection: $filter.stream, title: \.title)
                Button { showsFilter = true } label: {
                    Image(systemName: filter.hasTagFilter
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(filter.hasTagFilter ? Color.pr0Orange : Color.pr0Text)
                        .frame(width: 40, height: 40)
                        .contentShape(.circle)
                        .glassCircle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reels-Filter")
            }

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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 6)
        .animation(.snappy, value: filter.hasTagFilter)
    }

    /// "#kadse +2" or "ohne #süßvieh".
    private var filterSummary: String {
        let count = filter.includedTags.count + filter.excludedTags.count
        let first = filter.includedTags.first.map { "#\($0)" } ?? filter.excludedTags.first.map { "ohne #\($0)" } ?? ""
        return count > 1 ? "\(first) +\(count - 1)" : first
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

    @ViewBuilder
    private var media: some View {
        ZStack {
            AsyncImage(url: item.thumbnailURL) { $0.resizable().scaledToFill() } placeholder: { Color.black }
                .blur(radius: 40)
                .opacity(0.5)
            if item.isVideo {
                PlayerLayerView(player: pool.players[item.id]?.player)
                    .contentShape(.rect)
                    .onTapGesture { pool.isMuted.toggle() }
            } else {
                RemoteImage(url: item.mediaURL)
            }
        }
        .containerRelativeFrame([.horizontal, .vertical])
        .accessibilityLabel(item.isVideo ? "Video von \(item.user)" : "Bild von \(item.user)")
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
