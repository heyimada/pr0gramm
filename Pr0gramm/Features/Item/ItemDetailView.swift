import SwiftUI

struct ItemDetailView: View {
    @Environment(Session.self) private var session
    @Environment(\.horizontalSizeClass) private var sizeClass
    let item: FeedItem
    let isActive: Bool
    let pageSize: CGSize
    /// Leading and trailing safe-area insets the page spans but must keep its content out of, e.g.
    /// the vertical bar of an iPhone Duo. Backgrounds still run underneath.
    var sideInsets = EdgeInsets()
    var step: (Int) -> (() -> Void)? = { _ in nil }

    @State private var details: ItemDetails
    @State private var playback = VideoPlayback()

    init(item: FeedItem, isActive: Bool, pageSize: CGSize, sideInsets: EdgeInsets = EdgeInsets(),
         step: @escaping (Int) -> (() -> Void)? = { _ in nil }) {
        self.item = item
        self.isActive = isActive
        self.pageSize = pageSize
        self.sideInsets = sideInsets
        self.step = step
        _details = State(initialValue: ItemDetails(itemID: item.id))
    }

    private var isSideBySide: Bool {
        sizeClass == .regular && pageSize.width > pageSize.height
    }

    var body: some View {
        Group {
            if isSideBySide {
                HStack(spacing: 0) {
                    GeometryReader { proxy in
                        ScrollView {
                            media(maxHeight: max(proxy.size.height - (item.sourceURL == nil ? 0 : SourceBar.height), 0))
                                .frame(width: proxy.size.width)
                        }
                        .defaultScrollAnchor(.center, for: .alignment)
                    }
                    .padding(.leading, sideInsets.leading)
                    .background(Color.black)

                    ScrollView {
                        column
                            .padding(.top, 8)
                            .padding(.trailing, sideInsets.trailing)
                    }
                    .frame(width: min(max(pageSize.width * 0.38, 340), 440) + sideInsets.trailing)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        media(maxHeight: max(pageSize.height * 0.75, 200), insets: sideInsets)
                        column.padding(.leading, sideInsets.leading).padding(.trailing, sideInsets.trailing)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .onDisappear { playback.stop() }
        .task { await details.load() }
    }

    private func media(maxHeight: CGFloat, insets: EdgeInsets = EdgeInsets()) -> some View {
        VStack(spacing: 0) {
            MediaView(item: item, isActive: isActive, playback: playback, maxHeight: maxHeight)
                .overlay { StepArrows(previous: step(-1), next: step(1)) }
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

    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            ItemInfoBar(item: item)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)

            content.padding(.horizontal, 16)
        }
        .padding(.bottom, 40)
    }

    @ViewBuilder
    private var content: some View {
        if let info = details.info {
            TagsSection(tags: info.tags)
            CommentsSection(item: item, details: details)
                .padding(.top, 28)
        } else if let error = details.error {
            ErrorView(error: error, retry: details.load)
        } else {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
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
                            Text("\(item.createdAt.pr0Age) · \(UserMark.name(item.mark))")
                                .font(.footnote)
                                .foregroundStyle(Color.pr0Secondary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Menu {
                    Button("Link kopieren", systemImage: "link") {
                        #if canImport(UIKit)
                        UIPasteboard.general.url = item.webURL
                        #endif
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

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    VoteCapsule(item: item)
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

struct VoteCapsule: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    let item: FeedItem
    var body: some View {
        let vote = session.vote(for: .item, id: item.id)
        HStack(spacing: 0) {
            button(value: 1, current: vote, symbol: "plus", label: "Plus")
            ScoreView(score: item.score + vote, created: item.createdAt)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(vote == 0 ? Color.pr0Text : Color.pr0Orange)
                .frame(minWidth: 36)
            button(value: -1, current: vote, symbol: "minus", label: "Minus")
        }
        .frame(height: 38)
        .background(Color.pr0Pill, in: .capsule)
        .animation(.snappy, value: vote)
    }

    private func button(value: Int, current: Int, symbol: String, label: String) -> some View {
        let active = current == value
        return Button {
            Task { await app.toggleVote(.item, id: item.id, value, in: session) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(active ? Color.white : Color.pr0Text)
                .frame(width: 30, height: 30)
                .background(active ? Color.pr0Orange : .clear, in: .circle)
                .frame(width: 42, height: 38)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: active)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
