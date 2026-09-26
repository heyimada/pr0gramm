import SwiftUI

/// Profil tab: your own profile, or a prompt to log in.
struct AccountScreen: View {
    @Environment(Session.self) private var session
    @Environment(AppState.self) private var app

    var body: some View {
        if let name = session.userName {
            ProfileScreen(name: name).id(name)
        } else {
            ContentUnavailableView {
                Label("Nicht angemeldet", systemImage: "person.crop.circle")
            } description: {
                Text("Melde dich an, um abzustimmen, zu kommentieren und NSFW/NSFL zu sehen.")
            } actions: {
                Button("Anmelden") { app.showsLogin = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pr0Background)
        }
    }
}
