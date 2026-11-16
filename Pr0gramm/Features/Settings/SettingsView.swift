import SwiftUI

struct SettingsView: View {
    @Environment(Session.self) private var session
    @Environment(DownloadStore.self) private var downloads
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDeleteAll = false

    var body: some View {
        @Bindable var session = session
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        NavigationSettingsView()
                    } label: {
                        Label("Navigation", systemImage: "dock.rectangle")
                    }
                    NavigationLink {
                        FeedSettingsView()
                    } label: {
                        LabeledContent {
                            Text(app.title(for: app.defaultSource(for: session.flags)))
                        } label: {
                            Label("Feeds", systemImage: "square.stack")
                        }
                    }
                }

                Section {
                    ForEach(ContentFlags.filters, id: \.title) { filter in
                        Toggle(isOn: session.filterBinding(filter.flag)) {
                            Text(filter.title)
                            Text(filter.subtitle)
                        }
                    }
                    Toggle(isOn: $session.resetsFlagsOnLaunch) {
                        Text("Beim Start auf SFW zurücksetzen")
                        Text("Nach jedem Neustart der App ist nur SFW an")
                    }
                } header: {
                    Text("Filter")
                } footer: {
                    if !session.isLoggedIn {
                        Text("Ohne Anmeldung zeigt pr0gramm nur SFW-Inhalte.")
                    }
                }
                .disabled(!session.isLoggedIn)

                Section("Videos") {
                    Toggle("Automatisch abspielen", isOn: $session.autoplayVideos)
                    Toggle("Stumm starten", isOn: $session.startMuted)
                }

                Section("Downloads") {
                    LabeledContent("Belegt", value: ByteCountFormatter.string(fromByteCount: downloads.totalBytes, countStyle: .file))
                    Button("Alle Downloads löschen", role: .destructive) { confirmsDeleteAll = true }
                        .disabled(downloads.downloads.isEmpty)
                }

                Section {
                    Button("Bild-Cache leeren") { URLCache.shared.removeAllCachedResponses() }
                } footer: {
                    Text("Inoffizieller Client. Nicht mit pr0gramm.com verbunden.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pr0Background)
            .navigationTitle("Einstellungen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig", role: .confirm) { dismiss() }
                }
            }
            .confirmationDialog("Alle Downloads löschen?", isPresented: $confirmsDeleteAll, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { downloads.deleteAll() }
            }
        }
    }
}
