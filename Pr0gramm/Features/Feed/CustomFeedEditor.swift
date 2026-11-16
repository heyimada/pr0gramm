import SwiftUI

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
                            library.remove(feed.id)
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
        if feed.name.isEmpty { feed.name = CustomFeed.defaultName(forTags: feed.tags) }
        library.save(feed, makeDefault: makesDefault)
        dismiss()
    }
}
