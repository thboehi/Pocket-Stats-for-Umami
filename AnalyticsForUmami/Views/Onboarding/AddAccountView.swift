import SwiftUI

struct AddAccountView: View {
    enum ServerKind: Hashable {
        case selfHosted, cloud, share
    }

    private enum Field: Hashable {
        case server, username, password, apiKey, shareLink
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var kind = ServerKind.selfHosted
    @State private var serverAddress = ""
    @State private var username = ""
    @State private var password = ""
    @State private var apiKey = ""
    @State private var shareLink = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private var canSubmit: Bool {
        guard !isSigningIn else { return false }
        return switch kind {
        case .selfHosted: !serverAddress.trimmingCharacters(in: .whitespaces).isEmpty && !username.isEmpty && !password.isEmpty
        case .cloud: !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
        case .share: !shareLink.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Server type", selection: $kind) {
                        Text("Self-hosted").tag(ServerKind.selfHosted)
                        Text("Umami Cloud").tag(ServerKind.cloud)
                        Text("Share link").tag(ServerKind.share)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                switch kind {
                case .selfHosted: selfHostedFields
                case .cloud: cloudFields
                case .share: shareFields
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Connect to Umami")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isSigningIn)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSigningIn {
                        ProgressView()
                    } else {
                        Button("Sign In", action: signIn)
                            .disabled(!canSubmit)
                    }
                }
            }
            #if DEBUG
            .task { if DebugLaunch.screen == "share" { kind = .share } }
            #endif
            .onAppear { focusedField = firstField }
            .onChange(of: kind) {
                errorMessage = nil
                focusedField = firstField
            }
        }
        .interactiveDismissDisabled(isSigningIn)
    }

    @ViewBuilder
    private var selfHostedFields: some View {
        Section {
            TextField("umami.example.com", text: $serverAddress)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .server)
                .submitLabel(.next)
                .onSubmit { focusedField = .username }
        } header: {
            Text("Server address")
        } footer: {
            Text("The address you use to open Umami in your browser.")
        }

        Section {
            TextField("Username", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .username)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
            SecureField("Password", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { if canSubmit { signIn() } }
        } header: {
            Text("Account")
        } footer: {
            Text("Your password is stored in the Keychain and is only ever sent to your server.")
        }
    }

    @ViewBuilder
    private var cloudFields: some View {
        Section {
            SecureField("API key", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .apiKey)
                .submitLabel(.go)
                .onSubmit { if canSubmit { signIn() } }
        } header: {
            Text("Umami Cloud")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Create an API key in Umami Cloud under Settings › API keys.")
                Link("How to get an API key", destination: URL(string: "https://umami.is/docs/cloud/api-key")!)
            }
        }
    }

    @ViewBuilder
    private var shareFields: some View {
        Section {
            TextField(text: $shareLink, prompt: Text(verbatim: "https://umami.example.com/share/…")) {
                Text("Share link")
            }
            .keyboardType(.URL)
            .textContentType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .shareLink)
            .submitLabel(.go)
            .onSubmit { if canSubmit { signIn() } }
            if shareLink.isEmpty {
                PasteButton(payloadType: URL.self) { urls in
                    if let url = urls.first { shareLink = url.absoluteString }
                }
                .labelStyle(.titleAndIcon)
            }
        } header: {
            Text("Share link")
        } footer: {
            Text("Follow a single website without an account, read-only. In Umami, open the website’s settings and turn on Share URL.")
        }
    }

    private var firstField: Field {
        switch kind {
        case .selfHosted: .server
        case .cloud: .apiKey
        case .share: .shareLink
        }
    }

    private func signIn() {
        focusedField = nil
        errorMessage = nil
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                switch kind {
                case .selfHosted: try await model.signIn(serverAddress: serverAddress, username: username, password: password)
                case .cloud: try await model.signIn(apiKey: apiKey)
                case .share: try await model.signIn(shareLink: shareLink)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    AddAccountView()
        .environment(AppModel())
}
