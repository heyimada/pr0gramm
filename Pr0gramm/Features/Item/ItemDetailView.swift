import SwiftUI

/// One post as laid out on pr0.app: media, vote/info bar, tags, comments.
struct ItemDetailView: View {
    @Environment(Session.self) private var session
    let item: FeedItem
    let isActive: Bool
    let pageHeight: CGFloat
    /// Returns an action moving to the previous (-1) or next (+1) post, if there is one.
    var step: (Int) -> (() -> Void)? = { _ in nil }

    @State private var info: ItemInfo?
    @State private var infoError: Error?
    @State private var replyTarget: ReplyTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MediaView(item: item, isActive: isActive, maxHeight: max(pageHeight * 0.75, 200))
                    .overlay { StepArrows(previous: step(-1), next: step(1)) }

                if let sourceURL = item.sourceURL {
                    SourceBar(url: sourceURL)
                }

                ItemInfoBar(item: item)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                content.padding(.horizontal, 16)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .task { await loadInfo() }
        .sheet(item: $replyTarget) { target in
            CommentComposer(itemId: item.id, parentId: target.parentId,
                            replyingTo: target.parentId == 0 ? nil : target.name) { comments in
                apply(comments)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let info {
            TagsSection(tags: info.tags)
            CommentsSection(item: item, comments: info.comments,
                            onComment: { replyTarget = ReplyTarget(parentId: 0, name: item.user) },
                            onReply: { comment in replyTarget = ReplyTarget(parentId: comment.id, name: comment.name) })
                .padding(.top, 28)
        } else if let infoError {
            ErrorView(error: infoError, retry: loadInfo)
        } else {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
        }
    }

    private func apply(_ comments: [Comment]?) {
        if let comments, let tags = info?.tags {
            info = ItemInfo(tags: tags, comments: comments)
        } else {
            Task { await loadInfo() }
        }
    }

    private func loadInfo() async {
        do {
            info = try await APIClient.shared.itemInfo(item.id)
            infoError = nil
        } catch is CancellationError {
        } catch {
            infoError = error
        }
    }
}

private struct SourceBar: View {
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
            .frame(minHeight: 44)
            .background(Color.pr0Pill)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Soße: \(domain)")
        .accessibilityHint("Öffnet die Quelle im Browser")
    }
}

private struct ReplyTarget: Identifiable {
    let parentId: Int
    let name: String
    var id: Int { parentId }
}

/// Faint ‹ › buttons on the media's edges for stepping through the feed.
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

/// Uploader row, then a row of actions (vote capsule, share, download) below the media.
struct ItemInfoBar: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL
    let item: FeedItem

    private var link: URL { URL(string: "https://pr0gramm.com/new/\(item.id)")! }

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
                        UIPasteboard.general.url = link
                        #endif
                    }
                    Button("Im Browser öffnen", systemImage: "safari") { openURL(link) }
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
                    ShareLink(item: link) {
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

/// Label of a pill-shaped action button in the post's action row.
struct ActionPillLabel: View {
    let title: String
    let symbol: String
    var tint: Color = .pr0Text

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Color.pr0Pill, in: .capsule)
            .contentShape(.capsule)
    }
}

/// ⊕ score ⊖ in one capsule.
struct VoteCapsule: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    let item: FeedItem
    @State private var failed = false

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
        .alert("Abstimmen fehlgeschlagen", isPresented: $failed) {}
    }

    private func button(value: Int, current: Int, symbol: String, label: String) -> some View {
        let active = current == value
        return Button {
            guard session.isLoggedIn else { return app.showsLogin = true }
            Task {
                do { try await session.vote(.item, id: item.id, value: active ? 0 : value) } catch { failed = true }
            }
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
