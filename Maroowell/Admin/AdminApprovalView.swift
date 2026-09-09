import Foundation
import SwiftUI

struct AdminApprovalView: View {
    let session: AppSession
    @StateObject private var store = AdminApprovalStore()
    @State private var editing: AdminAccountRow?
    @State private var deleteTarget: AdminAccountRow?

    var body: some View {
        Group {
            if session.isSuperAdmin {
                content
            } else {
                denied
            }
        }
        .navigationTitle("가입 승인 / 권한")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard session.isSuperAdmin, store.rows.isEmpty else { return }
            await store.loadPending()
        }
        .sheet(item: $editing) { row in
            AdminApprovalSheet(row: row) { state, appOnly, infoID in
                Task {
                    await store.setState(row: row, state: state, appOnly: appOnly, infoID: infoID)
                    editing = nil
                }
            }
        }
        .confirmationDialog("계정 삭제", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { row in
            Button("계정 삭제", role: .destructive) {
                Task {
                    await store.delete(row: row)
                    deleteTarget = nil
                }
            }
            Button("취소", role: .cancel) { deleteTarget = nil }
        } message: { row in
            Text("\(row.displayName) 계정을 완전히 삭제합니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .alert("관리자 권한", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                tools
                if store.loading && store.rows.isEmpty {
                    ProgressView("계정 정보를 불러오는 중...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                } else if store.rows.isEmpty {
                    Text(store.pendingMode ? "승인 대기 계정이 없습니다." : "검색 결과가 없습니다.")
                        .foregroundStyle(MaroowellTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 50)
                } else {
                    ForEach(store.rows) { row in
                        AdminAccountCard(
                            row: row,
                            pending: store.pendingMode,
                            onEdit: { editing = row },
                            onDelete: { deleteTarget = row }
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(MaroowellTheme.background)
    }

    private var tools: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MaroowellTheme.muted)
                    TextField("이름 · 이메일 · 쿠팡ID", text: $store.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await store.search() } }
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 13))

                Button("검색") { Task { await store.search() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.loading)
            }

            HStack(spacing: 8) {
                Button("승인대기") { Task { await store.loadPending() } }
                    .buttonStyle(.bordered)
                    .disabled(store.loading)
                ShareLink(item: URL(string: "https://maroowell.com/?signup=1")!) {
                    Label("가입링크", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                Spacer()
                Text("\(store.rows.count)건")
                    .font(.caption.weight(.black))
                    .foregroundStyle(MaroowellTheme.muted)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(MaroowellTheme.border) }
    }

    private var denied: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill").font(.largeTitle)
            Text("마루웰 최고관리자 권한이 필요합니다.")
                .font(.headline.weight(.black))
        }
        .foregroundStyle(MaroowellTheme.muted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaroowellTheme.background)
    }
}

private struct AdminAccountCard: View {
    let row: AdminAccountRow
    let pending: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(row.displayName)
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
            Text(row.email)
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)
            Text(row.linkSummary)
                .font(.caption)
                .foregroundStyle(MaroowellTheme.ink)

            if pending {
                Button("승인 설정", action: onEdit)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    Button("권한 선택", action: onEdit)
                        .buttonStyle(.bordered)
                    Button("계정 삭제", role: .destructive, action: onDelete)
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(MaroowellTheme.border) }
    }
}

