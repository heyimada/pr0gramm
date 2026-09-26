import SwiftUI

struct LoginView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var password = ""
    @State private var captchaText = ""
    @State private var captcha: Captcha?
    @State private var isLoading = false
    @State private var error: Error?

    private var canSubmit: Bool {
        !name.isEmpty && !password.isEmpty && !captchaText.isEmpty && captcha != nil && !isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Pr0Logo(size: 56)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Benutzername", text: $name)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Passwort", text: $password)
                        .textContentType(.password)
                }

                Section {
                    Button {
                        Task { await loadCaptcha() }
                    } label: {
                        Group {
                            if let data = captcha?.imageData, let image = UIImage(data: data) {
                                Image(uiImage: image).resizable().scaledToFit()
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 60, maxHeight: 90)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Captcha-Bild, tippen für ein neues")
                    TextField("Captcha", text: $captchaText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit(submit)
                } header: {
                    Text("Captcha")
                } footer: {
                    Text("Tippe auf das Bild für ein neues Captcha.")
                }

                if let error {
                    Section {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Color.pr0Orange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.pr0Background)
            .navigationTitle("Anmelden")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Anmelden", role: .confirm, action: submit).disabled(!canSubmit)
                    }
                }
            }
            .task { await loadCaptcha() }
        }
    }

    private func loadCaptcha() async {
        captcha = nil
        captchaText = ""
        do {
            captcha = try await session.captcha()
        } catch {
            self.error = error
        }
    }

    private func submit() {
        guard canSubmit, let captcha else { return }
        isLoading = true
        error = nil
        Task {
            defer { isLoading = false }
            do {
                try await session.login(name: name, password: password, captcha: captchaText, token: captcha.token)
                dismiss()
            } catch {
                self.error = error
                await loadCaptcha()
            }
        }
    }
}
