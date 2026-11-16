import SwiftUI

struct TagsSection: View {
    let tags: [Tag]
    @State private var expanded = false

    private static let collapsedCount = 5

    private var visibleTags: [Tag] {
        expanded ? tags : Array(tags.prefix(Self.collapsedCount))
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(visibleTags) { tag in
                TagPill(tag: tag)
            }
            if tags.count > Self.collapsedCount {
                Button(expanded ? "weniger" : "\(tags.count - Self.collapsedCount) weitere") {
                    withAnimation(.snappy) { expanded.toggle() }
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(Color.pr0Orange)
                .padding(.horizontal, 6)
                .frame(height: 32)
            }
        }
    }
}

private struct TagPill: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    let tag: Tag

    var body: some View {
        let vote = session.vote(for: .tag, id: tag.id)
        NavigationLink(value: Route.tag(tag.tag)) {
            TagCapsule(tag.tag, tint: vote == 0 ? nil : vote > 0 ? .upvoteGreen : .pr0Orange)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        #if os(visionOS)
        .hoverEffect()
        #endif
        .contextMenu {
            Button(vote == 1 ? "Plus entfernen" : "Plus", systemImage: "plus.circle") { cast(1) }
            Button(vote == -1 ? "Minus entfernen" : "Minus", systemImage: "minus.circle") { cast(-1) }
        }
    }

    private func cast(_ value: Int) {
        Task { await app.toggleVote(.tag, id: tag.id, value) }
    }
}
