import SwiftUI

/// Choose the default feed and manage saved tag feeds.
struct FeedSettingsView: View {
    @Environment(FeedLibrary.self) private var library
    @State private var editedFeed: CustomFeed?
    @State private var addsFeed = false

    private var sources: [FeedSource] {
        FeedStream.searchable.map(FeedSource.stream) + library.accessibleCustomFeeds.map { .custom($0.id) }
    }

    /// Moves within the shown feeds while locked protected feeds keep their places.
    private func move(from offsets: IndexSet, to offset: Int) {
        var shown = library.accessibleCustomFeeds
        shown.move(fromOffsets: offsets, toOffset: offset)
        var reordered = shown.makeIterator()
        library.customFeeds = library.customFeeds.map { library.isAccessible($0) ? reordered.next()! : $0 }
    }

    private func delete(at offsets: IndexSet) {
        let ids = Set(offsets.map { library.accessibleCustomFeeds[$0].id })
        library.customFeeds.removeAll { ids.contains($0.id) }
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
                .onMove(perform: move)
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

/// Sheet to create or edit a saved tag feed.
struct CustomFeedEditor: View {
    @Environment(FeedLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var feed: CustomFeed
    let isNew: Bool
    @State private var makesDefault = false

    init(feed: CustomFeed, isNew: Bool) {
        _feed = State(initialValue: feed)
        self.isNew = isNew
    }

    private var tagsAreEmpty: Bool {
        TagQuery(feed.tags).body.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Katzen", text: $feed.name)
                    TextField("Tags, z. B. kadse -süßvieh", text: $feed.tags)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } footer: {
                    Text("Posts müssen alle Tags haben. Mit - davor wird ein Tag ausgeblendet; die erweiterte Suche mit ! funktioniert auch.")
                }

                Section("Stream") {
                    Picker("Stream", selection: $feed.stream) {
                        ForEach(FeedStream.searchable) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    ForEach(ContentFlags.filters, id: \.title) { filter in
                        Toggle(isOn: Binding {
                            feed.flags.contains(filter.flag)
                        } set: { isOn in
                            if isOn { feed.flags.insert(filter.flag) } else { feed.flags.remove(filter.flag) }
                        }) {
                            Text(filter.title)
                        }
                    }
                } header: {
                    Text("Nur anzeigen bei")
                } footer: {
                    Text("Ohne Auswahl ist der Feed immer da. Sonst erscheint er nur, wenn ausschließlich ausgewählte Filter an sind: Ein NSFW-Feed verschwindet also, sobald auch SFW an ist.")
                }

                Section {
                    Toggle("Mit Face ID schützen", isOn: $feed.isProtected)
                } footer: {
                    Text("Geschützte Feeds bleiben überall ausgeblendet, bis du sie im Filter-Menü mit Face ID entsperrst. Sobald du die App verlässt, sind sie wieder gesperrt.")
                }

                Section {
                    Toggle("Als Standard-Feed", isOn: $makesDefault)
                }

                if !isNew {
                    Section {
                        Button("Feed löschen", role: .destructive) {
                            library.customFeeds.removeAll { $0.id == feed.id }
                            dismiss()
                        }
                    }
                }
            }
            .pr0FormBackground()
            .inlineNavigationTitle(isNew ? "Neuer Feed" : "Feed bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", role: .confirm, action: save)
                        .disabled(tagsAreEmpty)
                }
            }
            .onAppear { makesDefault = library.defaultSource == .custom(feed.id) }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        feed.tags = feed.tags.trimmingCharacters(in: .whitespaces)
        feed.name = feed.name.trimmingCharacters(in: .whitespaces)
        if feed.name.isEmpty { feed.name = CustomFeed(query: FeedQuery(tags: feed.tags)).name }
        if let index = library.customFeeds.firstIndex(where: { $0.id == feed.id }) {
            library.customFeeds[index] = feed
        } else {
            library.customFeeds.append(feed)
        }
        if makesDefault {
            library.defaultSource = .custom(feed.id)
        } else if library.defaultSource == .custom(feed.id) {
            library.defaultSource = .stream(feed.stream)
        }
        dismiss()
    }
}
