import Foundation
import Supabase

@MainActor
final class SessionViewModel: ObservableObject {
    @Published private(set) var session: AppSession?
    @Published private(set) var isBootstrapping = true
    @Published private(set) var isSigningIn = false
    @Published var errorMessage: String?

    private let client = SupabaseService.shared.client

    init() {
        Task { await restoreSession() }
    }

    func restoreSession() async {
        isBootstrapping = true
        defer { isBootstrapping = false }

        do {
            _ = try await client.auth.session
            session = try await makeValidatedSession()
        } catch {
            session = nil
        }
    }

    func signIn(email: String, password: String) async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            errorMessage = "이메일과 비밀번호를 입력해주세요."
            return
        }

        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            try await client.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            session = try await makeValidatedSession()
        } catch {
            if error is MaroowellAuthError {
                try? await client.auth.signOut()
            }
            session = nil
            errorMessage = friendlyMessage(for: error)
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        session = nil
        errorMessage = nil
    }

    private func makeValidatedSession() async throws -> AppSession {
        let authSession = try await client.auth.session
        let user = authSession.user
        let state = try await loadAccountState()

        switch state.approvalStatus.lowercased() {
        case "approved":
            break
        case "pending":
            throw MaroowellAuthError.accountPending
        case "rejected":
            throw MaroowellAuthError.accountRejected
        default:
            throw MaroowellAuthError.accountStateUnavailable
        }

        let access = try await loadAccountAccess()
        let email = user.email ?? ""
        let displayName = try await loadDisplayName(userID: user.id)
            ?? email.split(separator: "@").first.map(String.init)
            ?? "마루웰"

        return AppSession(
            userID: user.id,
            email: email,
            displayName: displayName,
            isMaroowell: access.isMaroowell,
            isAdmin: access.isAdmin,
            roleLevel: access.maxRoleLevel,
            isDragonCarAdmin: access.isDragonCarAdmin
        )
    }

    private func loadAccountState() async throws -> AccountState {
        let response = try await client.rpc("mw_my_account_state").execute()
        guard let value: AccountState = decodeFirst(from: response.data) else {
            throw MaroowellAuthError.accountStateUnavailable
        }
        return value
    }

    private func loadAccountAccess() async throws -> AccountAccess {
        let response = try await client.rpc("mw_my_access").execute()
        guard let value: AccountAccess = decodeFirst(from: response.data) else {
            throw MaroowellAuthError.accessUnavailable
        }
        return value
    }

    private func loadDisplayName(userID: UUID) async throws -> String? {
        let response = try await client
            .from("profiles")
            .select("display_name")
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute()

        let rows = try JSONDecoder().decode([DisplayNameRow].self, from: response.data)
        return rows.first?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private func decodeFirst<T: Decodable>(from data: Data) -> T? {
        let decoder = JSONDecoder()
        if let rows = try? decoder.decode([T].self, from: data) {
            return rows.first
        }
        return try? decoder.decode(T.self, from: data)
    }

    private func friendlyMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }

        let raw = error.localizedDescription
        if raw.localizedCaseInsensitiveContains("invalid login credentials") {
            return "이메일 또는 비밀번호를 확인해주세요."
        }
        if raw.localizedCaseInsensitiveContains("rate limit") || raw.contains("429") {
            return "로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요."
        }
        return "로그인하지 못했습니다. 인터넷 연결을 확인하고 다시 시도해주세요."
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
