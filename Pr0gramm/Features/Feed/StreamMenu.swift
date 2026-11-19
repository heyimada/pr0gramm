import SwiftUI

/// The feed picker behind the Feed title and the Reels pill. Streams, the website's presets, Abos
/// and the custom feeds each get a section, and the picked feed carries the checkmark.
struct StreamMenu<Label: View>: View {
    @Environment(FeedLibrary.self) private var library
    let sources: [FeedSource]
    @Binding var selection: FeedSource
    @ViewBuilder let label: Label

    var body: some View {
        Menu {
            picker(sources.filter { if case .stream(let stream) = $0 { stream != .subscribed } else { false } })
            picker(FeedPreset.allCases.map(FeedSource.preset))
            picker(sources.filter { $0 == .stream(.subscribed) })
            let custom = sources.filter { if case .custom = $0 { true } else { false } }
            if !custom.isEmpty {
                Section("Eigene Feeds") { picker(custom) }
            }
        } label: {
            label
        }
        .accessibilityLabel("Feed: \(library.title(for: selection))")
        .accessibilityHint("Feed wechseln")
    }

    @ViewBuilder
    private func picker(_ options: [FeedSource]) -> some View {
        if !options.isEmpty {
            Picker("Feed", selection: $selection) {
                ForEach(options, id: \.self) { source in
                    SwiftUI.Label(library.title(for: source), systemImage: Self.symbol(for: source)).tag(source)
                }
            }
            .pickerStyle(.inline)
        }
    }

    static func symbol(for source: FeedSource) -> String {
        switch source {
        case .stream(.top): "star"
        case .stream(.new): "sparkles"
        case .stream(.junk): "trash"
        case .stream(.subscribed): "bell"
        case .preset(let preset): preset.symbol
        case .custom: "tag"
        }
    }
}

/// The feed's name with an orange chevron, as Feed and Reels show it.
struct StreamMenuLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color.pr0Text)
                .lineLimit(1)
            MenuChevron(size: 13)
        }
        .frame(maxWidth: 260, alignment: .leading)
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}

/// The orange chevron that marks a title as a menu.
struct MenuChevron: View {
    var size: CGFloat

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Color.pr0Orange)
    }
}

extension ContentFlags {
    /// "Nur SFW" for one active filter, otherwise the active filters in a list.
    var summary: String {
        let titles = ContentFlags.filterTitles(in: self)
        return titles.count == 1 ? "Nur \(titles[0])" : titles.joined(separator: ", ")
    }
}
