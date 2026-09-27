import SwiftUI

/// Choose the default feed and manage saved tag feeds.
struct FeedSettingsView: View {
    @Environment(AppState.self) private var app
    @State private var editedFeed: CustomFeed?
    @State private var addsFeed = false

    private var sources: [FeedSource] {
        FeedStream.searchable.map(FeedSource.stream) + app.customFeeds.map { .custom($0.id) }
    }

    var body: some View {
        @Bindable var app = app
        List {
            Section {
                Picker("Standard-Feed", selection: $app.defaultSource) {
                    ForEach(sources, id: \.self) { source in
                        Text(app.title(for: source)).tag(source)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Standard-Feed")
            } footer: {
                Text("Damit starten Start und Feed. Reels, Tags und die Suche öffnen im selben Stream.")
            }

            Section {
                ForEach(app.customFeeds) { feed in
                    Button { editedFeed = feed } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feed.name).foregroundStyle(Color.pr0Text)
                            Text("\(feed.tags) · \(feed.stream.title)")
                                .font(.caption)
                                .foregroundStyle(Color.pr0Secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .onMove { app.customFeeds.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { app.customFeeds.remove(atOffsets: $0) }

                Button("Feed hinzufügen", systemImage: "plus") { addsFeed = true }
            } header: {
                Text("Eigene Feeds")
            } footer: {
                Text("Eigene Feeds erscheinen im Feed-Tab neben beliebt, neu und müll. Du kannst auch eine Suche mit dem Lesezeichen speichern.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pr0Background)
        .navigationTitle("Feeds")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if !app.customFeeds.isEmpty {
                EditButton()
            }
        }
        .sheet(item: $editedFeed) { CustomFeedEditor(feed: $0, isNew: false) }
        .sheet(isPresented: $addsFeed) { CustomFeedEditor(feed: CustomFeed(), isNew: true) }
    }
}

/// Sheet to create or edit a saved tag feed.
struct CustomFeedEditor: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var feed: CustomFeed
    let isNew: Bool
    @State private var makesDefault = false

    init(feed: CustomFeed, isNew: Bool) {
        _feed = State(initialValue: feed)
        self.isNew = isNew
    }

    private var tagsAreEmpty: Bool {
        var tags = feed.tags.trimmingCharacters(in: .whitespaces)
        if tags.hasPrefix("!") { tags.removeFirst() }
        return tags.trimmingCharacters(in: .whitespaces).isEmpty
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
                    Toggle("Als Standard-Feed", isOn: $makesDefault)
                }

                if !isNew {
                    Section {
                        Button("Feed löschen", role: .destructive) {
                            app.customFeeds.removeAll { $0.id == feed.id }
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pr0Background)
            .navigationTitle(isNew ? "Neuer Feed" : "Feed bearbeiten")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", role: .confirm, action: save)
                        .disabled(tagsAreEmpty)
                }
            }
            .onAppear { makesDefault = app.defaultSource == .custom(feed.id) }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        feed.tags = feed.tags.trimmingCharacters(in: .whitespaces)
        feed.name = feed.name.trimmingCharacters(in: .whitespaces)
        if feed.name.isEmpty { feed.name = CustomFeed(query: FeedQuery(tags: feed.tags)).name }
        if let index = app.customFeeds.firstIndex(where: { $0.id == feed.id }) {
            app.customFeeds[index] = feed
        } else {
            app.customFeeds.append(feed)
        }
        if makesDefault {
            app.defaultSource = .custom(feed.id)
        } else if app.defaultSource == .custom(feed.id) {
            app.defaultSource = .stream(feed.stream)
        }
        dismiss()
    }
}
