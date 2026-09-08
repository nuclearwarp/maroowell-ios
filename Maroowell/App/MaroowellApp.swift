import SwiftUI

@main
struct MaroowellApp: App {
    @StateObject private var sessionViewModel = SessionViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionViewModel)
                .tint(MaroowellTheme.yellow)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel

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
    }
}
