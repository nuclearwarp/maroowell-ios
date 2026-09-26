import SwiftUI

@main
struct MaroowellApp: App {
    @UIApplicationDelegateAdaptor(MaroowellAppDelegate.self) private var appDelegate
    @StateObject private var sessionViewModel = SessionViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionViewModel)
                .tint(MaroowellTheme.primary)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            MaroowellTheme.background
                .ignoresSafeArea()

            if sessionViewModel.isBootstrapping {
                ZStack {
                    Color.white
                        .ignoresSafeArea()

                    Image("MaroowellLoginLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 242, maxHeight: 218)
                        .accessibilityLabel("마루웰")
                }
            } else if let session = sessionViewModel.session {
                HomeView(session: session)
            } else {
                LoginView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, sessionViewModel.session != nil else { return }
            Task { await PushManager.shared.resyncCurrentDevice() }
        }
    }
}
