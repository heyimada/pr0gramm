import SwiftUI

struct FeedSettingsView: View {
    @Environment(FeedLibrary.self) private var library
    @State private var editedFeed: CustomFeed?
    @State private var addsFeed = false

    private var sources: [FeedSource] {
        FeedStream.searchable.map(FeedSource.stream) + library.accessibleCustomFeeds.map { .custom($0.id) }
    }

    private func delete(at offsets: IndexSet) {
        let ids = offsets.map { library.accessibleCustomFeeds[$0].id }
        ids.forEach(library.remove)
    }

    var body: some View {
        @Bindable var library = library
        List {
            Section {
                Picker("Standard-Feed", selection: $library.defaultSource) {
                    ForEach(sources, id: \.self) { source in
                        Text(library.title(for: source)).tag(source)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Standard-Feed")
            } footer: {
                Text("Damit starten Start, Feed und Reels. Tags und die Suche öffnen im selben Stream. Ist ein eigener Feed wegen der Filter ausgeblendet, gilt sein Stream.")
            }

            Section {
                ForEach(library.accessibleCustomFeeds) { feed in
                    Button { editedFeed = feed } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(feed.name).foregroundStyle(Color.pr0Text)
                                if feed.isProtected {
                                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(Color.pr0Secondary)
                                }
                            }
                            Text(([feed.tags, feed.stream.title] + ContentFlags.filterTitles(in: feed.flags)).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(Color.pr0Secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .onMove(perform: library.moveAccessible)
                .onDelete(perform: delete)

                Button("Feed hinzufügen", systemImage: "plus") { addsFeed = true }
                if library.hasProtectedFeeds {
                    ProtectedFeedsButton()
                }
            } header: {
                Text("Eigene Feeds")
            } footer: {
                Text("Eigene Feeds erscheinen im Feed-Tab und in Reels neben beliebt, neu und müll, auf Wunsch nur bei bestimmten Filtern. Du kannst auch eine Suche mit dem Lesezeichen speichern.")
            }
        }
        .pr0FormBackground()
        .inlineNavigationTitle("Feeds")
        .toolbar {
            if !library.accessibleCustomFeeds.isEmpty {
                EditButton()
            }
        }
        .sheet(item: $editedFeed) { CustomFeedEditor(feed: $0, isNew: false) }
        .sheet(isPresented: $addsFeed) { CustomFeedEditor(feed: CustomFeed(), isNew: true) }
    }
}
