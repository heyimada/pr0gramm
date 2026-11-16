import SwiftUI

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
            .pr0FormBackground()
            .inlineNavigationTitle("Reels-Filter")
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
