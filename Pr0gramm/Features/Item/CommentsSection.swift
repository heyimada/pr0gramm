import SwiftUI

/// A comment positioned in the flattened thread.
struct CommentNode: Identifiable {
    let comment: Comment
    let depth: Int
    let replyCount: Int
    var id: Int { comment.id }

    /// Depth-first flattening; siblings are ordered by confidence like on the website.
    /// Descendants of `collapsed` comments are skipped.
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
    let comments: [Comment]
    let onComment: () -> Void
    let onReply: (Comment) -> Void

    @State private var collapsed: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(comments.count == 1 ? "1 Kommentar" : "\(comments.count) Kommentare")
                    .font(.title3.weight(.semibold))
                Spacer()
                if session.isLoggedIn {
                    Button("Kommentieren", systemImage: "square.and.pencil", action: onComment)
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
                        onReply: { onReply(node.comment) }
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

private struct CommentRow: View {
    @Environment(Session.self) private var session
    let node: CommentNode
    let isOP: Bool
    let isCollapsed: Bool
    let onToggle: () -> Void
    let onReply: () -> Void

    /// Past this depth, threads stop indenting so text stays readable on phones.
    private static let maxIndent = 6

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<min(node.depth, Self.maxIndent), id: \.self) { _ in
                Rectangle()
                    .fill(Color.pr0ThreadLine)
                    .frame(width: 3)
                    .padding(.trailing, 10)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VoteButtons(target: .comment, id: node.comment.id, size: 20)
                        .padding(.top, 1)
                    Text(CommentText.attributed(node.comment.content))
                        .font(.body)
                        .foregroundStyle(.white)
                        .tint(.pr0Mention)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                footer

                if node.replyCount > 0 {
                    Button(action: onToggle) {
                        Text(isCollapsed
                             ? (node.replyCount == 1 ? "1 Antwort anzeigen" : "\(node.replyCount) Antworten anzeigen")
                             : (node.replyCount == 1 ? "1 Antwort" : "\(node.replyCount) Antworten"))
                            .font(.caption)
                            .foregroundStyle(Color.pr0Orange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(isCollapsed ? "Aufklappen" : "Einklappen")
                }
            }
            .padding(.vertical, 10)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            NavigationLink(value: Route.user(node.comment.name)) {
                HStack(spacing: 6) {
                    Avatar(name: node.comment.name, size: 24)
                    if isOP { OPBadge() }
                    Text(node.comment.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.pr0Text)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            MarkDot(mark: node.comment.mark, size: 7)
            ScoreView(score: node.comment.score, created: node.comment.createdAt)
                .font(.caption)
                .foregroundStyle(Color.pr0Secondary)
            Text(node.comment.createdAt.pr0Age)
                .font(.caption)
                .foregroundStyle(Color.pr0Secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if session.isLoggedIn {
                Button(action: onReply) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.pr0Orange)
                        .frame(width: 32, height: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Antworten")
            }

            Menu {
                Button("Text kopieren", systemImage: "doc.on.doc") {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = node.comment.content
                    #endif
                }
                if node.replyCount > 0 {
                    Button(isCollapsed ? "Antworten aufklappen" : "Antworten einklappen",
                           systemImage: isCollapsed ? "chevron.down" : "chevron.up", action: onToggle)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.subheadline)
                    .foregroundStyle(Color.pr0Secondary)
                    .frame(width: 24, height: 28)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Aktionen")
        }
    }
}

/// Turns plain comment text into an `AttributedString` with tappable URLs and @mentions.
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
            guard let attributedRange = Range(match.range, in: result),
                  let url = URL(string: "https://pr0gramm.com/user/\(match.output.1)") else { continue }
            result[attributedRange].link = url
        }
        return result
    }
}
