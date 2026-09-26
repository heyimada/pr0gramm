import SwiftUI

#if os(iOS)
/// Full-screen image viewer with pinch-to-zoom, panning and double-tap zoom.
struct ZoomableImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    let aspectRatio: CGFloat

    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    var body: some View {
        RemoteImage(url: url)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .contentShape(.rect)
            .gesture(magnify.simultaneously(with: pan))
            .onTapGesture(count: 2) {
                withAnimation(.snappy) {
                    if scale > 1 { reset() } else { scale = 2.5; committedScale = 2.5 }
                }
            }
            .overlay(alignment: .topTrailing) {
                Button("Schließen", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .padding()
            }
            .statusBarHidden()
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { scale = max(1, committedScale * $0.magnification) }
            .onEnded { _ in
                committedScale = scale
                if scale <= 1 { withAnimation(.snappy) { reset() } }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(width: committedOffset.width + value.translation.width,
                                    height: committedOffset.height + value.translation.height)
                } else {
                    // Not zoomed: drag down to dismiss.
                    offset = CGSize(width: 0, height: max(0, value.translation.height))
                }
            }
            .onEnded { value in
                if scale <= 1 {
                    if value.translation.height > 120 { dismiss() } else { withAnimation(.snappy) { offset = .zero } }
                } else {
                    committedOffset = offset
                }
            }
    }

    private func reset() {
        scale = 1
        committedScale = 1
        offset = .zero
        committedOffset = .zero
    }
}
#endif
