import SwiftUI

struct CommentNode: Identifiable {
    let comment: Comment
    let depth: Int
    let replyCount: Int
    var id: Int { comment.id }

    /// Siblings are ordered by confidence like on the website.
    static func flatten(_ comments: [Comment], collapsed: Set<Int>) -> [CommentNode] {
        let children = Dictionary(grouping: comments, by: \.parent)
            .mapValues { $0.sorted { $0.confidence > $1.confidence } }
        let known = Set(comments.map(\.id))
        var result: [CommentNode] = []

        func descendants(of id: Int) -> Int {
            (children[id] ?? []).reduce(0) { $0 + 1 + descendants(of: $1.id) }
        }

        func visit(_ comment: Comment, depth: Int) {
            result.append(CommentNode(comment: comment, depth: depth, replyCount: descendants(of: comment.id)))
            guard !collapsed.contains(comment.id) else { return }
            for reply in children[comment.id] ?? [] { visit(reply, depth: depth + 1) }
        }

        // Replies whose parent was deleted are shown as top-level comments.
        let roots = comments.filter { $0.parent == 0 || !known.contains($0.parent) }
            .sorted { $0.confidence > $1.confidence }
        for root in roots { visit(root, depth: 0) }
        return result
    }
}

struct CommentsSection: View {
    @Environment(Session.self) private var session
    let item: FeedItem
    let details: ItemDetails

    @State private var collapsed: Set<Int> = []

    private var comments: [Comment] { details.info?.comments ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(comments.count == 1 ? "1 Kommentar" : "\(comments.count) Kommentare")
                    .font(.title3.weight(.semibold))
                Spacer()
                if session.isLoggedIn {
                    Button("Kommentieren", systemImage: "square.and.pencil") {
                        details.replyTarget = ReplyTarget(parentId: 0, name: nil)
                    }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(CommentNode.flatten(comments, collapsed: collapsed)) { node in
                    CommentRow(
                        node: node,
                        isOP: node.comment.name == item.user,
                        isCollapsed: collapsed.contains(node.id),
                        onToggle: { toggle(node.id) },
                        onReply: { details.replyTarget = ReplyTarget(parentId: node.comment.id, name: node.comment.name) }
                    )
                }
            }
        }
    }

    private func toggle(_ id: Int) {
        withAnimation(.snappy) {
            if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
        }
    }
}

struct ReplyTarget: Identifiable {
    let parentId: Int
    let name: String?
    var id: Int { parentId }
}

extension View {
    /// Presents the comment composer for `details.replyTarget`. Attach it to a view that keeps its
    /// identity while the post's layout changes, so a rotation doesn't throw away a draft.
    func commentComposer(item: FeedItem, details: ItemDetails) -> some View {
        @Bindable var details = details
        return sheet(item: $details.replyTarget) { target in
            CommentComposer(itemId: item.id, parentId: target.parentId,
                            replyingTo: target.name) { comments in
                Task { await details.apply(postedComments: comments) }
            }
        }
    }
}

private struct CommentRow: View {
    @Environment(Session.self) private var session
    let node: CommentNode
    let isOP: Bool
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onReply: () -> Void

    private static let maxIndent = 6

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<min(node.depth, Self.maxIndent), id: \.self) { _ in
                Rectangle()
                    .fill(Color.pr0ThreadLine)
                    .frame(width: 3)
                    .padding(.trailing, 10)
            }

            VStack(alignment: .leading, spacing: 6) {
                header

                Text(CommentText.attributed(node.comment.content))
                    .font(.body)
                    .foregroundStyle(.white)
                    .tint(.pr0Mention)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    if session.isLoggedIn {
                        Button(action: onReply) {
                            Label("Antworten", systemImage: "arrowshape.turn.up.left")
                                .font(.footnote)
                                .foregroundStyle(Color.pr0Secondary)
                                .frame(minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                    if node.replyCount > 0 {
                        Button(action: onToggle) {
                            Text(isCollapsed
                                 ? (node.replyCount == 1 ? "1 Antwort anzeigen" : "\(node.replyCount) Antworten anzeigen")
                                 : (node.replyCount == 1 ? "1 Antwort" : "\(node.replyCount) Antworten"))
                                .font(.footnote)
                                .foregroundStyle(Color.pr0Orange)
                                .frame(minHeight: 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(isCollapsed ? "Aufklappen" : "Einklappen")
                    }
                    Spacer(minLength: 8)
                    CommentVotes(comment: node.comment)
                }
                .padding(.top, -6)
            }
            .padding(.top, 10)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            NavigationLink(value: Route.user(node.comment.name)) {
                HStack(spacing: 6) {
                    Avatar(name: node.comment.name, size: 24)
                    if isOP { OPBadge() }
                    Text(node.comment.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.pr0Text)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            MarkDot(mark: node.comment.mark, size: 7)
            Text(node.comment.createdAt.pr0Age)
                .font(.caption)
                .foregroundStyle(Color.pr0Secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Menu {
                Button("Text kopieren", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = node.comment.content
                }
                if node.replyCount > 0 {
                    Button(isCollapsed ? "Antworten aufklappen" : "Antworten einklappen",
                           systemImage: isCollapsed ? "chevron.down" : "chevron.up", action: onToggle)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .foregroundStyle(Color.pr0Secondary)
                    .frame(width: 32, height: 28)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Aktionen")
        }
    }
}

/// Plus, the comment's score and minus in one row. Each button gets its own column and a 44 pt
/// tall hit area, so the two never overlap.
struct CommentVotes: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    let comment: Comment

    var body: some View {
        let vote = session.vote(for: .comment, id: comment.id)
        HStack(spacing: 0) {
            button(value: 1, current: vote, symbol: "plus", label: "Plus", color: .pr0Orange)
            ScoreView(score: session.score(of: comment), created: comment.createdAt)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(vote > 0 ? Color.pr0Orange : vote < 0 ? Color.voteDown : Color.pr0Text)
                .frame(minWidth: 34)
            button(value: -1, current: vote, symbol: "minus", label: "Minus", color: .voteDown)
        }
        .animation(.snappy, value: vote)
    }

    private func button(value: Int, current: Int, symbol: String, label: String, color: Color) -> some View {
        let active = current == value
        return Button {
            Task { await app.toggleVote(.comment, id: comment.id, value) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(active ? color : Color.pr0Secondary)
                .frame(width: 34, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: active)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

enum CommentText {
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    private static let mention = /@([A-Za-z0-9_-]{2,32})/

    static func attributed(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        let range = NSRange(text.startIndex..., in: text)
        detector?.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, let url = match.url,
                  let swiftRange = Range(match.range, in: text),
                  let attributedRange = Range(swiftRange, in: result) else { return }
            result[attributedRange].link = url
        }
        for match in text.matches(of: mention) {
            guard let attributedRange = Range(match.range, in: result) else { continue }
            result[attributedRange].link = Site.user(String(match.output.1))
        }
        return result
    }
}
