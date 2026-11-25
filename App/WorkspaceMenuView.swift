import SwiftUI

struct WorkspaceMenuView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Switch workspace") {
                    ForEach(Workspace.allCases, id: \.self) { ws in
                        Button {
                            store.switchWorkspace(to: ws)
                            dismiss()
                        } label: {
                            HStack {
                                Text(ws.rawValue)
                                Spacer()
                                if store.workspace == ws {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
                Section {
                    Label("Profile and saved homes", systemImage: "person")
                    Label("Notifications", systemImage: "bell")
                    Label("Messages", systemImage: "message")
                    Label("Settings and privacy", systemImage: "gearshape")
                    Label("Concierge help", systemImage: "person.wave.2")
                }
                Section {
                    if let s = store.session {
                        Text("Signed in as \(s.name)")
                            .foregroundStyle(.secondary)
                    }
                    Button("Sign out", role: .destructive) { store.signOut() }
                }
            }
            .navigationTitle("Linen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
