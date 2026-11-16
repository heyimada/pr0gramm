import SwiftUI

extension View {
    /// Keeps a paging scroll view on the page whose ID is `current` and writes swipes back to it.
    ///
    /// `scrollPosition(id:)` alone isn't enough: it leaves the view on the first page when it
    /// first appears, and it keeps the content offset in points when the pages change size, e.g.
    /// after the iPhone Duo was rotated or unfolded while the app was in the background, which
    /// leaves the view resting between two pages.
    func pagePosition<ID: Hashable & Sendable>(_ current: Binding<ID?>, anchor: UnitPoint? = nil) -> some View {
        modifier(PagePosition(current: current, anchor: anchor))
    }
}

private struct PagePosition<ID: Hashable & Sendable>: ViewModifier {
    @Binding var current: ID?
    let anchor: UnitPoint?
    @State private var position = ScrollPosition(idType: ID.self)

    private var shown: ID? { position.viewID(type: ID.self) }

    func body(content: Content) -> some View {
        content
            .scrollPosition($position, anchor: anchor)
            .onAppear(perform: snap)
            .onChange(of: current) {
                guard shown != current else { return }
                withAnimation(.snappy) { snap() }
            }
            .onChange(of: shown) {
                if let shown, shown != current { current = shown }
            }
            .onScrollGeometryChange(for: CGSize.self, of: \.containerSize) { old, new in
                if old != new { snap() }
            }
    }

    private func snap() {
        if let current { position.scrollTo(id: current, anchor: anchor) }
    }
}
