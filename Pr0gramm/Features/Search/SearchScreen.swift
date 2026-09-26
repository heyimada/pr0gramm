import SwiftUI

/// Search tab. The system search field lives in the tab bar; below it the extended options,
/// then results once a search has been submitted.
struct SearchScreen: View {
    @Environment(AppState.self) private var app
    @State private var results: FeedModel?
    @AppStorage("recentSearches") private var recentStorage = ""

    private var recent: [String] {
        recentStorage.split(separator: "\n").map(String.init)
    }

    var body: some View {
        @Bindable var app = app
        Group {
            if let results {
                FeedScreenContent(model: results) { stream in
                    app.search.stream = stream
                    submit()
                }
                .id(ObjectIdentifier(results))
            } else {
                options
            }
        }
        .searchable(text: $app.search.text, prompt: "Tags, z. B. kadse")
        .onSubmit(of: .search, submit)
        .onChange(of: app.search.text) {
            if app.search.text.isEmpty { results = nil }
        }
    }

    private var options: some View {
        @Bindable var app = app
        return Form {
            Section("Suchen in") {
                Picker("Suchen in", selection: $app.search.stream) {
                    ForEach(FeedStream.searchable) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Picker("Medien", selection: $app.search.media) {
                    ForEach(SearchOptions.Media.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }

            Section {
                Toggle("Mindest-Benis", isOn: $app.search.requiresMinimumScore.animation())
                if app.search.requiresMinimumScore {
                    LabeledContent("Mindestens") {
                        Text("\(app.search.minimumScore) Benis").monospacedDigit()
                    }
                    Slider(value: $app.search.scoreSlider, in: 0...100)
                }
                TextField("Tags ausschließen, z. B. kadse fogel", text: $app.search.excludedTags)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            if !recent.isEmpty {
                Section("Zuletzt gesucht") {
                    ForEach(recent, id: \.self) { term in
                        Button(term) {
                            app.search.text = term
                            submit()
                        }
                        .foregroundStyle(Color.pr0Text)
                    }
                    .onDelete { offsets in
                        var terms = recent
                        terms.remove(atOffsets: offsets)
                        recentStorage = terms.joined(separator: "\n")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.pr0Background)
    }

    private func submit() {
        guard let query = app.search.query else { return }
        results = FeedModel(query: query)
        let term = app.search.text.trimmingCharacters(in: .whitespaces)
        if !term.isEmpty {
            recentStorage = ([term] + recent.filter { $0 != term }).prefix(15).joined(separator: "\n")
        }
    }
}
