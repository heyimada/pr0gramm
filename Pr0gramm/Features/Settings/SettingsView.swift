import SwiftUI

struct SettingsView: View {
    @Environment(Session.self) private var session
    @Environment(PlaybackSettings.self) private var playback
    @Environment(DownloadStore.self) private var downloads
    @Environment(FeedLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDeleteAll = false

    var body: some View {
        @Bindable var session = session
        @Bindable var playback = playback
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
                            Text(library.title(for: library.effectiveDefaultSource))
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
                    Toggle("Automatisch abspielen", isOn: $playback.autoplayVideos)
                    Toggle("Stumm starten", isOn: $playback.startMuted)
                }

                Section {
                    Toggle(isOn: $playback.reelsShowWhole.animation()) {
                        Text("Ganz anzeigen")
                        Text("Mit Rändern statt beschnitten. Aufziehen füllt den Bildschirm, zusammenziehen zeigt wieder alles.")
                    }
                    if playback.reelsShowWhole {
                        LabeledContent("Trotzdem füllen bis") {
                            Text("\(Int((playback.reelsFillTolerance * 100).rounded())) % beschnitten").monospacedDigit()
                        }
                        Slider(value: $playback.reelsFillTolerance, in: PlaybackSettings.fillToleranceRange, step: 0.01)
                    }
                } header: {
                    Text("Reels")
                } footer: {
                    Text("Passt ein Post fast genau auf den Bildschirm, füllt er ihn trotzdem, solange höchstens so viel abgeschnitten wird.")
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
            .pr0FormBackground()
            .inlineNavigationTitle("Einstellungen")
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
