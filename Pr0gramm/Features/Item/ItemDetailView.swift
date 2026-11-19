import SwiftUI

struct ItemDetailView: View {
    @Environment(\.bookPages) private var bookPages
    @Environment(\.horizontalSizeClass) private var sizeClass
    let item: FeedItem
    let isActive: Bool
    let pageSize: CGSize
    /// Leading and trailing safe-area insets the page spans but must keep its content out of, e.g.
    /// the vertical bar of an iPhone Duo. Backgrounds still run underneath.
    let sideInsets: EdgeInsets
    let previous: (() -> Void)?
    let next: (() -> Void)?

    @State private var details: ItemDetails
    @State private var playback = VideoPlayback()

    init(item: FeedItem, isActive: Bool, pageSize: CGSize, sideInsets: EdgeInsets = EdgeInsets(),
         previous: (() -> Void)? = nil, next: (() -> Void)? = nil) {
        self.item = item
        self.isActive = isActive
        self.pageSize = pageSize
        self.sideInsets = sideInsets
        self.previous = previous
        self.next = next
        _details = State(initialValue: ItemDetails(itemID: item.id))
    }

    private var isSideBySide: Bool {
        sizeClass == .regular && pageSize.width > pageSize.height
    }

    var body: some View {
        // One container rather than a Group, so the modifiers below, the comment composer
        // among them, belong to the page and survive switching between the two layouts.
        ZStack {
            if bookPages != nil, #available(iOS 27.1, visionOS 27.1, *) {
                // Book Mode: the media on one page, the post's details on the other.
                ArrangementView { mediaColumn } secondary: { detailsColumn }
                    .arrangementViewStyle(.split)
            } else if isSideBySide {
                HStack(spacing: 0) {
                    mediaColumn
                    detailsColumn
                        .frame(width: min(max(pageSize.width * 0.38, 340), 440) + sideInsets.trailing)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        media(maxHeight: max(pageSize.height * 0.75, 200), insets: sideInsets)
                        PostDetails(item: item, details: details).padding(.leading, sideInsets.leading).padding(.trailing, sideInsets.trailing)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .onDisappear { playback.stop() }
        .task { await details.load() }
        .commentComposer(item: item, details: details)
    }

    /// Sized by the space left rather than by the media, so the page can't outgrow the screen.
    private var mediaColumn: some View {
        GeometryReader { proxy in
            ScrollView {
                media(maxHeight: max(proxy.size.height - (item.sourceURL == nil ? 0 : SourceBar.height), 0))
                    .frame(width: proxy.size.width)
            }
            .defaultScrollAnchor(.center, for: .alignment)
        }
        .padding(.leading, sideInsets.leading)
        .background(Color.black)
    }

    private var detailsColumn: some View {
        ScrollView {
            PostDetails(item: item, details: details)
                .padding(.top, 8)
                .padding(.trailing, sideInsets.trailing)
        }
    }

    private func media(maxHeight: CGFloat, insets: EdgeInsets = EdgeInsets()) -> some View {
        VStack(spacing: 0) {
            MediaView(item: item, isActive: isActive, playback: playback, maxHeight: maxHeight)
                .overlay { StepArrows(previous: previous, next: next) }
                .padding(.leading, insets.leading)
                .padding(.trailing, insets.trailing)
                .background(Color.black)

            if let sourceURL = item.sourceURL {
                SourceBar(url: sourceURL)
                    .padding(.leading, insets.leading)
                    .padding(.trailing, insets.trailing)
                    .background(Color.pr0Pill)
            }
        }
    }
}

private struct SourceBar: View {
    static let height: CGFloat = 44
    let url: URL

    private var domain: String {
        let host = url.host ?? ""
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                Text("Soße")
                    .fontWeight(.medium)
                Text(domain)
                    .foregroundStyle(Color.pr0Mention)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.semibold))
            }
            .font(.footnote)
            .foregroundStyle(Color.pr0Secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: Self.height)
            .background(Color.pr0Pill)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Soße: \(domain)")
        .accessibilityHint("Öffnet die Quelle im Browser")
    }
}

private struct StepArrows: View {
    let previous: (() -> Void)?
    let next: (() -> Void)?

    var body: some View {
        HStack {
            arrow("chevron.left", label: "Vorheriger Hochlad", action: previous)
            Spacer()
            arrow("chevron.right", label: "Nächster Hochlad", action: next)
        }
    }

    @ViewBuilder
    private func arrow(_ symbol: String, label: String, action: (() -> Void)?) -> some View {
        if let action {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.6), radius: 4)
                    .frame(width: 44, height: 88)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        }
    }
}

struct ItemInfoBar: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL
    let item: FeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                NavigationLink(value: Route.user(item.user)) {
                    HStack(spacing: 12) {
                        Avatar(name: item.user, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.user).font(.headline).lineLimit(1)
                                MarkDot(mark: item.mark)
                            }
                            Text("\(Text(UserMark.name(item.mark)).foregroundStyle(Color.mark(item.mark))), vor \(item.createdAt.pr0Age)")
                                .font(.footnote)
                                .foregroundStyle(Color.pr0Secondary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hochgeladen von \(item.user)")

                Spacer(minLength: 8)

                Menu {
                    Button("Link kopieren", systemImage: "link") {
                        UIPasteboard.general.url = item.webURL
                    }
                    Button("Im Browser öffnen", systemImage: "safari") { openURL(item.webURL) }
                    #if os(visionOS)
                    Button("In eigenem Fenster öffnen", systemImage: "macwindow.badge.plus") {
                        openWindow(id: MediaWindow.id, value: item)
                    }
                    #endif
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.pr0Text)
                        .frame(width: 36, height: 36)
                        .background(Color.pr0Pill, in: .circle)
                        .contentShape(.circle)
                }
                .accessibilityLabel("Weitere Aktionen")
            }

            BenisBar(item: item)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ShareLink(item: item.webURL) {
                        ActionPillLabel(title: "Teilen", symbol: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    DownloadButton(item: item)
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }
}

struct ItemScore: View {
    @Environment(Session.self) private var session
    let item: FeedItem

    var body: some View {
        ScoreView(score: session.score(of: item), created: item.createdAt)
    }
}

/// The post's Benis as a large number, with plus and minus as full-size round buttons.
struct BenisBar: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    let item: FeedItem

    var body: some View {
        let vote = session.vote(for: .item, id: item.id)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                ItemScore(item: item)
                    // The hidden-score eye stays icon-sized; only the number is set large.
                    .font(item.createdAt.isScoreHidden ? .title2 : .system(size: 44, weight: .bold))
                    .foregroundStyle(Color.pr0Text)
                Text("Benis").font(.caption).foregroundStyle(Color.pr0Secondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            button(value: 1, current: vote, symbol: "plus", label: "Plus", color: .pr0Orange)
            button(value: -1, current: vote, symbol: "minus", label: "Minus", color: .voteDown)
        }
        .animation(.snappy, value: vote)
    }

    private func button(value: Int, current: Int, symbol: String, label: String, color: Color) -> some View {
        let active = current == value
        return Button {
            Task { await app.toggleVote(.item, id: item.id, value) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.pr0Text)
                .frame(width: 44, height: 44)
                .background(active ? color : Color.pr0Pill, in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: active)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
