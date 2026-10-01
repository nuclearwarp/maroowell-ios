import Foundation
import SwiftUI
import UIKit

struct LoginPopupNotice: Identifiable, Decodable, Equatable {
    let id: UUID
    let title: String
    let body: String
    let requireAck: Bool
    let expiresAt: String?
    let popupImageURL: String?
    let popupRevision: Int
    let popupPriority: Int
    let popupAllowDismiss: Bool
    let popupActionLabel: String?
    let popupActionURL: String?
    let popupStartAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case requireAck = "require_ack"
        case expiresAt = "expires_at"
        case popupImageURL = "popup_image_url"
        case popupRevision = "popup_revision"
        case popupPriority = "popup_priority"
        case popupAllowDismiss = "popup_allow_dismiss"
        case popupActionLabel = "popup_action_label"
        case popupActionURL = "popup_action_url"
        case popupStartAt = "popup_start_at"
    }

    var allowsNeverShowAgain: Bool {
        popupAllowDismiss && !requireAck
    }
}

private struct LoginPopupDismissal: Decodable {
    let noticeID: UUID
    let dismissedRevision: Int

    enum CodingKeys: String, CodingKey {
        case noticeID = "notice_id"
        case dismissedRevision = "dismissed_revision"
    }
}

@MainActor
final class LoginPopupNoticeCenter: ObservableObject {
    @Published var currentNotice: LoginPopupNotice?

    private var loadedUserID: UUID?
    private let client = SupabaseService.shared.client

    func clear() {
        currentNotice = nil
        loadedUserID = nil
    }

    func refresh(userID: UUID, force: Bool = false) async {
        if !force, loadedUserID == userID { return }

        do {
            let session = try await client.auth.session
            let token = session.accessToken
            async let notices = fetchNotices(token: token)
            async let dismissals = fetchDismissals(token: token, userID: userID)
            let (noticeRows, dismissalRows) = try await (notices, dismissals)

            let dismissed = Dictionary(
                uniqueKeysWithValues: dismissalRows.map { ($0.noticeID, $0.dismissedRevision) }
            )
            let now = Date()
            currentNotice = noticeRows.first { notice in
                if (dismissed[notice.id] ?? 0) >= max(1, notice.popupRevision) { return false }
                if let start = parseDate(notice.popupStartAt), start > now { return false }
                if let expires = parseDate(notice.expiresAt), expires <= now { return false }
                return true
            }
            loadedUserID = userID
        } catch {
            currentNotice = nil
        }
    }

    func close(
        userID: UUID,
        notice: LoginPopupNotice,
        neverShowAgain: Bool
    ) async {
        if neverShowAgain && notice.allowsNeverShowAgain {
            try? await saveDismissal(userID: userID, notice: notice)
        }
        currentNotice = nil
    }

    private func fetchNotices(token: String) async throws -> [LoginPopupNotice] {
        var components = URLComponents(
            url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/app_notices"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            .init(name: "select", value: "id,title,body,require_ack,expires_at,popup_image_url,popup_revision,popup_priority,popup_allow_dismiss,popup_action_label,popup_action_url,popup_start_at"),
            .init(name: "is_active", value: "eq.true"),
            .init(name: "show_as_popup", value: "eq.true"),
            .init(name: "order", value: "popup_priority.desc,created_at.desc"),
            .init(name: "limit", value: "25")
        ]
        let data = try await request(
            url: components.url!,
            method: "GET",
            token: token,
            body: nil,
            prefer: nil
        )
        return try JSONDecoder().decode([LoginPopupNotice].self, from: data)
    }

    private func fetchDismissals(token: String, userID: UUID) async throws -> [LoginPopupDismissal] {
        var components = URLComponents(
            url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/app_notice_popup_dismissals"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            .init(name: "select", value: "notice_id,dismissed_revision"),
            .init(name: "user_id", value: "eq.\(userID.uuidString.lowercased())")
        ]
        let data = try await request(
            url: components.url!,
            method: "GET",
            token: token,
            body: nil,
            prefer: nil
        )
        return try JSONDecoder().decode([LoginPopupDismissal].self, from: data)
    }

    private func saveDismissal(userID: UUID, notice: LoginPopupNotice) async throws {
        var components = URLComponents(
            url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/app_notice_popup_dismissals"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            .init(name: "on_conflict", value: "user_id,notice_id")
        ]

        let payload: [String: Any] = [
            "user_id": userID.uuidString.lowercased(),
            "notice_id": notice.id.uuidString.lowercased(),
            "dismissed_revision": max(1, notice.popupRevision)
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(
            url: components.url!,
            method: "POST",
            token: try await client.auth.session.accessToken,
            body: body,
            prefer: "resolution=merge-duplicates,return=minimal"
        )
    }

    private func request(
        url: URL,
        method: String,
        token: String,
        body: Data?,
        prefer: String?
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw NSError(
                domain: "LoginPopupNotice",
                code: status,
                userInfo: [NSLocalizedDescriptionKey: "공지 조회 실패 (\(status))"]
            )
        }
        return data
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: raw) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}

struct LoginPopupNoticeSheet: View {
    let notice: LoginPopupNotice
    let onClose: (_ neverShowAgain: Bool) -> Void
    @State private var neverShowAgain = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let raw = notice.popupImageURL,
                       let url = URL(string: raw),
                       !raw.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ZStack {
                                    Color.gray.opacity(0.08)
                                    ProgressView()
                                }
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                Color.gray.opacity(0.06)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    Text(notice.title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)

                    Text(notice.body)
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                        .textSelection(.enabled)

                    if let actionRaw = notice.popupActionURL,
                       let actionURL = URL(string: actionRaw),
                       !actionRaw.isEmpty {
                        Button {
                            UIApplication.shared.open(actionURL)
                        } label: {
                            Text((notice.popupActionLabel ?? "").isEmpty ? "자세히 보기" : (notice.popupActionLabel ?? ""))
                                .font(.headline.weight(.black))
                                .foregroundStyle(MaroowellTheme.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    if notice.allowsNeverShowAgain {
                        Toggle("다시 보지 않음", isOn: $neverShowAgain)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onClose(neverShowAgain)
                } label: {
                    Text("닫기")
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("공지")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .presentationDetents([.medium, .large])
    }
}