private struct AdminApprovalSheet: View {
    let row: AdminAccountRow
    let onSubmit: (String, Bool, Int64?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var infoID: String
    @State private var appOnly: Bool

    init(row: AdminAccountRow, onSubmit: @escaping (String, Bool, Int64?) -> Void) {
        self.row = row
        self.onSubmit = onSubmit
        _infoID = State(initialValue: row.defaultInfoID.map(String.init) ?? "")
        _appOnly = State(initialValue: row.appOnly)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("계정") {
                    Text(row.displayName)
                    Text(row.email).foregroundStyle(.secondary)
                }
                Section("연결") {
                    TextField("maroowell_info PK", text: $infoID)
                        .keyboardType(.numberPad)
                    Toggle("앱 전용 (웹 로그인 차단)", isOn: $appOnly)
                }
                Section {
                    Button("승인") {
                        onSubmit("approved", appOnly, Int64(infoID))
                    }
                    Button("대기 / 거절", role: .destructive) {
                        onSubmit("rejected", false, nil)
                    }
                }
            }
            .navigationTitle("계정 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}

private struct AdminAccountRow: Identifiable, Hashable {
    let userID: String
    let displayName: String
    let email: String
    let linkedName: String
    let suggestedName: String
    let infoID: Int64?
    let suggestedInfoID: Int64?
    let appOnly: Bool

    var id: String { userID.isEmpty ? email : userID }
    var defaultInfoID: Int64? { infoID ?? suggestedInfoID }
    var linkSummary: String {
        if !linkedName.isEmpty { return "인사정보 연결됨 · \(linkedName)" }
        if !suggestedName.isEmpty { return "추천 매칭 · \(suggestedName)" }
        return "maroowell_info 매칭 없음"
    }
}

@MainActor
private final class AdminApprovalStore: ObservableObject {
    @Published var rows: [AdminAccountRow] = []
    @Published var query = ""
    @Published var loading = false
    @Published var pendingMode = true
    @Published var message: String?

    func loadPending() async {
        await loadRPC("mw_admin_pending_users", body: ["p_query": ""], pending: true)
    }

    func search() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            await loadPending()
            return
        }
        await loadRPC("mw_admin_search_accounts", body: ["p_query": q], pending: false)
    }

    func setState(row: AdminAccountRow, state: String, appOnly: Bool, infoID: Int64?) async {
        loading = true
        defer { loading = false }
        do {
            var payload: [String: Any] = [
                "p_user_id": row.userID,
                "p_approval_status": state,
                "p_app_only": appOnly
            ]
            payload["p_maroowell_info_id"] = infoID ?? NSNull()
            _ = try await requestRPC("mw_admin_set_account_state", body: payload)
            message = state == "approved" ? "승인했습니다." : "상태를 변경했습니다."
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await loadPending()
            } else {
                await search()
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func delete(row: AdminAccountRow) async {
        guard !row.userID.isEmpty else {
            message = "삭제할 계정 ID가 없습니다."
            return
        }
        loading = true
        defer { loading = false }
        do {
            _ = try await edgeFunction("admin-delete-account", body: ["user_id": row.userID])
            message = "\(row.displayName) 계정을 삭제했습니다."
            await search()
        } catch {
            message = error.localizedDescription
        }
    }

    private func loadRPC(_ name: String, body: [String: Any], pending: Bool) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let data = try await requestRPC(name, body: body)
            let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            rows = raw.map(Self.row)
            pendingMode = pending
        } catch {
            rows = []
            message = error.localizedDescription
        }
    }

    private func requestRPC(_ name: String, body: [String: Any]) async throws -> Data {
        let auth = try await SupabaseService.shared.client.auth.session
        var request = URLRequest(url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/rpc/\(name)"))
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, fallback: "관리자 요청 실패")
        return data
    }

    private func edgeFunction(_ name: String, body: [String: Any]) async throws -> Data {
        let auth = try await SupabaseService.shared.client.auth.session
        var request = URLRequest(url: AppConfig.supabaseURL.appendingPathComponent("functions/v1/\(name)"))
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, fallback: "계정 삭제 실패")
        return data
    }

    private static func row(_ object: [String: Any]) -> AdminAccountRow {
        AdminAccountRow(
            userID: text(object["user_id"]),
            displayName: text(object["display_name"]).isEmpty ? text(object["email"]) : text(object["display_name"]),
            email: text(object["email"]),
            linkedName: text(object["info_person_name"]),
            suggestedName: text(object["suggested_person_name"]),
            infoID: int64(object["maroowell_info_id"]),
            suggestedInfoID: int64(object["suggested_info_id"]),
            appOnly: bool(object["app_only"])
        )
    }

    private static func text(_ value: Any?) -> String {
        if value == nil || value is NSNull { return "" }
        if let string = value as? String { return string.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value ?? "")
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber { return number.int64Value }
        return Int64(text(value))
    }

    private static func bool(_ value: Any?) -> Bool {
        if let number = value as? NSNumber { return number.boolValue }
        return ["true", "1", "yes"].contains(text(value).lowercased())
    }

    private static func validate(_ response: URLResponse, fallback: String) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "AdminApproval", code: code, userInfo: [NSLocalizedDescriptionKey: "\(fallback) (\(code))"])
        }
    }
}