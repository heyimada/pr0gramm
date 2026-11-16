import SwiftUI

struct FeedScreen: View {
    @State private var model: FeedModel

    init(query: FeedQuery) {
        _model = State(initialValue: FeedModel(query: query))
    }

    var body: some View {
        FeedScreenContent(model: model) { stream in
            var query = model.query
            query.stream = stream
            model = FeedModel(query: query)
        }
        .id(ObjectIdentifier(model))
        .navigationTitle(model.query.tags == nil ? model.query.title : "Suche")
    }
}

struct FeedScreenContent: View {
    @Environment(FeedLibrary.self) private var library
    let model: FeedModel
    let onSelectStream: (FeedStream) -> Void
    @State private var newFeed: CustomFeed?

    private var savedFeed: CustomFeed? {
        library.accessibleCustomFeeds.first { $0.query == model.query }
    }

    var body: some View {
        FeedGrid(model: model) {
            if let tags = model.query.tags {
                VStack(spacing: 12) {
                    Text(tags)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        SegmentCapsule(
                            options: FeedStream.searchable,
                            selection: Binding(get: { model.query.stream }, set: { onSelectStream($0) }),
                            title: \.title
                        )
                        saveButton
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $newFeed) { feed in
            CustomFeedEditor(feed: feed, isNew: true)
        }
    }

    private var saveButton: some View {
        Button {
            if let savedFeed {
                withAnimation { library.remove(savedFeed.id) }
            } else {
                newFeed = CustomFeed(query: model.query)
            }
        } label: {
            Image(systemName: savedFeed == nil ? "bookmark" : "bookmark.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(savedFeed == nil ? Color.pr0Text : Color.pr0Orange)
                .frame(width: 40, height: 40)
                .contentShape(.circle)
                .glassCircle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(savedFeed == nil ? "Als Feed speichern" : "Gespeicherten Feed entfernen")
    }
}
