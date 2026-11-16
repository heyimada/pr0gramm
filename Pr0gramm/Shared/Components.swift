import SwiftUI

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

struct TagCapsule<Content: View>: View {
    var tint: Color?
    @ViewBuilder let content: Content

    var body: some View {
        content
            .font(.subheadline)
            .foregroundStyle(Color.pr0Text)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Color.pr0Pill, in: .capsule)
            .overlay {
                if let tint { Capsule().strokeBorder(tint, lineWidth: 1.5) }
            }
    }
}

extension TagCapsule where Content == Text {
    init(_ text: String, tint: Color? = nil) {
        self.init(tint: tint) { Text(text) }
    }
}

struct SegmentCapsule<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    /// Lets the glass morph into another shape with the same ID, see `CollapsingSegmentCapsule`.
    var glassNamespace: Namespace.ID?
    @Namespace private var namespace

    var body: some View {
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
        .modifier(GlassID(namespace: glassNamespace))
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

private let capsuleGlassID = "capsule"

struct CollapsingSegmentCapsule<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String
    let isCollapsed: Bool
    let collapsedHint: String
    let onExpand: () -> Void
    @Namespace private var glass

    var body: some View {
        #if os(visionOS)
        SegmentCapsule(options: options, selection: $selection, title: title)
        #else
        GlassEffectContainer {
            if isCollapsed {
                Button(action: onExpand) {
                    HStack(spacing: 5) {
                        Text(title(selection)).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.pr0Text)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .glassEffectID(capsuleGlassID, in: glass)
                .accessibilityLabel("\(title(selection)), \(collapsedHint)")
            } else {
                SegmentCapsule(options: options, selection: $selection, title: title, glassNamespace: glass)
            }
        }
        #endif
    }
}

#if !os(visionOS)
private struct GlassID: ViewModifier {
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.glassEffectID(capsuleGlassID, in: namespace)
        } else {
            content
        }
    }
}
#endif

extension View {
    func pr0SectionHeader() -> some View {
        HStack(spacing: 10) {
            self.font(.footnote).foregroundStyle(Color.pr0Secondary)
            Rectangle().fill(Color.pr0Secondary.opacity(0.4)).frame(height: 1)
        }
    }
}

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

struct RemoteImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary)
            default:
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ActionPillLabel: View {
    let title: String
    let symbol: String
    var tint: Color = .pr0Text

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Color.pr0Pill, in: .capsule)
            .contentShape(.capsule)
    }
}

extension View {
    func glassCircle() -> some View {
        #if os(visionOS)
        glassBackgroundEffect(in: .circle)
        #else
        glassEffect(.regular, in: .circle)
        #endif
    }

    func glassCapsule() -> some View {
        #if os(visionOS)
        glassBackgroundEffect(in: .capsule)
        #else
        glassEffect(.regular, in: .capsule)
        #endif
    }
}

extension View {
    func inlineNavigationTitle(_ title: String) -> some View {
        #if os(iOS)
        navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        #else
        navigationTitle(title)
        #endif
    }

    func pr0FormBackground() -> some View {
        scrollContentBackground(.hidden).background(Color.pr0Background)
    }
}
