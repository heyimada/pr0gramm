import SwiftUI

struct StreamsScreen: View {
    @Environment(FeedLibrary.self) private var library
    @State private var selection: FeedSource?
    /// The preset picked last, kept as the last page so swiping away from it doesn't remove it
    /// mid-swipe.
    @State private var preset: FeedSource?
    @State private var cache = FeedCache()

    private var sources: [FeedSource] {
        library.sources(withSubscriptions: true, picked: preset)
    }

    private var current: FeedSource {
        library.currentSource(picked: selection, in: sources)
    }

    private func pick(_ source: FeedSource) {
        if case .preset = source { preset = source }
        selection = source
    }

    var body: some View {
        // Pages span the whole screen so posts scroll under the toolbar and the tab bar; margins
        // keep the first and last rows clear of them.
        GeometryReader { outer in
            let insets = outer.safeAreaInsets
            // Leading and trailing too: the closed iPhone Duo keeps its tab bar along the right edge.
            let margins = EdgeInsets(top: insets.top, leading: insets.leading,
                                     bottom: insets.bottom, trailing: insets.trailing)
            FeedPager(sources: sources, current: current, onSwipe: { selection = $0 }) { source in
                let query = library.query(for: source)
                FeedGrid(model: cache.model(for: query))
                    .contentMargins(.all, margins, for: .scrollContent)
                    .contentMargins(.all, margins, for: .scrollIndicators)
                    .id(query)
            }
        }
        .background(Color.pr0Background)
        .toolbar {
            // Beside the logo, which the tab's toolbar puts first.
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) { menu }
                .sharedBackgroundVisibility(.hidden)
            #else
            ToolbarItem(placement: .navigation) { menu }
            #endif
        }
    }

    private var menu: some View {
        StreamMenu(sources: sources, selection: Binding(get: { current }, set: { pick($0) })) {
            StreamMenuLabel(title: library.title(for: current))
        }
    }
}
