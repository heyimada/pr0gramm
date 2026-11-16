import SwiftUI

extension View {
    /// Vote and download failures. Attached at the root and inside sheets that can vote or
    /// download, because an alert can't present from beneath a sheet.
    func appAlerts() -> some View {
        modifier(AppAlerts())
    }
}

private struct AppAlerts: ViewModifier {
    @Environment(AppState.self) private var app
    @Environment(DownloadStore.self) private var downloads

    func body(content: Content) -> some View {
        @Bindable var app = app
        content
            .alert("Abstimmen fehlgeschlagen", isPresented: $app.showsVoteFailure) {}
            .alert(
                downloads.failure?.title ?? "",
                isPresented: Binding(get: { downloads.failure != nil }, set: { if !$0 { downloads.dismissFailure() } })
            ) {
                Button("OK") {}
            } message: {
                Text(downloads.failure?.message ?? "")
            }
    }
}
