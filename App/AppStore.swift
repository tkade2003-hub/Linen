import Foundation
import SwiftUI

final class AppStore: ObservableObject {
    @Published var session: Session? = nil
    @Published var workspace: Workspace = .homeowner
    @Published var proStatus: ProStatus = .none
    @Published var signInPath: Workspace = .homeowner
    @Published var isOnline: Bool = true

    func signIn(email: String, path: Workspace) {
        session = Session(profileId: UUID(), name: "Sarah Jenkins", email: email)
        signInPath = path
        if path == .pro {
            // Pro access stays gated until verification clears.
            // Stage 1 demo: a returning verified pro lands in the Pro workspace.
            proStatus = .verified
            workspace = .pro
        } else {
            workspace = .homeowner
        }
    }

    func applyForPro() {
        proStatus = .pending
    }

    func switchWorkspace(to next: Workspace) {
        workspace = next
    }

    func signOut() {
        session = nil
        workspace = .homeowner
    }
}
