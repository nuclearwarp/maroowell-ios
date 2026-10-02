import PhotosUI
import SwiftUI
import UIKit
import Supabase

struct OperationsBoardView: View {
    let session: AppSession
    @StateObject private var store: OperationsBoardStore
    @State private var editor: OperationsEditor?

    init(session: AppSession) {
        self.session = session
        _store = StateObject(wrappedValue: OperationsBoardStore(session: session))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                noticeSection
                if store.canManage {
                    summarySection("실시간 운영 요약", rows: store.realtimeRows, emptyText: "실시간 운영 데이터가 없습니다.")
                    summarySection("메모", rows: store.memoRows, emptyText: "등록된 메모가 없습니다.")
                    taskSection
                    issueSection
                    summarySection("프로세스", rows: store.workflowRows, emptyText: "진행 중 프로세스가 없습니다.")
                    summarySection("완료 이력", rows: store.completedRows, emptyText: "완료된 업무나 이슈가 없습니다.")
                    summarySection("인원 · 앱 활성화", rows: store.peopleRows, emptyText: "인원·앱 상태가 없습니다.")
                    summarySection("앱 기능 · 버전", rows: store.versionRows, emptyText: "앱 버전 정보가 없습니다.")
                    summarySection("변경 이력", rows: store.auditRows, emptyText: "변경 이력이 없습니다.")
                }
            }
            .padding(16)
        }
        .background(MaroowellTheme.background)
        .navigationTitle("운영 업무")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await store.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.loading)
            }
        }
        .task {
            if !store.loaded { await store.load() }
        }
        .sheet(item: $editor) { value in
            OperationsEditorSheet(editor: value, store: store)
        }
        .alert("운영 업무", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
    }

    private var noticeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("공지사항", count: store.notices.count, actionTitle: store.canSendNotice ? "+ 공지" : nil) {
                editor = .notice
            }
            if store.loading && !store.loaded {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if store.notices.isEmpty {
                empty("등록된 공지가 없습니다.")
            } else {
                ForEach(store.notices.prefix(6)) { notice in
                    operationCard(
                        title: notice.title,
                        meta: [notice.typeLabel, notice.createdAt.shortDateTime].filter { !$0.isEmpty }.joined(separator: " · "),
                        body: notice.body,
                        accent: notice.noticeType == "emergency" ? .red : .blue
                    )
                }
            }
        }
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("진행중 업무", count: store.tasks.count, actionTitle: "+ 업무") {
                editor = .task(nil)
            }
            if store.tasks.isEmpty {
                empty("진행 중 업무가 없습니다.")
            } else {
                ForEach(store.tasks) { task in
                    Button {
                        editor = .task(task)
                    } label: {
                        operationCard(
                            title: task.title,
                            meta: [
                                task.statusLabel,
                                task.campCode.isEmpty ? "공통" : task.campCode,
                                task.wave,
                                task.dueDate.isEmpty ? "" : "마감 \(task.dueDate)"
                            ].filter { !$0.isEmpty }.joined(separator: " · "),
                            body: task.body,
                            accent: MaroowellTheme.deepYellow
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var issueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("운영 이슈", count: store.issues.count, actionTitle: "+ 이슈") {
                editor = .issue(nil)
            }
            if store.issues.isEmpty {
                empty("진행 중 운영 이슈가 없습니다.")
            } else {
                ForEach(store.issues) { issue in
                    Button {
                        editor = .issue(issue)
                    } label: {
                        operationCard(
                            title: issue.title,
                            meta: [
                                issue.statusLabel,
                                issue.campCode.isEmpty ? "공통" : issue.campCode,
                                issue.wave,
                                issue.personName
                            ].filter { !$0.isEmpty }.joined(separator: " · "),
                            body: issue.body,
                            accent: issue.severity == "critical" ? .red : .orange
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func summarySection(_ title: String, rows: [OperationSummaryRow], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title, count: rows.count, actionTitle: nil) {}
            if rows.isEmpty {
                empty(emptyText)
            } else {
                ForEach(rows) { row in
                    operationCard(
                        title: row.title,
                        meta: row.meta,
                        body: row.body,
                        accent: row.accent
                    )
                }
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int, actionTitle: String?, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.title3.weight(.black)).foregroundStyle(MaroowellTheme.ink)
            Text("\(count)건").font(.caption.weight(.bold)).foregroundStyle(MaroowellTheme.muted)
            Spacer()
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }

    private func operationCard(title: String, meta: String, body: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.isEmpty ? "-" : title)
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !meta.isEmpty {
                Text(meta).font(.caption.weight(.bold)).foregroundStyle(accent)
            }
            if !body.isEmpty {
                Text(body).font(.caption).foregroundStyle(MaroowellTheme.muted).lineLimit(5)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(MaroowellTheme.border) }
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(MaroowellTheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct NoticeBoardView: View {
    let session: AppSession
    @StateObject private var store = NoticeBoardStore()

    var body: some View {
        Group {
            if !session.isMaroowell {
                ContentUnavailableView("권한이 없습니다.", systemImage: "lock.fill")
            } else if store.loading && store.notices.isEmpty {
                ProgressView("공지사항을 불러오는 중...")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if store.notices.isEmpty {
                            Text("등록된 공지가 없습니다.")
                                .foregroundStyle(MaroowellTheme.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(store.notices) { notice in
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(notice.title)
                                        .font(.headline.weight(.black))
                                        .foregroundStyle(MaroowellTheme.ink)
                                    Text("\(notice.typeLabel) · \(notice.createdAt.shortDateTime)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.blue)
                                    if !notice.body.isEmpty {
                                        Text(notice.body)
                                            .font(.subheadline)
                                            .foregroundStyle(MaroowellTheme.muted)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                                .overlay { RoundedRectangle(cornerRadius: 16).stroke(MaroowellTheme.border) }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(MaroowellTheme.background)
        .navigationTitle("공지사항")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await store.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { if session.isMaroowell && store.notices.isEmpty { await store.load() } }
        .alert("공지사항", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
}

private enum OperationsEditor: Identifiable {
    case notice
    case task(OperationTask?)
    case issue(OperationIssue?)

    var id: String {
        switch self {
        case .notice: return "notice"
        case .task(let row): return "task-\(row?.id ?? "new")"
        case .issue(let row): return "issue-\(row?.id ?? "new")"
        }
    }
}

private struct OperationsEditorSheet: View {
    let editor: OperationsEditor
    @ObservedObject var store: OperationsBoardStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var bodyText = ""
    @State private var camp = ""
    @State private var wave = ""
    @State private var status = ""
    @State private var priority = ""
    @State private var categoryID = ""
    @State private var targetVersion = ""
    @State private var dueDate = ""
    @State private var personName = ""
    @State private var severity = ""
    @State private var resignationNoticeDate = ""
    @State private var noticeType = "normal"
    @State private var noticeScope = "camp"
    @State private var sendPush = true
    @State private var showPopup = true
    @State private var allowDismiss = true
    @State private var requireAck = false
    @State private var selectedCamps: Set<String> = []
    @State private var selectedUsers: Set<String> = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedPhotoImage: UIImage?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                switch editor {
                case .notice:
                    Picker("구분", selection: $noticeType) {
                        Text("일반").tag("normal")
                        Text("중요").tag("important")
                        Text("긴급").tag("emergency")
                    }

                    Picker("발송 대상", selection: $noticeScope) {
                        if store.canCompanyBroadcast {
                            Text("회사전체").tag("company")
                        }
                        Text("캠프 단위").tag("camp")
                        Text("개별 계정").tag("account")
                    }

                    if noticeScope == "camp" {
                        Section("대상 캠프") {
                            ForEach(store.noticeCamps) { row in
                                Toggle(isOn: Binding(
                                    get: { selectedCamps.contains(row.camp) },
                                    set: { checked in
                                        if checked { selectedCamps.insert(row.camp) }
                                        else { selectedCamps.remove(row.camp) }
                                    }
                                )) {
                                    Text("\(row.camp) · \(row.registeredUsers)명")
                                }
                            }
                        }
                    } else if noticeScope == "account" {
                        Section("개별 계정") {
                            ForEach(store.noticeAccounts) { row in
                                Toggle(isOn: Binding(
                                    get: { selectedUsers.contains(row.userID) },
                                    set: { checked in
                                        if checked { selectedUsers.insert(row.userID) }
                                        else { selectedUsers.remove(row.userID) }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(row.displayName.isEmpty ? row.email : row.displayName)
                                        Text([row.camp, row.email].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(MaroowellTheme.muted)
                                    }
                                }
                            }
                        }
                    }

                    Toggle("PUSH 발송", isOn: $sendPush)
                    Toggle("로그인 팝업 표시", isOn: $showPopup)

                    if showPopup {
                        Toggle("다시 보지 않음 허용", isOn: $allowDismiss)
                            .disabled(requireAck)
                        Toggle("확인 필수", isOn: $requireAck)
                            .onChange(of: requireAck) { _, checked in
                                if checked { allowDismiss = false }
                            }

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(selectedPhotoImage == nil ? "공지 이미지 선택" : "이미지 변경", systemImage: "photo")
                        }
                        .onChange(of: selectedPhoto) { _, item in
                            Task { await loadSelectedNoticePhoto(item) }
                        }

                        if let selectedPhotoImage {
                            Image(uiImage: selectedPhotoImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    TextField("제목", text: $title)
                    TextField("내용", text: $bodyText, axis: .vertical).lineLimit(4...8)

                case .task:
                    categoryPicker
                    TextField("업무명", text: $title)
                    TextField("세부 내용", text: $bodyText, axis: .vertical).lineLimit(3...7)
                    TextField("캠프", text: $camp)
                    Picker("주/야", selection: $wave) {
                        Text("공통").tag("")
                        Text("주간").tag("주간")
                        Text("야간").tag("야간")
                    }
                    Picker("상태", selection: $status) {
                        Text("대기").tag("planned")
                        Text("진행중").tag("in_progress")
                        Text("완료").tag("completed")
                    }
                    Picker("우선순위", selection: $priority) {
                        Text("일반").tag("normal")
                        Text("높음").tag("high")
                        Text("긴급").tag("urgent")
                        Text("낮음").tag("low")
                    }
                    TextField("목표 버전", text: $targetVersion)
                    TextField("마감일 (YYYY-MM-DD)", text: $dueDate)

                case .issue:
                    categoryPicker
                    TextField("제목", text: $title)
                    TextField("코멘트", text: $bodyText, axis: .vertical).lineLimit(3...7)
                    TextField("캠프", text: $camp)
                    Picker("주/야", selection: $wave) {
                        Text("공통").tag("")
                        Text("주간").tag("주간")
                        Text("야간").tag("야간")
                    }
                    TextField("대상 기사", text: $personName)
                    Picker("중요도", selection: $severity) {
                        Text("일반").tag("normal")
                        Text("높음").tag("high")
                        Text("긴급").tag("critical")
                        Text("낮음").tag("low")
                    }
                    Picker("상태", selection: $status) {
                        Text("확인필요").tag("open")
                        Text("진행중").tag("monitoring")
                        Text("해결").tag("resolved")
                        Text("종료").tag("closed")
                    }
                    if store.categoryCode(id: categoryID) == "resignation" {
                        TextField("퇴사 통보일 (YYYY-MM-DD)", text: $resignationNoticeDate)
                        if let last = resignationLastDate {
                            Text("최종 마지막 근무일 \(last)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "저장 중..." : "저장") {
                        Task { await save() }
                    }
                    .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { hydrate() }
        }
    }

    @ViewBuilder
    private var categoryPicker: some View {
        Picker("구분", selection: $categoryID) {
            Text("선택").tag("")
            ForEach(store.categories) { category in
                Text(category.name).tag(category.id)
            }
        }
    }

    private var editorTitle: String {
        switch editor {
        case .notice: return "공지 등록"
        case .task(let row): return row == nil ? "업무 등록" : "업무 수정"
        case .issue(let row): return row == nil ? "운영 이슈 등록" : "운영 이슈 수정"
        }
    }

    private var resignationLastDate: String? {
        guard store.categoryCode(id: categoryID) == "resignation" else { return nil }
        if title == "김용준 퇴사" || personName == "김용준" { return "2026-09-25" }
        guard let date = OperationsDate.iso.date(from: resignationNoticeDate) else { return nil }
        return OperationsDate.iso.string(from: Calendar(identifier: .gregorian).date(byAdding: .day, value: 60, to: date) ?? date)
    }

    @MainActor
    private func loadSelectedNoticePhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            selectedPhotoData = nil
            selectedPhotoImage = nil
            return
        }
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: raw),
              let jpeg = image.jpegData(compressionQuality: 0.88) else {
            store.message = "이미지를 불러오지 못했습니다."
            return
        }
        guard jpeg.count <= 10 * 1024 * 1024 else {
            store.message = "이미지는 10MB 이하만 등록할 수 있습니다."
            selectedPhotoData = nil
            selectedPhotoImage = nil
            return
        }
        selectedPhotoData = jpeg
        selectedPhotoImage = image
    }

    private func hydrate() {
        switch editor {
        case .notice:
            if store.canCompanyBroadcast { noticeScope = "company" }
            Task { await store.loadNoticeContextIfNeeded() }
        case .task(let row):
            guard let row else {
                status = "planned"; priority = "normal"; return
            }
            categoryID = row.categoryID; title = row.title; bodyText = row.body
            camp = row.campCode; wave = row.wave; status = row.status; priority = row.priority
            targetVersion = row.targetVersion; dueDate = row.dueDate
        case .issue(let row):
            guard let row else {
                status = "open"; severity = "normal"; return
            }
            categoryID = row.categoryID; title = row.title; bodyText = row.body
            camp = row.campCode; wave = row.wave; personName = row.personName
            severity = row.severity; status = row.status
            resignationNoticeDate = row.resignationNoticeDate
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            switch editor {
            case .notice:
                try await store.sendNotice(
                    title: title,
                    body: bodyText,
                    type: noticeType,
                    scope: noticeScope,
                    camps: Array(selectedCamps),
                    userIDs: Array(selectedUsers),
                    sendPush: sendPush,
                    showPopup: showPopup,
                    allowDismiss: allowDismiss,
                    requireAck: requireAck,
                    imageData: selectedPhotoData
                )
            case .task(let row):
                try await store.saveTask(
                    existing: row, categoryID: categoryID, title: title, body: bodyText,
                    camp: camp, wave: wave, status: status, priority: priority,
                    targetVersion: targetVersion, dueDate: dueDate
                )
            case .issue(let row):
                try await store.saveIssue(
                    existing: row, categoryID: categoryID, title: title, body: bodyText,
                    camp: camp, wave: wave, personName: personName, severity: severity,
                    status: status, resignationNoticeDate: resignationNoticeDate,
                    resignationLastDate: resignationLastDate
                )
            }
            dismiss()
        } catch {
            store.message = error.localizedDescription
        }
    }
}

@MainActor
private final class OperationsBoardStore: ObservableObject {
    @Published var notices: [OperationNotice] = []
    @Published var tasks: [OperationTask] = []
    @Published var issues: [OperationIssue] = []
    @Published var categories: [OperationCategory] = []
    @Published var realtimeRows: [OperationSummaryRow] = []
    @Published var memoRows: [OperationSummaryRow] = []
    @Published var workflowRows: [OperationSummaryRow] = []
    @Published var completedRows: [OperationSummaryRow] = []
    @Published var peopleRows: [OperationSummaryRow] = []
    @Published var versionRows: [OperationSummaryRow] = []
    @Published var auditRows: [OperationSummaryRow] = []
    @Published var noticeCamps: [NoticeTargetCamp] = []
    @Published var noticeAccounts: [NoticeTargetAccount] = []
    @Published var canCompanyBroadcast = false
    @Published var loading = false
    @Published var loaded = false
    @Published var message: String?

    let session: AppSession
    var canManage: Bool { session.isSuperAdmin }
    var canSendNotice: Bool { session.isMaroowell && session.roleLevel >= 30 }

    init(session: AppSession) { self.session = session }

    func categoryCode(id: String) -> String {
        categories.first(where: { $0.id == id })?.code ?? ""
    }

    func load() async {
        loading = true
        defer { loading = false }
        do {
            if canManage {
                let data = try await call("bootstrap", method: "GET", body: nil)
                let allTasks = Self.tasks(data["tasks"])
                let allIssues = Self.issues(data["issues"])
                notices = Self.notices(data["notices"])
                tasks = allTasks.filter { !["completed", "cancelled"].contains($0.status) && !$0.isArchived }
                issues = allIssues.filter { !["resolved", "closed"].contains($0.status) && !$0.isArchived }
                categories = Self.categories(data["categories"])
                realtimeRows = Self.realtime(data["realtime"])
                memoRows = Self.memos(data["memos"])
                workflowRows = Self.workflows(data["workflows"])
                completedRows = Self.completed(data["tasks"], data["issues"])
                peopleRows = Self.people(data["people"])
                auditRows = Self.audit(data["audit_logs"])
                versionRows = (try? await fetchVersionRows()) ?? []
            } else {
                notices = try await NoticeBoardStore.fetchNotices()
                tasks = []; issues = []; categories = []
                realtimeRows = []; memoRows = []; workflowRows = []
                completedRows = []; peopleRows = []; versionRows = []; auditRows = []
            }
            loaded = true
        } catch {
            message = error.localizedDescription
        }
    }

    func loadNoticeContextIfNeeded() async {
        if !noticeCamps.isEmpty || !noticeAccounts.isEmpty || canCompanyBroadcast { return }
        do {
            let data = try await callEdgeFunction("app-push-console", payload: ["action": "context"])
            canCompanyBroadcast = Self.bool(data["can_company_broadcast"])
            noticeCamps = (data["camps"] as? [[String: Any]] ?? []).map {
                NoticeTargetCamp(
                    camp: Self.text($0["camp"]),
                    registeredUsers: Int(Self.text($0["registered_users"])) ?? 0
                )
            }
            noticeAccounts = (data["accounts"] as? [[String: Any]] ?? []).map {
                NoticeTargetAccount(
                    userID: Self.text($0["user_id"]),
                    displayName: Self.text($0["display_name"]),
                    email: Self.text($0["email"]),
                    camp: Self.text($0["camp"])
                )
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func sendNotice(
        title: String,
        body: String,
        type: String,
        scope: String,
        camps: [String],
        userIDs: [String],
        sendPush: Bool,
        showPopup: Bool,
        allowDismiss: Bool,
        requireAck: Bool,
        imageData: Data?
    ) async throws {
        if scope == "camp" && camps.isEmpty {
            throw NSError(domain: "Notice", code: -1, userInfo: [NSLocalizedDescriptionKey: "대상 캠프를 선택하세요."])
        }
        if scope == "account" && userIDs.isEmpty {
            throw NSError(domain: "Notice", code: -1, userInfo: [NSLocalizedDescriptionKey: "대상 계정을 선택하세요."])
        }
        if !sendPush && !showPopup {
            throw NSError(domain: "Notice", code: -1, userInfo: [NSLocalizedDescriptionKey: "PUSH 또는 로그인 팝업을 하나 이상 선택하세요."])
        }

        let imageURL = try await uploadNoticeImage(imageData)
        let payload: [String: Any] = [
            "action": "send",
            "target_scope": scope,
            "target_camps": camps,
            "target_user_ids": userIDs,
            "notice_type": type,
            "title": title.trimmed,
            "body": body.trimmed,
            "send_push": sendPush,
            "show_as_popup": showPopup,
            "popup_image_url": imageURL,
            "popup_allow_dismiss": allowDismiss,
            "require_ack": requireAck
        ]
        _ = try await callEdgeFunction("app-notice-dispatch", payload: payload)
        await load()
    }

    private func uploadNoticeImage(_ data: Data?) async throws -> String {
        guard let data else { return "" }
        guard data.count <= 10 * 1024 * 1024 else {
            throw NSError(domain: "NoticeImage", code: -1, userInfo: [NSLocalizedDescriptionKey: "이미지는 10MB 이하만 등록할 수 있습니다."])
        }

        let auth = try await SupabaseService.shared.client.auth.session
        let userID = session.userID.uuidString.lowercased()
        let path = "notices/\(userID)/\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.lowercased()).jpg"
        let encodedPath = path.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }.joined(separator: "/")
        let url = AppConfig.supabaseURL
            .appendingPathComponent("storage/v1/object/app-notice-images")
            .appendingPathComponent(encodedPath)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.timeoutInterval = 30
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("false", forHTTPHeaderField: "x-upsert")

        let (_, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else {
            throw NSError(domain: "NoticeImage", code: code, userInfo: [NSLocalizedDescriptionKey: "공지 이미지 업로드 실패 (\(code))"])
        }

        return AppConfig.supabaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + "/storage/v1/object/public/app-notice-images/" + path
    }

    private func callEdgeFunction(_ name: String, payload: [String: Any]) async throws -> [String: Any] {
        let auth = try await SupabaseService.shared.client.auth.session
        let url = AppConfig.supabaseURL.appendingPathComponent("functions/v1/\(name)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(code) else {
            let text = Self.text(object["error"])
            throw NSError(domain: "Notice", code: code, userInfo: [NSLocalizedDescriptionKey: text.isEmpty ? "공지 요청 실패 (\(code))" : text])
        }
        return object
    }

    func saveTask(
        existing: OperationTask?, categoryID: String, title: String, body: String,
        camp: String, wave: String, status: String, priority: String,
        targetVersion: String, dueDate: String
    ) async throws {
        let payload: [String: Any] = [
            "category_id": categoryID.nilIfBlank,
            "title": title.trimmed,
            "body": body.nilIfBlank,
            "camp_code": camp.nilIfBlank,
            "wave": wave,
            "status": status.isEmpty ? "planned" : status,
            "priority": priority.isEmpty ? "normal" : priority,
            "target_version": targetVersion.nilIfBlank,
            "due_date": dueDate.nilIfBlank
        ]
        _ = try await call(existing == nil ? "tasks" : "tasks/\(existing!.id)", method: existing == nil ? "POST" : "PATCH", body: payload)
        await load()
    }

    func saveIssue(
        existing: OperationIssue?, categoryID: String, title: String, body: String,
        camp: String, wave: String, personName: String, severity: String,
        status: String, resignationNoticeDate: String, resignationLastDate: String?
    ) async throws {
        let isResignation = categoryCode(id: categoryID) == "resignation"
        let payload: [String: Any] = [
            "category_id": categoryID.nilIfBlank,
            "title": title.trimmed,
            "body": body.nilIfBlank,
            "camp_code": camp.nilIfBlank,
            "wave": wave,
            "person_name_snapshot": personName.nilIfBlank,
            "severity": severity.isEmpty ? "normal" : severity,
            "status": status.isEmpty ? "open" : status,
            "resignation_notice_date": isResignation ? resignationNoticeDate.nilIfBlank : NSNull(),
            "resignation_last_work_date": isResignation ? (resignationLastDate.map { $0 as Any } ?? NSNull()) : NSNull()
        ]
        _ = try await call(existing == nil ? "issues" : "issues/\(existing!.id)", method: existing == nil ? "POST" : "PATCH", body: payload)
        await load()
    }

    private func fetchVersionRows() async throws -> [OperationSummaryRow] {
        let client = SupabaseService.shared.client
        let minimums: [AppMinimumVersionRow] = try await client
            .from("app_min_versions")
            .select("platform,min_build,min_version,is_force_update,updated_at")
            .order("platform", ascending: true)
            .execute()
            .value
        let sources: [AppSourceVersionRow] = try await client
            .from("app_source_versions")
            .select("platform,build,version,updated_at")
            .order("platform", ascending: true)
            .execute()
            .value

        let platforms = Array(Set(minimums.map(\.platform) + sources.map(\.platform))).sorted()
        return platforms.map { platform in
            let minimum = minimums.first { $0.platform == platform }
            let source = sources.first { $0.platform == platform }
            let display = platform.lowercased() == "ios" ? "iOS" :
                (platform.lowercased() == "android" ? "Android" : platform)
            let sourceText = source.map { "소스 v\($0.version) (\($0.build))" } ?? "소스 정보 없음"
            let minimumText = minimum.map { "최소 v\($0.minVersion) (\($0.minBuild))" } ?? "최소 버전 미설정"
            let policyText = minimum?.isForceUpdate == true ? "필수 업데이트" : "강제 업데이트 해제"
            return OperationSummaryRow(
                id: "version-\(platform)",
                title: display,
                meta: [sourceText, minimumText, policyText].joined(separator: " · "),
                body: [
                    source.map { "소스 갱신 \($0.updatedAt.shortDateTime)" },
                    minimum.map { "정책 갱신 \($0.updatedAt.shortDateTime)" }
                ].compactMap { $0 }.joined(separator: " · "),
                accent: minimum?.isForceUpdate == true ? .red : .blue
            )
        }
    }

    private func call(_ path: String, method: String, body: [String: Any]?) async throws -> [String: Any] {
        let auth = try await SupabaseService.shared.client.auth.session
        var request = URLRequest(url: URL(string: "https://home-system.brain-0f6.workers.dev/api/\(path)")!)
        request.httpMethod = method
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(code), Self.bool(object["ok"]) else {
            let errorText = Self.text(object["error"])
            throw NSError(
                domain: "OperationsBoard",
                code: code,
                userInfo: [NSLocalizedDescriptionKey: errorText.isEmpty ? "운영 업무 요청 실패 (\(code))" : errorText]
            )
        }
        return object["data"] as? [String: Any] ?? [:]
    }

    private static func dictionaries(_ value: Any?) -> [[String: Any]] {
        value as? [[String: Any]] ?? []
    }

    private static func realtime(_ value: Any?) -> [OperationSummaryRow] {
        guard let row = value as? [String: Any] else { return [] }
        let delivery = Int(text(row["delivery_total"])) ?? 0
        let completed = Int(text(row["delivery_completed"])) ?? 0
        return [OperationSummaryRow(
            id: "realtime",
            title: "배송 현황",
            meta: "캠프 \(text(row["camp_count"]))곳 · 기사 \(text(row["driver_count"]))명 · 주간 \(text(row["day_count"]))명 · 야간 \(text(row["night_count"]))명",
            body: "배송 \(completed)/\(delivery) · 완료율 \(text(row["delivery_rate"]))% · 반품 \(text(row["return_collected"])) · 프백 \(text(row["freshbag_collected"]))",
            accent: .blue
        )]
    }

    private static func memos(_ value: Any?) -> [OperationSummaryRow] {
        dictionaries(value).prefix(20).map {
            OperationSummaryRow(
                id: "memo-" + text($0["id"]),
                title: "메모",
                meta: "수정 " + text($0["updated_at"] ?? $0["created_at"]).shortDateTime,
                body: text($0["body"]),
                accent: .blue
            )
        }
    }

    private static func workflows(_ value: Any?) -> [OperationSummaryRow] {
        dictionaries(value).filter { !bool($0["is_archived"]) }.prefix(20).map {
            let meta = [
                text($0["status"]).isEmpty ? "진행중" : text($0["status"]),
                text($0["camp_code"]).isEmpty ? "공통" : text($0["camp_code"]),
                text($0["wave"]), text($0["assignee_name"]),
                text($0["due_date"]).isEmpty ? "" : "마감 " + text($0["due_date"])
            ].filter { !$0.isEmpty }.joined(separator: " · ")
            return OperationSummaryRow(
                id: "workflow-" + text($0["id"]),
                title: text($0["subject_name"]).isEmpty ? "운영 프로세스" : text($0["subject_name"]),
                meta: meta,
                body: text($0["notes"]),
                accent: .purple
            )
        }
    }

    private static func completed(_ tasks: Any?, _ issues: Any?) -> [OperationSummaryRow] {
        let taskRows = dictionaries(tasks).filter { ["completed", "cancelled"].contains(text($0["status"])) }
        let issueRows = dictionaries(issues).filter { ["resolved", "closed"].contains(text($0["status"])) }
        let a = taskRows.prefix(10).map {
            OperationSummaryRow(
                id: "completed-task-" + text($0["id"]),
                title: text($0["title"]),
                meta: "업무 · " + text($0["status"]) + " · " + text($0["updated_at"]).shortDateTime,
                body: text($0["body"]), accent: .green
            )
        }
        let b = issueRows.prefix(10).map {
            OperationSummaryRow(
                id: "completed-issue-" + text($0["id"]),
                title: text($0["title"]),
                meta: "이슈 · " + text($0["status"]) + " · " + text($0["updated_at"]).shortDateTime,
                body: text($0["body"]), accent: .green
            )
        }
        return Array(a) + Array(b)
    }

    private static func people(_ value: Any?) -> [OperationSummaryRow] {
        dictionaries(value).prefix(40).map {
            let state = text($0["status"]).isEmpty ? "미가입" : text($0["status"])
            let push = text($0["push_status"]).isEmpty ? "미확인" : text($0["push_status"])
            let devices = text($0["active_device_count"]).isEmpty ? "0" : text($0["active_device_count"])
            let meta = [
                text($0["position_title"]), text($0["camp_code"]), text($0["wave"]),
                "앱 " + state, "기기 " + devices + "대", "알림 " + push
            ].filter { !$0.isEmpty }.joined(separator: " · ")
            return OperationSummaryRow(
                id: "person-" + (text($0["user_id"]).isEmpty ? text($0["pk_id"]) : text($0["user_id"])),
                title: text($0["person_name"]).isEmpty ? "이름 미등록" : text($0["person_name"]),
                meta: meta, body: "", accent: state == "active" ? .green : .gray
            )
        }
    }

    private static func audit(_ value: Any?) -> [OperationSummaryRow] {
        dictionaries(value).prefix(30).map {
            OperationSummaryRow(
                id: "audit-" + text($0["id"]),
                title: text($0["action"]).isEmpty ? "변경" : text($0["action"]),
                meta: [text($0["table_name"]), text($0["row_id"]), text($0["created_at"]).shortDateTime]
                    .filter { !$0.isEmpty }.joined(separator: " · "),
                body: text($0["actor_user_id"]),
                accent: .gray
            )
        }
    }

    private static func notices(_ value: Any?) -> [OperationNotice] {
        (value as? [[String: Any]] ?? []).map {
            OperationNotice(
                id: text($0["id"]),
                title: text($0["title"]),
                body: text($0["body"]),
                noticeType: text($0["notice_type"]),
                createdAt: text($0["created_at"])
            )
        }
    }

    private static func tasks(_ value: Any?) -> [OperationTask] {
        (value as? [[String: Any]] ?? []).map {
            OperationTask(
                id: text($0["id"]), categoryID: text($0["category_id"]),
                title: text($0["title"]), body: text($0["body"]),
                campCode: text($0["camp_code"]), wave: text($0["wave"]),
                status: text($0["status"]), priority: text($0["priority"]),
                targetVersion: text($0["target_version"]), dueDate: text($0["due_date"]),
                isArchived: bool($0["is_archived"])
            )
        }
    }

    private static func issues(_ value: Any?) -> [OperationIssue] {
        (value as? [[String: Any]] ?? []).map {
            OperationIssue(
                id: text($0["id"]), categoryID: text($0["category_id"]),
                title: text($0["title"]), body: text($0["body"]),
                campCode: text($0["camp_code"]), wave: text($0["wave"]),
                personName: text($0["person_name_snapshot"]),
                severity: text($0["severity"]), status: text($0["status"]),
                resignationNoticeDate: text($0["resignation_notice_date"]),
                isArchived: bool($0["is_archived"])
            )
        }
    }

    private static func categories(_ value: Any?) -> [OperationCategory] {
        (value as? [[String: Any]] ?? []).map {
            OperationCategory(id: text($0["id"]), name: text($0["name"]), code: text($0["code"]))
        }
    }

    fileprivate static func text(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        let text = (value as? String ?? String(describing: value)).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || ["null", "undefined", "nan"].contains(text.lowercased()) { return "" }
        return text
    }

    fileprivate static func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return ["true", "1", "y", "yes"].contains(text(value).lowercased())
    }
}

@MainActor
private final class NoticeBoardStore: ObservableObject {
    @Published var notices: [OperationNotice] = []
    @Published var loading = false
    @Published var message: String?

    func load() async {
        loading = true
        defer { loading = false }
        do { notices = try await Self.fetchNotices() }
        catch { message = error.localizedDescription }
    }

    static func fetchNotices() async throws -> [OperationNotice] {
        let auth = try await SupabaseService.shared.client.auth.session
        var c = URLComponents(url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/app_notices"), resolvingAgainstBaseURL: false)!
        c.query = "select=id,title,body,notice_type,created_at&is_active=eq.true&order=created_at.desc&limit=100"
        var request = URLRequest(url: c.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else {
            throw NSError(domain: "NoticeBoard", code: code, userInfo: [NSLocalizedDescriptionKey: "공지 조회 실패 (\(code))"])
        }
        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return rows.map {
            OperationNotice(
                id: OperationsBoardStore.text($0["id"]),
                title: OperationsBoardStore.text($0["title"]),
                body: OperationsBoardStore.text($0["body"]),
                noticeType: OperationsBoardStore.text($0["notice_type"]),
                createdAt: OperationsBoardStore.text($0["created_at"])
            )
        }
    }
}

private struct OperationSummaryRow: Identifiable {
    let id: String
    let title: String
    let meta: String
    let body: String
    let accent: Color
}

private struct AppMinimumVersionRow: Decodable {
    let platform: String
    let minBuild: Int
    let minVersion: String
    let isForceUpdate: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case platform
        case minBuild = "min_build"
        case minVersion = "min_version"
        case isForceUpdate = "is_force_update"
        case updatedAt = "updated_at"
    }
}

private struct AppSourceVersionRow: Decodable {
    let platform: String
    let build: Int
    let version: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case platform, build, version
        case updatedAt = "updated_at"
    }
}

private struct NoticeTargetCamp: Identifiable {
    var id: String { camp }
    let camp: String
    let registeredUsers: Int
}

private struct NoticeTargetAccount: Identifiable {
    var id: String { userID }
    let userID: String
    let displayName: String
    let email: String
    let camp: String
}

private struct OperationNotice: Identifiable {
    let id: String
    let title: String
    let body: String
    let noticeType: String
    let createdAt: String

    var typeLabel: String {
        switch noticeType {
        case "emergency": return "긴급"
        case "important": return "중요"
        default: return "일반"
        }
    }
}

private struct OperationTask: Identifiable {
    let id: String
    let categoryID: String
    let title: String
    let body: String
    let campCode: String
    let wave: String
    let status: String
    let priority: String
    let targetVersion: String
    let dueDate: String
    let isArchived: Bool

    var statusLabel: String {
        switch status {
        case "in_progress": return "진행중"
        case "completed": return "완료"
        default: return "대기"
        }
    }
}

private struct OperationIssue: Identifiable {
    let id: String
    let categoryID: String
    let title: String
    let body: String
    let campCode: String
    let wave: String
    let personName: String
    let severity: String
    let status: String
    let resignationNoticeDate: String
    let isArchived: Bool

    var statusLabel: String {
        switch status {
        case "monitoring": return "진행중"
        case "resolved": return "해결"
        case "closed": return "종료"
        default: return "확인필요"
        }
    }
}

private struct OperationCategory: Identifiable {
    let id: String
    let name: String
    let code: String
}

private enum OperationsDate {
    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfBlank: Any { trimmed.isEmpty ? NSNull() : trimmed }
    var shortDateTime: String { replacingOccurrences(of: "T", with: " ").prefix(16).description }
}

