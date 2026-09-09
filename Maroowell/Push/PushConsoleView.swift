import Foundation
import SwiftUI

struct PushConsoleView: View {
    let session: AppSession
    @StateObject private var store = PushConsoleStore()
    @State private var showSendConfirm = false

    var body: some View {
        Group {
            if session.canView("/maroowell_push") || session.isTeamLeader {
                content
            } else {
                denied
            }
        }
        .navigationTitle("PUSH 알림")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard store.memberships.isEmpty && !store.companyAdmin else { return }
            await store.bootstrap()
        }
        .confirmationDialog("PUSH를 발송할까요?", isPresented: $showSendConfirm) {
            Button("발송", role: .destructive) { Task { await store.send() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text(store.previewSummary)
        }
        .alert("PUSH 알림", isPresented: Binding(
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
            VStack(spacing: 14) {
                composeCard
                historyCard
            }
            .padding(16)
        }
        .background(Color(red: 1.0, green: 0.99, blue: 0.97))
    }

    private var composeCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("알림 발송")
                        .font(.title3.weight(.black))
                    Text(store.statusText)
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                if store.loading { ProgressView().controlSize(.small) }
            }

            Text("알림 종류").font(.caption.weight(.black)).foregroundStyle(MaroowellTheme.muted)
            Picker("알림 종류", selection: $store.noticeType) {
                Text("🚨 긴급").tag("emergency")
                Text("⚠️ 중요").tag("important")
                Text("🔔 일반").tag("normal")
            }
            .pickerStyle(.segmented)
            .onChange(of: store.noticeType) { _, _ in store.invalidatePreview() }

            Text("발송 범위").font(.caption.weight(.black)).foregroundStyle(MaroowellTheme.muted)
            Picker("발송 범위", selection: $store.scope) {
                if store.hasCampScope { Text("담당 캠프 선택").tag("camp") }
                if store.canVendorBroadcast { Text("소속 전체 캠프").tag("vendor") }
                if store.companyAdmin { Text("전사 전체").tag("company") }
            }
            .pickerStyle(.menu)
            .onChange(of: store.scope) { _, _ in store.invalidatePreview() }

            if store.scope == "camp" {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.currentCamps) { camp in
                        Toggle(isOn: Binding(
                            get: { store.selectedCamps.contains(camp.name) },
                            set: { store.setCamp(camp.name, selected: $0) }
                        )) {
                            HStack {
                                Text(camp.name).font(.subheadline.weight(.bold))
                                Spacer()
                                Text("\(camp.users)명 · \(camp.devices)기기")
                                    .font(.caption)
                                    .foregroundStyle(MaroowellTheme.muted)
                            }
                        }
                    }
                }
                .padding(12)
                .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 14))
            }

            TextField("제목", text: $store.title)
                .textFieldStyle(.roundedBorder)
                .onChange(of: store.title) { _, _ in store.invalidatePreview() }

            TextEditor(text: $store.bodyText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(MaroowellTheme.border) }
                .onChange(of: store.bodyText) { _, _ in store.invalidatePreview() }

            HStack(spacing: 8) {
                Button("대상 확인") { Task { await store.previewTargets() } }
                    .buttonStyle(.bordered)
                    .disabled(store.loading)
                    .frame(maxWidth: .infinity)
                Button("PUSH 발송", role: .destructive) { showSendConfirm = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canSend || store.loading)
                    .frame(maxWidth: .infinity)
            }

            if !store.previewSummary.isEmpty {
                Text(store.previewSummary)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MaroowellTheme.muted)
            }
        }
        .padding(15)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(MaroowellTheme.border) }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("발송 이력").font(.title3.weight(.black))
                Spacer()
                Button("새로고침") { Task { await store.loadHistory() } }
                    .buttonStyle(.bordered)
                    .disabled(store.loading)
            }

            if store.notices.isEmpty {
                Text(store.loading ? "발송 이력을 불러오는 중..." : "아직 발송된 알림이 없습니다.")
                    .foregroundStyle(MaroowellTheme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else {
                ForEach(store.notices) { notice in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(notice.typeLabel).font(.caption.weight(.black))
                            Text(notice.scopeLabel).font(.caption).foregroundStyle(MaroowellTheme.muted)
                            Spacer()
                            Text(notice.createdAt).font(.caption2).foregroundStyle(MaroowellTheme.muted)
                        }
                        Text(notice.title).font(.headline.weight(.black))
                        if !notice.body.isEmpty {
                            Text(notice.body).font(.caption).foregroundStyle(MaroowellTheme.muted).lineLimit(3)
                        }
                        if !notice.stats.isEmpty {
                            Text(notice.stats).font(.caption2.weight(.bold)).foregroundStyle(MaroowellTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(15)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(MaroowellTheme.border) }
    }

    private var denied: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill").font(.largeTitle)
            Text("PUSH 발송 권한이 필요합니다.").font(.headline.weight(.black))
        }
        .foregroundStyle(MaroowellTheme.muted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaroowellTheme.background)
    }
}

