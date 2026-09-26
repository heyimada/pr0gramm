import SwiftUI

/// Sheet for writing a comment, or a reply when `replyingTo` is set.
struct CommentComposer: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    let itemId: Int
    let parentId: Int
    let replyingTo: String?
    /// Called with the item's updated comment list after posting.
    let onPosted: ([Comment]?) -> Void

    @State private var text = ""
    @State private var isSending = false
    @State private var error: Error?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Kommentieren…", text: $text, axis: .vertical)
                        .lineLimit(5...15)
                        .focused($focused)
                } footer: {
                    if let error {
                        Text(error.localizedDescription).foregroundStyle(Color.pr0Orange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pr0Background)
            .navigationTitle(replyingTo.map { "Antwort an \($0)" } ?? "Kommentar")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("Abschicken", systemImage: "paperplane.fill", role: .confirm, action: send)
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { focused = true }
    }

    private func send() {
        isSending = true
        Task {
            defer { isSending = false }
            do {
                onPosted(try await session.postComment(itemId: itemId, parentId: parentId, text: text))
                dismiss()
            } catch {
                self.error = error
            }
        }
    }
}
