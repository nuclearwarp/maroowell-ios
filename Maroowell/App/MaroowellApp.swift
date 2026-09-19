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
                VStack(spacing: 18) {
                    MaroowellMark(size: 86)
                    ProgressView()
                        .controlSize(.large)
                    Text("마루웰을 준비하고 있어요")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
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
