import SwiftUI

struct TagsSection: View {
    let tags: [Tag]
    @State private var expanded = false

    private static let collapsedCount = 5

    private var visibleTags: [Tag] {
        let sorted = tags.sorted { $0.confidence > $1.confidence }
        return expanded ? sorted : Array(sorted.prefix(Self.collapsedCount))
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

/// Tag chip; tap searches, long press votes. A voted tag gets a colored outline.
private struct TagPill: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    let tag: Tag

    var body: some View {
        let vote = session.vote(for: .tag, id: tag.id)
        NavigationLink(value: Route.feed(FeedQuery(stream: .top, tags: tag.tag))) {
            Text(tag.tag)
                .font(.subheadline)
                .foregroundStyle(Color.pr0Text)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color.pr0Pill, in: .capsule)
                .overlay {
                    if vote != 0 {
                        Capsule().strokeBorder(vote > 0 ? Color.upvoteGreen : Color.pr0Orange, lineWidth: 1.5)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        #if os(visionOS)
        .hoverEffect()
        #endif
        .contextMenu {
            Button(vote == 1 ? "Plus entfernen" : "Plus", systemImage: "plus.circle") { cast(vote == 1 ? 0 : 1) }
            Button(vote == -1 ? "Minus entfernen" : "Minus", systemImage: "minus.circle") { cast(vote == -1 ? 0 : -1) }
        }
    }

    private func cast(_ value: Int) {
        guard session.isLoggedIn else { return app.showsLogin = true }
        Task { try? await session.vote(.tag, id: tag.id, value: value) }
    }
}
