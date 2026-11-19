import SwiftUI

/// The Profil tab: your profile and the settings when logged in, a login prompt and the settings
/// when not.
struct AccountScreen: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app

    var body: some View {
        if let name = session.userName {
            ProfileScreen(name: name) {
                // Kept on one page in Book Mode, as on the logged-out screen.
                AccountSettingsList().frame(maxWidth: 560, alignment: .leading)
            }
            .id(name)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nicht angemeldet").font(.title2.bold())
                        Text("Melde dich an, um abzustimmen, zu kommentieren und NSFW/NSFL zu sehen.")
                            .foregroundStyle(Color.pr0Secondary)
                        Button("Anmelden") { app.showsLogin = true }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                    }
                    AccountSettingsList()
                }
                .padding(16)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.pr0Background)
        }
    }
}

/// Settings rows grouped like a system list, sized to sit inside a scrolling profile.
private struct AccountSettingsList: View {
    @Environment(Session.self) private var session
    @Environment(FeedLibrary.self) private var library
    @State private var confirmsLogout = false

    var body: some View {
        VStack(spacing: 0) {
            row("Feeds", symbol: "square.stack", value: library.title(for: library.effectiveDefaultSource)) {
                FeedSettingsView()
            }
            Divider().padding(.leading, 52)
            row("Filter", symbol: "shield", value: session.flags.summary) { FilterSettingsView() }
            Divider().padding(.leading, 52)
            row("Navigation", symbol: "dock.rectangle") { NavigationSettingsView() }
            Divider().padding(.leading, 52)
            row("Einstellungen", symbol: "gearshape") { SettingsForm() }
            if session.isLoggedIn {
                Divider().padding(.leading, 52)
                Button(role: .destructive) { confirmsLogout = true } label: {
                    Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Color.pr0Orange)
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                        .padding(.horizontal, 16)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.pr0Pill, in: .rect(cornerRadius: 22))
        .confirmationDialog("Wirklich abmelden?", isPresented: $confirmsLogout, titleVisibility: .visible) {
            Button("Abmelden", role: .destructive) { Task { await session.logout() } }
        }
    }

    private func row(_ title: String, symbol: String, value: String? = nil,
                     @ViewBuilder destination: @escaping () -> some View) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.pr0Orange)
                    .frame(width: 24)
                Text(title).foregroundStyle(Color.pr0Text)
                Spacer(minLength: 8)
                if let value {
                    Text(value).foregroundStyle(Color.pr0Secondary).lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.pr0Secondary.opacity(0.6))
            }
            .frame(minHeight: 50)
            .padding(.horizontal, 16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
