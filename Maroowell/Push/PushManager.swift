import FirebaseCore
import FirebaseMessaging
import Foundation
import SwiftUI
import UIKit
import UserNotifications

final class MaroowellAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        Task { await PushManager.shared.resyncCurrentDevice() }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { await PushManager.shared.recordRegistrationFailure(error) }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        Task { await PushManager.shared.receiveFCMToken(fcmToken) }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let noticeID = userInfo["notice_id"] as? String, !noticeID.isEmpty {
            NotificationCenter.default.post(
                name: .maroowellPushOpened,
                object: nil,
                userInfo: ["notice_id": noticeID]
            )
        }
    }
}

@MainActor
final class PushManager: ObservableObject {
    static let shared = PushManager()

    @Published private(set) var currentToken: String?
    @Published private(set) var notificationEnabled = false
    @Published private(set) var lastSyncError: String?

    private let tokenKey = "maroowell_ios_fcm_token"
    private var syncing = false

    private init() {
        currentToken = UserDefaults.standard.string(forKey: tokenKey)
    }

    func sessionBecameAvailable() async {
        await requestPermissionAndRegisterIfNeeded()
        await refreshTokenAndSync()
    }

    func resyncCurrentDevice() async {
        guard (try? await SupabaseService.shared.client.auth.session) != nil else { return }
        await refreshAuthorizationState()
        UIApplication.shared.registerForRemoteNotifications()
        await refreshTokenAndSync()
    }

    func receiveFCMToken(_ token: String) async {
        currentToken = token
        UserDefaults.standard.set(token, forKey: tokenKey)
        await sync(token: token, action: "register")
    }

    func unregisterCurrentDevice() async {
        guard let token = currentToken ?? UserDefaults.standard.string(forKey: tokenKey) else { return }
        await sync(token: token, action: "unregister")
    }

    func recordRegistrationFailure(_ error: Error) {
        lastSyncError = "APNs 등록 실패: \(error.localizedDescription)"
    }

    private func requestPermissionAndRegisterIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        await refreshAuthorizationState()
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func refreshAuthorizationState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationEnabled = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
    }

    private func refreshTokenAndSync() async {
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().token { [weak self] token, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastSyncError = "FCM 토큰 조회 실패: \(error.localizedDescription)"
                    return
                }
                guard let token, !token.isEmpty else { return }
                await self.receiveFCMToken(token)
            }
        }
    }

    private func sync(token: String, action: String) async {
        guard !syncing || action == "unregister" else { return }
        syncing = true
        defer { syncing = false }

        do {
            let auth = try await SupabaseService.shared.client.auth.session
            await refreshAuthorizationState()

            let endpoint = AppConfig.supabaseURL.appendingPathComponent("functions/v1/app-push-register")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")

            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            let deviceID = UIDevice.current.identifierForVendor?.uuidString

            var payload: [String: Any] = [
                "action": action,
                "platform": "ios",
                "fcm_token": token,
                "app_version": version
            ]
            if let deviceID { payload["device_id"] = deviceID }
            if action == "register" {
                payload["notification_enabled"] = notificationEnabled
                payload["notice_channel_enabled"] = notificationEnabled
                payload["emergency_channel_enabled"] = notificationEnabled
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(status) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw NSError(
                    domain: "MaroowellPush",
                    code: status,
                    userInfo: [NSLocalizedDescriptionKey: "PUSH 기기 등록 실패 (\(status)): \(body.prefix(160))"]
                )
            }
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }
}

extension Notification.Name {
    static let maroowellPushOpened = Notification.Name("maroowell.push.opened")
}

