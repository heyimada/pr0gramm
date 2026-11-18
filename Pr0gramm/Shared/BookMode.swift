import SwiftUI

/// The two pages of an iPhone Duo held like a book, in global coordinates.
struct BookPages: Equatable {
    var leading: CGRect
    var trailing: CGRect

    var gap: CGFloat { trailing.minX - leading.maxX }
}

extension EnvironmentValues {
    /// Set while the hinge is partially open (Book Mode); nil when it is closed or flat, and on
    /// devices without a hinge.
    @Entry var bookPages: BookPages?
}

extension View {
    /// In Book Mode, centres this view on the leading page instead of the whole width.
    func centeredOnLeadingPage() -> some View {
        modifier(LeadingPageCentering())
    }

    /// Publishes `bookPages` to everything inside. Apply once, at the root of a window.
    func readsBookPages() -> some View {
        modifier(BookPagesReader())
    }
}

private struct LeadingPageCentering: ViewModifier {
    @Environment(\.bookPages) private var bookPages

    func body(content: Content) -> some View {
        if let pages = bookPages {
            content
                .frame(width: pages.leading.width)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content
        }
    }
}

private struct BookPagesReader: ViewModifier {
    @State private var isPartiallyOpen = false
    @State private var leading = CGRect.zero
    @State private var trailing = CGRect.zero

    private var pages: BookPages? {
        guard isPartiallyOpen, !leading.isEmpty, !trailing.isEmpty else { return nil }
        return BookPages(leading: leading, trailing: trailing)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.bookPages, pages)
            .background {
                if #available(iOS 27.1, visionOS 27.1, *) {
                    // The system's split leaves the fold free; measuring its two panes gives the
                    // pages without knowing the fold's size.
                    ArrangementView {
                        Color.clear.onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { leading = $0 }
                    } secondary: {
                        Color.clear.onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { trailing = $0 }
                    }
                    .arrangementViewStyle(.split)
                    .background(HingeObserver(isPartiallyOpen: $isPartiallyOpen))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
    }
}

@available(iOS 27.1, visionOS 27.1, *)
private struct HingeObserver: UIViewRepresentable {
    @Binding var isPartiallyOpen: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        let binding = $isPartiallyOpen
        view.addInteraction(UIHingeInteraction { _, update in
            let open = update.hinge?.status == .partiallyOpen
            if binding.wrappedValue != open { binding.wrappedValue = open }
        })
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {}
}