private struct PushCamp: Identifiable, Hashable {
    let name: String
    let users: Int
    let devices: Int
    var id: String { name }
}

private struct PushMembership: Identifiable, Hashable {
    let vendorID: String
    let roleLevel: Int
    let canVendorBroadcast: Bool
    let camps: [PushCamp]
    var id: String { vendorID }
}

private struct PushNotice: Identifiable, Hashable {
    let id: String
    let noticeType: String
    let targetScope: String
    let targetCamps: [String]
    let title: String
    let body: String
    let createdAt: String
    let stats: String

    var typeLabel: String {
        switch noticeType {
        case "emergency": return "🚨 긴급"
        case "important": return "⚠️ 중요"
        default: return "🔔 일반"
        }
    }
    var scopeLabel: String {
        switch targetScope {
        case "company": return "전사"
        case "vendor": return "소속 전체"
        default: return targetCamps.isEmpty ? "캠프" : targetCamps.joined(separator: ", ")
        }
    }
}

@MainActor
private final class PushConsoleStore: ObservableObject {
    @Published var memberships: [PushMembership] = []
    @Published var companyAdmin = false
    @Published var selectedMembership = 0
    @Published var scope = "camp"
    @Published var noticeType = "emergency"
    @Published var selectedCamps: Set<String> = []
    @Published var title = ""
    @Published var bodyText = ""
    @Published var notices: [PushNotice] = []
    @Published var loading = false
    @Published var statusText = "PUSH 발송 권한과 대상을 불러오는 중입니다."
    @Published var previewUsers = 0
    @Published var previewDevices = 0
    @Published var message: String?

