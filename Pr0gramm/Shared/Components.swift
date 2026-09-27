import SwiftUI

/// The orange `>_` terminal logo.
struct Pr0Logo: View {
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.08)
            .fill(Color.pr0Orange)
            .overlay { PromptShape().stroke(.white, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .square)) }
            .frame(width: size, height: size)
            .accessibilityLabel("pr0gramm")
    }

    private nonisolated struct PromptShape: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.27))
                path.addLine(to: CGPoint(x: rect.width * 0.46, y: rect.height * 0.5))
                path.addLine(to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.73))
                path.move(to: CGPoint(x: rect.width * 0.54, y: rect.height * 0.73))
                path.addLine(to: CGPoint(x: rect.width * 0.8, y: rect.height * 0.73))
            }
        }
    }
}

/// Round initials avatar, e.g. "MU" for MUSE or "Cu" for Cumarin.
struct Avatar: View {
    let name: String
    var size: CGFloat = 24

    private var initials: String {
        guard let first = name.first else { return "?" }
        return first.uppercased() + name.dropFirst().prefix(1)
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(Color.pr0Text)
            .frame(width: size, height: size)
            .background(Color.avatar(for: name), in: .circle)
            .accessibilityHidden(true)
    }
}

/// Small dot in the user's rank color.
struct MarkDot: View {
    let mark: Int
    var size: CGFloat = 8

    var body: some View {
        Circle().fill(Color.mark(mark)).frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct OPBadge: View {
    var body: some View {
        Text("OP")
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(Color.pr0Orange)
    }
}

/// Benis, or a crossed-out eye while the score is still hidden.
struct ScoreView: View {
    let score: Int
    let created: Date

    var body: some View {
        if created.isScoreHidden {
            Image(systemName: "eye.slash")
                .accessibilityLabel("Benis noch nicht sichtbar")
        } else {
            Text(score, format: .number)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}

/// Circled ⊕ / ⊖ buttons. Guests are asked to log in instead.
struct VoteButtons: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    let target: VoteTarget
    let id: Int
    var size: CGFloat = 20
    var axis: Axis = .vertical

    @State private var failed = false

    var body: some View {
        let vote = session.vote(for: target, id: id)
        let layout = axis == .vertical
            ? AnyLayout(VStackLayout(spacing: size * 0.3))
            : AnyLayout(HStackLayout(spacing: size * 0.4))
        layout {
            button(value: 1, current: vote, symbol: "plus.circle", label: "Plus")
            button(value: -1, current: vote, symbol: "minus.circle", label: "Minus")
        }
        .alert("Abstimmen fehlgeschlagen", isPresented: $failed) {}
    }

    private func button(value: Int, current: Int, symbol: String, label: String) -> some View {
        let active = current == value
        return Button {
            guard session.isLoggedIn else { return app.showsLogin = true }
            Task {
                do { try await session.vote(target, id: id, value: active ? 0 : value) } catch { failed = true }
            }
        } label: {
            Image(systemName: active ? "\(symbol).fill" : symbol)
                .resizable()
                .fontWeight(.light)
                .frame(width: size, height: size)
                .foregroundStyle(active ? Color.pr0Orange : Color.pr0Secondary)
                .contentShape(.rect.inset(by: -6))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: active)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// Glass capsule segmented control, e.g. "beliebt · neu · müll" above a tag feed.
struct SegmentCapsule<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    @Namespace private var namespace

    var body: some View {
        // Scrolls sideways once saved feeds no longer fit next to the streams.
        ViewThatFits(in: .horizontal) {
            segments
            ScrollViewReader { proxy in
                ScrollView(.horizontal) { segments }
                    .scrollIndicators(.hidden)
                    .clipShape(.capsule)
                    .onAppear { proxy.scrollTo(selection, anchor: .center) }
                    .onChange(of: selection) { withAnimation { proxy.scrollTo(selection, anchor: .center) } }
            }
        }
        #if os(visionOS)
        .glassBackgroundEffect(in: .capsule)
        #else
        .glassEffect(.regular, in: .capsule)
        #endif
    }

    private var segments: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isOn = option == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(isOn ? .semibold : .regular))
                        .foregroundStyle(isOn ? Color.pr0Text : Color.pr0Secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            if isOn {
                                Capsule().fill(.white.opacity(0.14))
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .id(option)
            }
        }
        .padding(4)
        .fixedSize()
    }
}

extension View {
    /// Section heading with a trailing hairline, like "Hochlads ───".
    func pr0SectionHeader() -> some View {
        HStack(spacing: 10) {
            self.font(.footnote).foregroundStyle(Color.pr0Secondary)
            Rectangle().fill(Color.pr0Secondary.opacity(0.4)).frame(height: 1)
        }
    }
}

/// Full-screen error state with a retry button.
struct ErrorView: View {
    let error: Error
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.title)
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.pr0Secondary)
            Button("Erneut versuchen") { Task { await retry() } }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
