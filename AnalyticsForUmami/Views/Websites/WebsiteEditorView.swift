import SwiftUI

struct WebsiteEditorView: View {
    enum Mode {
        case create
        case edit(Website)
    }

    let mode: Mode
    var onCreate: (Website) -> Void = { _ in }

    @Environment(WebsitesModel.self) private var websites
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var domain: String
    @State private var teamID: String?
    @State private var teams: [TeamSummary] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    init(mode: Mode, onCreate: @escaping (Website) -> Void = { _ in }) {
        self.mode = mode
        self.onCreate = onCreate
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _domain = State(initialValue: "")
        case .edit(let website):
            _name = State(initialValue: website.name)
            _domain = State(initialValue: website.domain ?? "")
        }
    }

    private var isCreating: Bool {
        if case .create = mode { true } else { false }
    }

    private var normalizedDomain: String {
        var value = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = value.range(of: "://") { value = String(value[range.upperBound...]) }
        if let slash = value.firstIndex(of: "/") { value = String(value[..<slash]) }
        return value
    }

    private var canSave: Bool {
        !isSaving && !name.trimmingCharacters(in: .whitespaces).isEmpty && !normalizedDomain.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .focused($isNameFocused)
                    TextField("example.com", text: $domain)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("The name is only shown in Umami. The domain is the address of the website, without https://.")
                }

                if isCreating && !teams.isEmpty {
                    Section {
                        Picker("Owner", selection: $teamID) {
                            Text("Me").tag(String?.none)
                            ForEach(teams, id: \.id) { team in
                                Text(team.name).tag(Optional(team.id))
                            }
                        }
                    } footer: {
                        Text("Websites owned by a team are visible to all its members.")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isCreating ? "New website" : "Edit website")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(isCreating ? "Add" : "Save", action: save)
                            .disabled(!canSave)
                    }
                }
            }
            .task {
                if isCreating {
                    isNameFocused = true
                    teams = (try? await websites.service.teams()) ?? []
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        let name = name.trimmingCharacters(in: .whitespaces)
        let domain = normalizedDomain
        Task {
            defer { isSaving = false }
            do {
                switch mode {
                case .create:
                    let website = try await websites.create(name: name, domain: domain, teamID: teamID)
                    dismiss()
                    onCreate(website)
                case .edit(let website):
                    try await websites.update(website, name: name, domain: domain)
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
