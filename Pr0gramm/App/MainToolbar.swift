import SwiftUI

/// Toolbar of every tab root: logo on the left, content filter and account on the right.
struct MainToolbar: ToolbarContent {
    var body: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            Wordmark()
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                FilterMenu()
                AccountItem()
            }
        }
        .sharedBackgroundVisibility(.hidden)
        #else
        ToolbarItem(placement: .primaryAction) { FilterMenu() }
        ToolbarItem(placement: .primaryAction) { AccountItem() }
        #endif
    }
}

/// SFW / NSFW / NSFL / POL toggles in a native menu.
struct FilterMenu: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    /// A bare white icon for overlays like the Reels header, instead of the toolbar circle.
    var plain = false

    private let flags: [(ContentFlags, String)] = [
        (.sfw, "SFW"), (.nsfw, "NSFW"), (.nsfl, "NSFL"), (.pol, "POL"),
    ]

    var body: some View {
        Menu {
            if session.isLoggedIn {
                ForEach(flags, id: \.1) { flag, title in
                    Toggle(title, isOn: binding(for: flag))
                }
            } else {
                Section("Ohne Anmeldung gibt es nur SFW.") {
                    Button("Anmelden", systemImage: "person.crop.circle") { app.showsLogin = true }
                }
            }
        } label: {
            Group {
                if plain {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                } else {
                    BarCircle { Image(systemName: "line.3.horizontal.decrease") }
                }
            }
            .accessibilityLabel("Filter")
        }
        .menuActionDismissBehavior(.disabled)
    }

    private func binding(for flag: ContentFlags) -> Binding<Bool> {
        Binding {
            session.flags.contains(flag)
        } set: { isOn in
            if isOn { session.selectedFlags.insert(flag) } else { session.selectedFlags.remove(flag) }
        }
    }
}

/// Avatar menu when logged in, otherwise a login button.
struct AccountItem: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    @State private var confirmsLogout = false

    var body: some View {
        if let name = session.userName {
            Menu {
                Section {
                    Button("Mein Profil", systemImage: "person") { app.open(.user(name)) }
                } header: {
                    if let score = session.userScore {
                        Text("\(name) · \(score.formatted()) Benis")
                    }
                }
                Button("Einstellungen", systemImage: "gearshape") { app.showsSettings = true }
                Button("Abmelden", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    confirmsLogout = true
                }
            } label: {
                Avatar(name: name, size: 34)
                    .overlay(Circle().strokeBorder(Color.pr0Orange, lineWidth: 1.5))
                    .accessibilityLabel(name)
            }
            .confirmationDialog("Wirklich abmelden?", isPresented: $confirmsLogout, titleVisibility: .visible) {
                Button("Abmelden", role: .destructive) { Task { await session.logout() } }
            }
        } else {
            Menu {
                Button("Anmelden", systemImage: "person.crop.circle") { app.showsLogin = true }
                Button("Einstellungen", systemImage: "gearshape") { app.showsSettings = true }
            } label: {
                BarCircle { Image(systemName: "person") }
                    .accessibilityLabel("Konto")
            }
        }
    }
}

/// Logo plus "pr0gramm" wordmark for the leading toolbar slot.
struct Wordmark: View {
    var body: some View {
        HStack(spacing: 8) {
            Pr0Logo(size: 28)
            Text("pr0gramm")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.pr0Text)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("pr0gramm")
    }
}

/// Dark round toolbar button drawn by the app instead of the shared glass capsule.
struct BarCircle<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.pr0Text)
            .frame(width: 34, height: 34)
            .background(Color.pr0Bar, in: .circle)
            .overlay(Circle().strokeBorder(.white.opacity(0.08)))
            .contentShape(.circle)
    }
}
