import SwiftUI

/// What the Reels tab shows: stream, media type and tags to include or exclude. Persisted.
struct ReelsFilter: Codable, Equatable {
    var stream: FeedStream = .top
    var onlyVideos = true
    var includedTags: [String] = []
    var excludedTags: [String] = []

    var hasTagFilter: Bool { !includedTags.isEmpty || !excludedTags.isEmpty }

    /// Extended search query, e.g. `! video kadse "steile frise" -"süßvieh"`.
    var query: FeedQuery {
        func quoted(_ tag: String) -> String {
            tag.contains(where: \.isWhitespace) ? "\"\(tag)\"" : tag
        }
        var terms = onlyVideos ? ["video"] : []
        terms += includedTags.map(quoted)
        terms += excludedTags.map { "-\"\($0)\"" }
        return FeedQuery(stream: stream, tags: terms.isEmpty ? nil : "! " + terms.joined(separator: " "))
    }

    mutating func include(_ tag: String) {
        let tag = tag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !includedTags.contains(tag) else { return }
        excludedTags.removeAll { $0 == tag }
        includedTags.append(tag)
    }

    mutating func exclude(_ tag: String) {
        let tag = tag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !excludedTags.contains(tag) else { return }
        includedTags.removeAll { $0 == tag }
        excludedTags.append(tag)
    }

    static func load() -> ReelsFilter {
        guard let data = UserDefaults.standard.data(forKey: "reelsFilter"),
              let filter = try? JSONDecoder().decode(ReelsFilter.self, from: data) else { return ReelsFilter() }
        return filter
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: "reelsFilter")
    }
}

/// Sheet for editing the Reels filter.
struct ReelsFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: ReelsFilter
    @State private var newIncluded = ""
    @State private var newExcluded = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Nur Videos", isOn: $filter.onlyVideos)
                }

                Section {
                    tagList($filter.includedTags, tint: .upvoteGreen)
                    addField("Tag hinzufügen, z. B. kadse", text: $newIncluded) { filter.include($0) }
                } header: {
                    Text("Nur mit diesen Tags")
                } footer: {
                    Text("Posts müssen alle Tags haben.")
                }

                Section("Ausblenden") {
                    tagList($filter.excludedTags, tint: .pr0Orange)
                    addField("Tag ausschließen, z. B. süßvieh", text: $newExcluded) { filter.exclude($0) }
                }

                if filter.hasTagFilter {
                    Section {
                        Button("Tag-Filter zurücksetzen", role: .destructive) {
                            filter.includedTags = []
                            filter.excludedTags = []
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pr0Background)
            .navigationTitle("Reels-Filter")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig", role: .confirm) {
                        // Keep what was typed but not yet confirmed with return.
                        filter.include(newIncluded)
                        filter.exclude(newExcluded)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func tagList(_ tags: Binding<[String]>, tint: Color) -> some View {
        if !tags.wrappedValue.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(tags.wrappedValue, id: \.self) { tag in
                    Button {
                        withAnimation { tags.wrappedValue.removeAll { $0 == tag } }
                    } label: {
                        HStack(spacing: 6) {
                            Text(tag).lineLimit(1)
                            Image(systemName: "xmark").font(.caption2.weight(.bold))
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.pr0Text)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Color.pr0Pill, in: .capsule)
                        .overlay(Capsule().strokeBorder(tint, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tag) entfernen")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func addField(_ prompt: String, text: Binding<String>, add: @escaping (String) -> Void) -> some View {
        HStack {
            TextField(prompt, text: text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit {
                    withAnimation { add(text.wrappedValue) }
                    text.wrappedValue = ""
                }
            if !text.wrappedValue.isEmpty {
                Button {
                    withAnimation { add(text.wrappedValue) }
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Color.upvoteGreen)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hinzufügen")
            }
        }
    }
}
