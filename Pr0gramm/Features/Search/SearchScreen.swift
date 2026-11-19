import SwiftUI

struct SearchScreen: View {
    @Environment(FeedLibrary.self) private var library
    @Environment(\.bookPages) private var bookPages
    @State private var search = SearchOptions()
    @State private var results: FeedModel?
    @AppStorage("recentSearches") private var recentStorage = ""

    private var recent: [String] {
        recentStorage.split(separator: "\n").map(String.init)
    }

    var body: some View {
        Group {
            if let results {
                FeedScreenContent(model: results) { stream in
                    search.stream = stream
                    submit()
                }
                .id(ObjectIdentifier(results))
            } else {
                options
            }
        }
        .searchable(text: $search.text, prompt: "Tags, z. B. kadse")
        .onChange(of: library.defaultStream, initial: true) { search.stream = library.defaultStream }
        .onSubmit(of: .search, submit)
        .onChange(of: search.text) {
            if search.text.isEmpty { results = nil }
        }
    }

    @ViewBuilder
    private var options: some View {
        if bookPages != nil, #available(iOS 27.1, visionOS 27.1, *) {
            // Book Mode: what you searched before on one page, how to search on the other.
            ArrangementView {
                Form {
                    if recent.isEmpty {
                        Text("Deine letzten Suchen erscheinen hier.").foregroundStyle(Color.pr0Secondary)
                    }
                    recentSection
                }
                .pr0FormBackground()
            } secondary: {
                Form { filterSections }.pr0FormBackground()
            }
            .arrangementViewStyle(.split)
        } else {
            Form {
                filterSections
                recentSection
            }
            .pr0FormBackground()
        }
    }

    @ViewBuilder
    private var filterSections: some View {
        Section("Suchen in") {
            Picker("Suchen in", selection: $search.stream) {
                ForEach(FeedStream.searchable) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Picker("Medien", selection: $search.media) {
                ForEach(SearchOptions.Media.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        }

        Section {
            Toggle("Mindest-Benis", isOn: $search.requiresMinimumScore.animation())
            if search.requiresMinimumScore {
                LabeledContent("Mindestens") {
                    Text("\(search.minimumScore) Benis").monospacedDigit()
                }
                Slider(value: $search.scoreSlider, in: 0...100)
            }
            TextField("Tags ausschließen, z. B. kadse fogel", text: $search.excludedTags)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !recent.isEmpty {
            Section("Zuletzt gesucht") {
                ForEach(recent, id: \.self) { term in
                    Button(term) {
                        search.text = term
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

    private func submit() {
        guard let query = search.query else { return }
        results = FeedModel(query: query)
        let term = search.text.trimmingCharacters(in: .whitespaces)
        if !term.isEmpty {
            recentStorage = ([term] + recent.filter { $0 != term }).prefix(15).joined(separator: "\n")
        }
    }
}
