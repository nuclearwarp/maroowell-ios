import SwiftUI
import UIKit

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
    @State private var versionGate: AppVersionGateState = .checking

    var body: some View {
        ZStack {
            MaroowellTheme.background
                .ignoresSafeArea()

            switch versionGate {
            case .checking:
                versionCheckingView
            case .required(let policy):
                updateRequiredView(policy)
            case .failed(let message):
                versionFailureView(message)
            case .allowed:
                if sessionViewModel.isBootstrapping {
                    versionCheckingView
                } else if let session = sessionViewModel.session {
                    HomeView(session: session)
                } else {
                    LoginView()
                }
            }
        }
        .task {
            await checkRequiredVersion()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await checkRequiredVersion()
                if case .allowed = versionGate, sessionViewModel.session != nil {
                    await PushManager.shared.resyncCurrentDevice()
                }
            }
        }
    }

    private var versionCheckingView: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 18) {
                Image("MaroowellLoginLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 242, maxHeight: 218)
                    .accessibilityLabel("마루웰")
                ProgressView()
                Text("앱 버전을 확인하는 중입니다.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MaroowellTheme.muted)
            }
        }
    }

    private func updateRequiredView(_ policy: AppMinVersionPolicy) -> some View {
        VStack(spacing: 18) {
            Image("MaroowellLoginLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 130)

            Text("필수 업데이트")
                .font(.title2.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)

            Text(policy.message)
                .font(.subheadline)
                .foregroundStyle(MaroowellTheme.muted)
                .multilineTextAlignment(.center)

            if !policy.minVersion.isEmpty {
                Text("최소 버전 v\(policy.minVersion)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MaroowellTheme.muted)
            }

            Button {
                guard let url = URL(string: policy.storeURL) else { return }
                UIApplication.shared.open(url)
            } label: {
                Text("업데이트")
                    .font(.headline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .frame(maxWidth: 440)
    }

    private func versionFailureView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text("버전 확인 필요")
                .font(.title3.weight(.black))
            Text(message + "\n\n네트워크 연결 후 다시 시도해주세요.")
                .font(.subheadline)
                .foregroundStyle(MaroowellTheme.muted)
                .multilineTextAlignment(.center)
            Button("다시 시도") {
                Task { await checkRequiredVersion() }
            }
            .buttonStyle(.borderedProminent)
            .tint(MaroowellTheme.yellow)
            .foregroundStyle(MaroowellTheme.ink)
        }
        .padding(28)
    }

    @MainActor
    private func checkRequiredVersion() async {
        versionGate = .checking
        do {
            var components = URLComponents(
                url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/app_min_versions"),
                resolvingAgainstBaseURL: false
            )!
            components.queryItems = [
                .init(name: "platform", value: "eq.ios"),
                .init(name: "select", value: "min_build,min_version,store_url,message,is_force_update"),
                .init(name: "limit", value: "1")
            ]

            var request = URLRequest(url: components.url!)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(status) else {
                throw NSError(domain: "VersionGate", code: status, userInfo: [NSLocalizedDescriptionKey: "버전 확인 실패 (\(status))"])
            }

            let rows = try JSONDecoder().decode([AppMinVersionPolicy].self, from: data)
            guard let policy = rows.first else {
                throw NSError(domain: "VersionGate", code: -1, userInfo: [NSLocalizedDescriptionKey: "버전 정책을 확인하지 못했습니다."])
            }

            let currentBuild = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
            if policy.isForceUpdate && currentBuild < policy.minBuild {
                versionGate = .required(policy)
            } else {
                versionGate = .allowed
            }
        } catch {
            versionGate = .failed(error.localizedDescription)
        }
    }
}

private enum AppVersionGateState {
    case checking
    case allowed
    case required(AppMinVersionPolicy)
    case failed(String)
}

private struct AppMinVersionPolicy: Decodable {
    let minBuild: Int
    let minVersion: String
    let storeURL: String
    let message: String
    let isForceUpdate: Bool

    enum CodingKeys: String, CodingKey {
        case minBuild = "min_build"
        case minVersion = "min_version"
        case storeURL = "store_url"
        case message
        case isForceUpdate = "is_force_update"
    }
}
