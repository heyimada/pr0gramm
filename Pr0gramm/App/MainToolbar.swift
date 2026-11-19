import SwiftUI

struct MainToolbar: ToolbarContent {
    var body: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            Wordmark()
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                FilterMenu { BarCircle { Image(systemName: "line.3.horizontal.decrease") } }
                AccountItem()
            }
        }
        .sharedBackgroundVisibility(.hidden)
        #else
        ToolbarItem(placement: .primaryAction) {
            FilterMenu { BarCircle { Image(systemName: "line.3.horizontal.decrease") } }
        }
        ToolbarItem(placement: .primaryAction) { AccountItem() }
        #endif
    }
}

/// Opens the Profil tab when it is in the tab bar, which carries login, settings and logout.
/// Otherwise a menu with those.
struct AccountItem: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    @State private var confirmsLogout = false

    var body: some View {
        // A menu in both cases: on the iPhone Duo a plain button beside the filter menu pushes the
        // pair out of the navigation bar.
        if app.visibleTabs(isLoggedIn: session.isLoggedIn).contains(.profile) {
            Menu {
                Button("Einstellungen", systemImage: "gearshape") { app.tab = .profile }
            } label: {
                label
            } primaryAction: {
                app.tab = .profile
            }
        } else {
            menu
        }
    }

    @ViewBuilder
    private var label: some View {
        if let name = session.userName {
            Avatar(name: name, size: 34)
                .overlay(Circle().strokeBorder(Color.pr0Orange, lineWidth: 1.5))
                .accessibilityLabel("Profil von \(name)")
        } else {
            BarCircle { Image(systemName: "person") }
                .accessibilityLabel("Konto")
        }
    }

    @ViewBuilder
    private var menu: some View {
        if let name = session.userName {
            Menu {
                Section {
                    Button("Mein Profil", systemImage: "person") { app.router.push(.user(name)) }
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
                label
            }
            .confirmationDialog("Wirklich abmelden?", isPresented: $confirmsLogout, titleVisibility: .visible) {
                Button("Abmelden", role: .destructive) { Task { await session.logout() } }
            }
        } else {
            Menu {
                Button("Anmelden", systemImage: "person.crop.circle") { app.showsLogin = true }
                Button("Einstellungen", systemImage: "gearshape") { app.showsSettings = true }
            } label: {
                label
            }
        }
    }
}

/// The pr0gramm logo, without the name beside it.
struct Wordmark: View {
    var body: some View {
        Pr0Logo(size: 28)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("pr0gramm")
    }
}

/// A plain toolbar icon with a round hit area, drawn without the system's glass capsule.
struct BarCircle<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.pr0Text)
            .frame(width: 34, height: 34)
            .contentShape(.circle)
    }
}
