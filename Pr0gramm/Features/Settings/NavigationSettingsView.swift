import SwiftUI

/// Choose and order the tabs in the tab bar.
struct NavigationSettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var hidden: [AppTab] {
        AppTab.allCases.filter { !app.tabOrder.contains($0) }
    }

    private var isFull: Bool {
        sizeClass == .compact && app.tabOrder.count >= AppTab.compactLimit
    }

    var body: some View {
        @Bindable var app = app
        List {
            Section {
                // Distinct identities per section: sharing the tab id would make SwiftUI reuse the
                // "Weitere" button row after adding, which then has no delete or move handle.
                ForEach(app.tabOrder, id: \.shownID) { tab in
                    row(tab)
                }
                .onMove { app.tabOrder.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { offsets in
                    guard app.tabOrder.count > offsets.count else { return }
                    app.tabOrder.remove(atOffsets: offsets)
                }
            } header: {
                Text("In der Leiste")
            } footer: {
                if sizeClass == .compact {
                    Text("Auf dem iPhone passen höchstens \(AppTab.compactLimit) Einträge in die Leiste. Abos erscheint nur, wenn du angemeldet bist.")
                }
            }

            if !hidden.isEmpty {
                Section("Weitere") {
                    ForEach(hidden, id: \.hiddenID) { tab in
                        Button {
                            withAnimation { app.tabOrder.append(tab) }
                        } label: {
                            HStack {
                                row(tab)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(isFull ? Color.secondary : Color.upvoteGreen)
                                    .font(.title3)
                            }
                        }
                        .disabled(isFull)
                    }
                }
            }

            Section {
                Button("Zurücksetzen") { withAnimation { app.tabOrder = AppTab.defaultOrder } }
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(Color.pr0Background)
        .navigationTitle("Navigation")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func row(_ tab: AppTab) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title).foregroundStyle(Color.pr0Text)
                Text(tab.summary).font(.caption).foregroundStyle(Color.pr0Secondary)
            }
        } icon: {
            Image(systemName: tab.symbol).foregroundStyle(Color.pr0Orange)
        }
    }
}

private extension AppTab {
    var shownID: String { "shown-\(rawValue)" }
    var hiddenID: String { "hidden-\(rawValue)" }
}
