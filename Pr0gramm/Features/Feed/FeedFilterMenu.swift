import SwiftUI

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
