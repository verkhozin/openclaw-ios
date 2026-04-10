import SwiftUI

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onCreate: ((Project) -> Void)?

    @State private var name = ""
    @State private var desc = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project name", text: $name)
                        .font(.system(.body, weight: .medium))

                    ZStack(alignment: .topLeading) {
                        if desc.isEmpty {
                            Text("Description (optional)")
                                .foregroundColor(Theme.textMuted)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $desc)
                            .frame(minHeight: 60)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.system(.caption))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createProject() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func createProject() {
        isSaving = true
        errorMessage = nil

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let slug = Self.slugify(trimmed)

        guard !slug.isEmpty else {
            errorMessage = "Invalid project name"
            isSaving = false
            return
        }

        guard let service = makeProjectService() else {
            errorMessage = "Not connected to gateway"
            isSaving = false
            return
        }

        Task {
            do {
                let project = try await service.createProject(
                    id: slug,
                    name: trimmed,
                    description: desc
                )
                await EntityIndex.shared.reindex(type: .project)
                await MainActor.run {
                    onCreate?(project)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }

    private func makeProjectService() -> ProjectService? {
        guard let gwURL = GatewayService.shared.gatewayURL,
              let token = GatewayService.shared.authToken else { return nil }
        let host = gwURL.host ?? "localhost"
        let scheme = (gwURL.scheme == "wss") ? "https" : "http"
        let port = gwURL.port ?? 18789
        guard let baseURL = URL(string: "\(scheme)://\(host):\(port)") else { return nil }
        return ProjectService(gatewayBaseURL: baseURL, token: token)
    }

    /// Convert project name to URL-safe slug: "Landing Redesign" → "landing-redesign"
    static func slugify(_ name: String) -> String {
        name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}
