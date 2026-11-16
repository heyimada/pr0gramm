import SwiftUI

extension View {
    /// The login sheet and the vote and download alerts. Attached at the root and inside sheets
    /// that can vote or download, because a sheet or alert can't present from beneath a sheet.
    func appPresentations() -> some View {
        modifier(AppPresentations())
    }
}

private struct AppPresentations: ViewModifier {
    @Environment(AppState.self) private var app
    @Environment(DownloadStore.self) private var downloads

    func body(content: Content) -> some View {
        @Bindable var app = app
        content
            .sheet(isPresented: $app.showsLogin) { LoginView() }
            .alert(
                "Abstimmen fehlgeschlagen",
                isPresented: Binding(get: { app.voteFailure != nil }, set: { if !$0 { app.voteFailure = nil } })
            ) {
                Button("OK") {}
            } message: {
                Text(app.voteFailure?.localizedDescription ?? "")
            }
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
