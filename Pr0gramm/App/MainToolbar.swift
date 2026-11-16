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

struct FilterMenu<Label: View>: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    @Environment(FeedLibrary.self) private var library
    @ViewBuilder let label: Label

    var body: some View {
        Menu {
            if session.isLoggedIn {
                ForEach(ContentFlags.filters, id: \.title) { filter in
                    Toggle(filter.title, isOn: session.filterBinding(filter.flag))
                }
            } else {
                Section("Ohne Anmeldung gibt es nur SFW.") {
                    Button("Anmelden", systemImage: "person.crop.circle") { app.showsLogin = true }
                }
            }
            if library.hasProtectedFeeds {
                Section {
                    ProtectedFeedsButton()
                }
            }
        } label: {
            label.accessibilityLabel("Filter")
        }
        .menuActionDismissBehavior(.disabled)
    }
}

struct ProtectedFeedsButton: View {
    @Environment(FeedLibrary.self) private var library

    var body: some View {
        if library.protectedFeedsUnlocked {
            Button("Geschützte Feeds sperren", systemImage: "lock") { library.lockProtectedFeeds() }
        } else {
            Button("Geschützte Feeds entsperren", systemImage: "lock.open") {
                Task { await library.unlockProtectedFeeds() }
            }
        }
    }
}

struct AccountItem: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app
    @State private var confirmsLogout = false

    var body: some View {
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
