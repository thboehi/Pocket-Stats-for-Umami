import SwiftUI

extension View {
    /// Asks the user to type the website name before deleting it: deletion
    /// removes all its statistics and cannot be undone.
    func deleteWebsiteAlert(_ website: Binding<Website?>, onDeleted: @escaping (Website) -> Void = { _ in }) -> some View {
        modifier(DeleteWebsiteAlert(website: website, onDeleted: onDeleted))
    }
}

private struct DeleteWebsiteAlert: ViewModifier {
    @Binding var website: Website?
    let onDeleted: (Website) -> Void

    @Environment(WebsitesModel.self) private var websites
    @State private var confirmation = ""
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .alert(
                Text("Delete “\(website?.name ?? "")”?"),
                isPresented: Binding(get: { website != nil }, set: { if !$0 { website = nil } }),
                presenting: website
            ) { website in
                TextField(website.name, text: $confirmation)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Delete", role: .destructive) { delete(website) }
                    .disabled(confirmation.trimmingCharacters(in: .whitespaces) != website.name)
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("The website and all its statistics will be permanently deleted. Type its name to confirm.")
            }
            .alert(
                "Couldn’t delete the website",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: website) { confirmation = "" }
    }

    private func delete(_ website: Website) {
        Task {
            do {
                try await websites.delete(website)
                onDeleted(website)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
