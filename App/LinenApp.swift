import SwiftUI

@main
struct LinenApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        if store.session == nil {
            OnboardingView()
        } else if store.workspace == .pro && store.proStatus != .verified {
            ProGateView()
        } else if store.workspace == .pro {
            ProShellView()
        } else {
            HomeownerShellView()
        }
    }
}