    var currentMembership: PushMembership? {
        guard memberships.indices.contains(selectedMembership) else { return nil }
        return memberships[selectedMembership]
    }
    var currentCamps: [PushCamp] { currentMembership?.camps ?? [] }
    var hasCampScope: Bool { !memberships.isEmpty }
    var canVendorBroadcast: Bool { currentMembership?.canVendorBroadcast == true }
    var canSend: Bool { previewUsers > 0 && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var previewSummary: String {
        previewUsers > 0 ? "대상 \(previewUsers)명 · PUSH 수신 가능 \(previewDevices)기기" : ""
    }

    func bootstrap() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let data = try await callFunction("app-push-console", payload: ["action": "bootstrap"])
            let object = try Self.object(data)
            companyAdmin = Self.bool(object["company_admin"])
            memberships = Self.memberships(object["memberships"])
            scope = !memberships.isEmpty ? "camp" : (companyAdmin ? "company" : "camp")
            notices = Self.notices(object["notices"])
            statusText = companyAdmin ? "마루웰 운영 권한" : "마루웰 팀장 권한"
        } catch {
            statusText = "PUSH 권한 확인 실패"
            message = error.localizedDescription
        }
    }

    func setCamp(_ name: String, selected: Bool) {
        if selected { selectedCamps.insert(name) } else { selectedCamps.remove(name) }
        invalidatePreview()
    }

    func invalidatePreview() {
        previewUsers = 0
        previewDevices = 0
    }

    func previewTargets() async {
        if scope == "camp" && selectedCamps.isEmpty {
            message = "대상 캠프를 하나 이상 선택하세요."
            return
        }
        await dispatch(action: "preview", sending: false)
    }

    func send() async {
        guard canSend else {
            message = "먼저 대상 확인을 하고 제목과 내용을 입력하세요."
            return
        }
        await dispatch(action: "send", sending: true)
    }

    func loadHistory() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let data = try await callFunction("app-push-console", payload: ["action": "history"])
            let object = try Self.object(data)
            notices = Self.notices(object["notices"])
        } catch {
            message = error.localizedDescription
        }
    }

    private func dispatch(action: String, sending: Bool) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let data = try await callFunction("app-push-dispatch", payload: payload(action: action))
            let object = try Self.object(data)
            if sending {
                let sent = Self.int(object["sent_users"])
                let failed = Self.int(object["failed_users"])
                let skipped = Self.int(object["skipped_users"])
                message = "발송 완료 · 성공 \(sent)명 / 실패 \(failed)명 / 미수신 \(skipped)명"
                title = ""
                bodyText = ""
                invalidatePreview()
                await loadHistory()
            } else {
                previewUsers = Self.int(object["recipient_count"])
                previewDevices = Self.int(object["active_device_count"])
                statusText = previewSummary.isEmpty ? "발송 대상이 없습니다." : previewSummary
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func payload(action: String) -> [String: Any] {
        var result: [String: Any] = [
            "action": action,
            "target_scope": scope,
            "target_camps": scope == "camp" ? Array(selectedCamps).sorted() : [],
            "notice_type": noticeType,
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "body": bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            "send_push": true,
            "show_on_home": false,
            "require_ack": false
        ]
        result["vendor_id"] = scope == "company" ? NSNull() : (currentMembership?.vendorID ?? NSNull())
        return result
    }

    private func callFunction(_ name: String, payload: [String: Any]) async throws -> Data {
        let auth = try await SupabaseService.shared.client.auth.session
        var request = URLRequest(url: AppConfig.supabaseURL.appendingPathComponent("functions/v1/\(name)"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "PushConsole", code: code, userInfo: [NSLocalizedDescriptionKey: "PUSH 요청 실패 (\(code))"])
        }
        return data
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private static func memberships(_ value: Any?) -> [PushMembership] {
        guard let rows = value as? [[String: Any]] else { return [] }
        return rows.map { row in
            PushMembership(
                vendorID: text(row["vendor_id"]),
                roleLevel: int(row["role_level"]),
                canVendorBroadcast: bool(row["can_vendor_broadcast"]),
                camps: camps(row["camps"])
            )
        }
    }

    private static func camps(_ value: Any?) -> [PushCamp] {
        guard let rows = value as? [[String: Any]] else { return [] }
        return rows.map { row in PushCamp(name: text(row["camp"]), users: int(row["registered_users"]), devices: int(row["active_devices"])) }
    }

    private static func notices(_ value: Any?) -> [PushNotice] {
        guard let rows = value as? [[String: Any]] else { return [] }
        return rows.map { row in
            let statsObject = row["stats"] as? [String: Any] ?? [:]
            let stats = statsObject.isEmpty ? "" : statsObject.map { "\($0.key) \(text($0.value))" }.sorted().joined(separator: " · ")
            let targetCamps = row["target_camps"] as? [String] ?? []
            return PushNotice(
                id: text(row["id"]).isEmpty ? UUID().uuidString : text(row["id"]),
                noticeType: text(row["notice_type"]),
                targetScope: text(row["target_scope"]),
                targetCamps: targetCamps,
                title: text(row["title"]),
                body: text(row["body"]),
                createdAt: text(row["created_at"]),
                stats: stats
            )
        }
    }

    private static func text(_ value: Any?) -> String {
        if value == nil || value is NSNull { return "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value ?? "")
    }
    private static func int(_ value: Any?) -> Int {
        if let number = value as? NSNumber { return number.intValue }
        return Int(text(value)) ?? 0
    }
    private static func bool(_ value: Any?) -> Bool {
        if let number = value as? NSNumber { return number.boolValue }
        return ["true", "1", "yes"].contains(text(value).lowercased())
    }
}