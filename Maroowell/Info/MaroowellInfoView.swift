import Foundation
import SwiftUI

struct MaroowellInfoView: View {
    @StateObject private var store = MaroowellInfoStore()
    @State private var editorRow: MaroowellInfoRow?
    @State private var deleteTarget: MaroowellInfoRow?

    var body: some View {
        ZStack {
            MaroowellTheme.background.ignoresSafeArea()

            if store.isLoading && store.rows.isEmpty {
                ProgressView("마루웰 정보를 불러오는 중...")
            } else {
                content
            }
        }
        .navigationTitle("마루웰 정보")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorRow = .blank
                } label: {
                    Label("사람 추가", systemImage: "person.badge.plus")
                }
                .disabled(store.isSaving)
            }
        }
        .task {
            if store.rows.isEmpty {
                await store.load()
            }
        }
        .refreshable {
            await store.load()
        }
        .sheet(item: $editorRow) { row in
            MaroowellInfoEditor(row: row) { edited in
                await store.save(edited)
            }
        }
        .confirmationDialog(
            "삭제할까요?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                guard let row = deleteTarget else { return }
                deleteTarget = nil
                Task { await store.delete(row) }
            }
            Button("취소", role: .cancel) { deleteTarget = nil }
        } message: {
            Text(deleteTarget?.personName.nilIfBlank ?? "선택한 인원")
        }
        .alert("마루웰 정보", isPresented: Binding(
            get: { store.alertMessage != nil },
            set: { if !$0 { store.alertMessage = nil } }
        )) {
            Button("확인", role: .cancel) { store.alertMessage = nil }
        } message: {
            Text(store.alertMessage ?? "")
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                controlCard

                if store.filteredRows.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(MaroowellTheme.muted)
                        Text("조회 결과가 없습니다.")
                            .font(.headline.weight(.black))
                            .foregroundStyle(MaroowellTheme.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 50)
                } else {
                    ForEach(store.filteredRows) { row in
                        Button {
                            editorRow = row
                        } label: {
                            MaroowellInfoPersonCard(row: row)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteTarget = row
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
    }

    private var controlCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("인원 정보 관리")
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                    Text("웹 마루웰 정보와 같은 데이터를 조회·수정합니다.")
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                Text("\(store.filteredRows.count)명")
                    .font(.caption.weight(.black))
                    .foregroundStyle(MaroowellTheme.deepYellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MaroowellTheme.yellow.opacity(0.18), in: Capsule())
            }

            HStack(spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MaroowellTheme.muted)
                    TextField("이름 · 캠프 · ID · 차량번호 검색", text: $store.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                Button {
                    Task { await store.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .black))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(store.isLoading || store.isSaving)
            }

            Toggle("퇴사 포함", isOn: $store.includeResigned)
                .font(.subheadline.weight(.bold))
                .tint(MaroowellTheme.deepYellow)

            if store.isSaving {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("저장 중...")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MaroowellTheme.muted)
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }
}

private struct MaroowellInfoPersonCard: View {
    let row: MaroowellInfoRow

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle().fill(MaroowellTheme.yellow.opacity(0.18))
                    Image(systemName: "person.fill")
                        .foregroundStyle(MaroowellTheme.deepYellow)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(row.personName.nilIfBlank ?? "이름 미입력")
                            .font(.headline.weight(.black))
                            .foregroundStyle(MaroowellTheme.ink)
                        if let position = row.positionTitle.nilIfBlank {
                            Text(position)
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(row.isResigned ? Color.red : MaroowellTheme.deepYellow)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background((row.isResigned ? Color.red : MaroowellTheme.yellow).opacity(0.12), in: Capsule())
                        }
                    }
                    Text([row.campCode, row.wave].compactMap(\.nilIfBlank).joined(separator: " · ").nilIfBlank ?? "캠프/웨이브 미입력")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MaroowellTheme.muted)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(MaroowellTheme.muted.opacity(0.7))
            }

            HStack(spacing: 8) {
                infoChip(symbol: "person.text.rectangle", text: row.coupangID.nilIfBlank ?? "ID 없음")
                infoChip(symbol: "car.fill", text: row.vehiclePlateNumber.nilIfBlank ?? "차량 없음")
            }

            if let phone = row.contactPhone.nilIfBlank {
                Label(phone, systemImage: "phone.fill")
                    .font(.caption)
                    .foregroundStyle(MaroowellTheme.muted)
            }
        }
        .padding(14)
        .background(row.isResigned ? Color.red.opacity(0.035) : Color.white, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(row.isResigned ? Color.red.opacity(0.22) : MaroowellTheme.border, lineWidth: 1)
        }
    }

    private func infoChip(symbol: String, text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(MaroowellTheme.ink)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(MaroowellTheme.background, in: Capsule())
    }
}

private struct MaroowellInfoEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MaroowellInfoRow
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onSave: (MaroowellInfoRow) async -> Bool

    init(row: MaroowellInfoRow, onSave: @escaping (MaroowellInfoRow) async -> Bool) {
        _draft = State(initialValue: row)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    field("이름", text: $draft.personName)
                    field("연락처", text: $draft.contactPhone, keyboard: .phonePad)
                    field("직책", text: $draft.positionTitle)
                    field("Camp", text: $draft.campCode)
                    Picker("Wave", selection: $draft.wave) {
                        Text("미지정").tag("")
                        Text("주간").tag("주간")
                        Text("야간").tag("야간")
                        Text("주/야").tag("주/야")
                    }
                    field("Coupang ID", text: $draft.coupangID)
                    field("차량 번호", text: $draft.vehiclePlateNumber)
                }

                Section("자격 · 계정") {
                    field("주민번호", text: $draft.residentRegistrationNumber, keyboard: .numbersAndPunctuation)
                    field("운송자격증번호", text: $draft.transportQualificationNumber)
                    field("서브 계정", text: $draft.subAccountInfo)
                }

                Section("정산 · 사업자") {
                    field("급여 은행", text: $draft.payrollBankName)
                    field("급여 계좌", text: $draft.payrollAccountNumber, keyboard: .numbersAndPunctuation)
                    field("사업자 상호", text: $draft.businessName)
                    field("사업자 번호", text: $draft.businessRegistrationNumber, keyboard: .numbersAndPunctuation)
                    field("고정 수수료", text: $draft.fixedCommissionAmount, keyboard: .numbersAndPunctuation)
                    field("고정 단가", text: $draft.fixedUnitPrice, keyboard: .numbersAndPunctuation)
                    field("용차 수수료", text: $draft.dragonCarCommission)
                    Picker("고용산재", selection: $draft.employmentAccidentInsurance) {
                        Text("미지정").tag("")
                        Text("O").tag("O")
                        Text("X").tag("X")
                    }
                }

                Section("입사 · 안전 · 비상연락") {
                    field("입사일", text: $draft.hireDate, prompt: "YYYY-MM-DD")
                    field("안전보건교육 수료일", text: $draft.safetyHealthEducationCompletionDate, prompt: "YYYY-MM-DD")
                    field("비상 연락처", text: $draft.emergencyContactPhone, keyboard: .phonePad)
                    field("관계", text: $draft.emergencyContactRelationship)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(draft.pkID == nil ? "사람 추가" : (draft.personName.nilIfBlank ?? "정보 수정"))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("저장").fontWeight(.black)
                        }
                    }
                    .disabled(isSaving || draft.personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType = .default,
        prompt: String? = nil
    ) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            TextField(prompt ?? "", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            let ok = await onSave(draft)
            await MainActor.run {
                isSaving = false
                if ok {
                    dismiss()
                } else {
                    errorMessage = "저장하지 못했습니다. 잠시 후 다시 시도해주세요."
                }
            }
        }
    }
}

struct MaroowellUniformSizeView: View {
    private let sizes = ["S", "M", "L", "XL", "2XL", "3XL", "4XL"]

    @State private var personName = ""
    @State private var positionTitle = ""
    @State private var vestSize1 = ""
    @State private var vestSize2 = ""
    @State private var fleeceSize1 = ""
    @State private var fleeceSize2 = ""
    @State private var isTwoPersonTeam = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCard

                sizeSection(
                    title: "조끼 (하계용)",
                    subtitle: "하계 조끼 사이즈를 선택하세요.",
                    first: $vestSize1,
                    second: $vestSize2
                )

                sizeSection(
                    title: "후리스 (동계용)",
                    subtitle: "동계 후리스 사이즈를 선택하세요.",
                    first: $fleeceSize1,
                    second: $fleeceSize2
                )

                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView().controlSize(.small) }
                        Text(isSaving ? "저장 중..." : "사이즈 저장")
                            .font(.headline.weight(.black))
                        Spacer()
                    }
                    .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(MaroowellTheme.yellow)
                .foregroundStyle(MaroowellTheme.ink)
                .disabled(isSaving)

                if let message {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(message.contains("완료") ? Color.green : Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
        }
        .background(MaroowellTheme.background)
        .navigationTitle("지급품 사이즈")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView("사이즈 불러오는 중...")
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !personName.isEmpty {
                Text(positionTitle.isEmpty ? personName : "\(personName) \(positionTitle)님")
                    .font(.title3.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
            }
            Label(
                isTwoPersonTeam ? "2인 1조 · 품목별 최대 2개 선택" : "1인 운영 · 품목별 1개 선택",
                systemImage: isTwoPersonTeam ? "person.2.fill" : "person.fill"
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.blue)

            Text("저장된 사이즈는 주문용 정보로 계속 유지됩니다. 변경이 필요한 경우에만 다시 선택해 저장하세요.")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(MaroowellTheme.border) }
    }

    private func sizeSection(
        title: String,
        subtitle: String,
        first: Binding<String>,
        second: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)

            sizeSlot(
                label: isTwoPersonTeam ? "1번" : "사이즈",
                selection: first
            )

            if isTwoPersonTeam {
                sizeSlot(
                    label: "2번",
                    selection: second
                )
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(MaroowellTheme.border) }
    }

    private func sizeSlot(label: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(MaroowellTheme.muted)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(sizes, id: \.self) { size in
                    let selected = selection.wrappedValue == size
                    Button {
                        selection.wrappedValue = selected ? "" : size
                        message = nil
                    } label: {
                        Text(size)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(selected ? MaroowellTheme.ink : MaroowellTheme.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                selected ? MaroowellTheme.yellow : Color.white,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selected ? MaroowellTheme.deepYellow : MaroowellTheme.border)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(selection.wrappedValue.isEmpty ? "선택 안 함" : "선택: \(selection.wrappedValue)")
                .font(.caption.weight(.bold))
                .foregroundStyle(MaroowellTheme.muted)
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let row = try await request("mw_my_uniform_sizes", body: [:])
            personName = row.personName ?? ""
            positionTitle = row.positionTitle ?? ""
            isTwoPersonTeam = row.isTwoPersonTeam
            let vest = parse(row.summerVestSize)
            let fleece = parse(row.winterFleeceSize)
            vestSize1 = vest.indices.contains(0) ? vest[0] : ""
            vestSize2 = vest.indices.contains(1) ? vest[1] : ""
            fleeceSize1 = fleece.indices.contains(0) ? fleece[0] : ""
            fleeceSize2 = fleece.indices.contains(1) ? fleece[1] : ""
            if !isTwoPersonTeam {
                vestSize2 = ""
                fleeceSize2 = ""
            }
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        message = nil
        defer { isSaving = false }
        do {
            let row = try await request(
                "mw_update_my_uniform_sizes",
                body: [
                    "p_summer_vest_size": [vestSize1, isTwoPersonTeam ? vestSize2 : ""].filter { !$0.isEmpty }.joined(separator: ","),
                    "p_winter_fleece_size": [fleeceSize1, isTwoPersonTeam ? fleeceSize2 : ""].filter { !$0.isEmpty }.joined(separator: ",")
                ]
            )
            personName = row.personName ?? personName
            positionTitle = row.positionTitle ?? positionTitle
            isTwoPersonTeam = row.isTwoPersonTeam
            let vest = parse(row.summerVestSize)
            let fleece = parse(row.winterFleeceSize)
            vestSize1 = vest.indices.contains(0) ? vest[0] : ""
            vestSize2 = vest.indices.contains(1) ? vest[1] : ""
            fleeceSize1 = fleece.indices.contains(0) ? fleece[0] : ""
            fleeceSize2 = fleece.indices.contains(1) ? fleece[1] : ""
            if !isTwoPersonTeam {
                vestSize2 = ""
                fleeceSize2 = ""
            }
            message = "저장 완료"
        } catch {
            message = error.localizedDescription
        }
    }

    private func parse(_ raw: String?) -> [String] {
        (raw ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { sizes.contains($0) }
    }

    private func request(_ rpc: String, body: [String: String]) async throws -> UniformSizeRow {
        let session = try await SupabaseService.shared.client.auth.session
        var url = AppConfig.supabaseURL
        url.append(path: "rest/v1/rpc/\(rpc)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UniformSizeError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let backend = try? JSONDecoder().decode(UniformSizeBackendError.self, from: data)
            throw UniformSizeError.backend(backend?.message ?? backend?.error ?? "사이즈 요청 실패 (HTTP \(http.statusCode))")
        }
        let rows = try JSONDecoder().decode([UniformSizeRow].self, from: data)
        guard let row = rows.first else {
            throw UniformSizeError.backend("연결된 마루웰 인사정보를 찾지 못했습니다.")
        }
        return row
    }

    private struct UniformSizeRow: Decodable {
        let personName: String?
        let positionTitle: String?
        let summerVestSize: String?
        let winterFleeceSize: String?
        let isTwoPersonTeam: Bool

        enum CodingKeys: String, CodingKey {
            case personName = "person_name"
            case positionTitle = "position_title"
            case summerVestSize = "summer_vest_size"
            case winterFleeceSize = "winter_fleece_size"
            case isTwoPersonTeam = "is_two_person_team"
        }
    }

    private struct UniformSizeBackendError: Decodable {
        let error: String?
        let message: String?
    }

    private enum UniformSizeError: LocalizedError {
        case invalidResponse
        case backend(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "서버 응답을 확인하지 못했습니다."
            case .backend(let message): return message
            }
        }
    }
}

@MainActor
private final class MaroowellInfoStore: ObservableObject {
    @Published var rows: [MaroowellInfoRow] = []
    @Published var query = ""
    @Published var includeResigned = false
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var alertMessage: String?

    private let api = MaroowellInfoAPI()

    var filteredRows: [MaroowellInfoRow] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rows.filter { row in
            if !includeResigned && row.isResigned { return false }
            guard !q.isEmpty else { return true }
            return row.searchText.lowercased().contains(q)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            rows = try await api.list()
        } catch {
            alertMessage = MaroowellInfoAPI.friendly(error)
        }
    }

    func save(_ row: MaroowellInfoRow) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            if row.pkID == nil {
                _ = try await api.save(deleteIDs: [], updateRows: [], newRows: [row.payload])
            } else {
                _ = try await api.save(deleteIDs: [], updateRows: [row.payload], newRows: [])
            }
            rows = try await api.list()
            return true
        } catch {
            alertMessage = MaroowellInfoAPI.friendly(error)
            return false
        }
    }

    func delete(_ row: MaroowellInfoRow) async {
        guard let id = row.pkID else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await api.save(deleteIDs: [id], updateRows: [], newRows: [])
            rows.removeAll { $0.pkID == id }
        } catch {
            alertMessage = MaroowellInfoAPI.friendly(error)
        }
    }
}

private struct MaroowellInfoAPI {
    private static let baseURL = URL(string: "https://maroowellinfo.brain-0f6.workers.dev")!
    private let client = SupabaseService.shared.client

    func list() async throws -> [MaroowellInfoRow] {
        let response: ListResponse = try await request(path: "/info/list", body: EmptyBody())
        return response.rows
    }

    func save(
        deleteIDs: [Int64],
        updateRows: [MaroowellInfoPayload],
        newRows: [MaroowellInfoPayload]
    ) async throws -> SaveResponse {
        try await request(
            path: "/info/save",
            body: SaveRequest(deleteIds: deleteIDs, updateRows: updateRows, newRows: newRows)
        )
    }

    private func request<Response: Decodable, Body: Encodable>(path: String, body: Body) async throws -> Response {
        let authSession = try await client.auth.session
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let backend = try? JSONDecoder().decode(BackendError.self, from: data)
            throw APIError.backend(status: http.statusCode, message: backend?.message)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decode(error.localizedDescription)
        }
    }

    static func friendly(_ error: Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .backend(let status, let message):
                if status == 401 || status == 403 {
                    return "마루웰 정보 접근 권한 또는 로그인 세션을 확인해주세요."
                }
                return message?.nilIfBlank ?? "마루웰 정보 서버 오류 (HTTP \(status))"
            case .invalidResponse:
                return "마루웰 정보 서버 응답을 확인하지 못했습니다."
            case .decode:
                return "마루웰 정보 응답 형식이 올바르지 않습니다."
            }
        }
        return error.localizedDescription
    }

    private struct EmptyBody: Encodable {}

    private struct ListResponse: Decodable {
        let rows: [MaroowellInfoRow]
    }

    struct SaveResponse: Decodable {
        let deleted: Int?
        let updated: Int?
        let inserted: Int?
    }

    private struct SaveRequest: Encodable {
        let deleteIds: [Int64]
        let updateRows: [MaroowellInfoPayload]
        let newRows: [MaroowellInfoPayload]
    }

    private struct BackendError: Decodable {
        let error: String?
        let message: String?
        let detail: String?

        var resolved: String? { error ?? message ?? detail }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            error = try c.decodeIfPresent(String.self, forKey: .error)
            message = try c.decodeIfPresent(String.self, forKey: .message) ?? error ?? (try c.decodeIfPresent(String.self, forKey: .detail))
            detail = try c.decodeIfPresent(String.self, forKey: .detail)
        }

        private enum CodingKeys: String, CodingKey { case error, message, detail }
    }

    private enum APIError: Error {
        case backend(status: Int, message: String?)
        case invalidResponse
        case decode(String)
    }
}

private struct MaroowellInfoRow: Decodable, Identifiable, Equatable {
    var pkID: Int64?
    var personName: String
    var contactPhone: String
    var positionTitle: String
    var campCode: String
    var wave: String
    var coupangID: String
    var vehiclePlateNumber: String
    var residentRegistrationNumber: String
    var transportQualificationNumber: String
    var subAccountInfo: String
    var payrollBankName: String
    var payrollAccountNumber: String
    var businessName: String
    var businessRegistrationNumber: String
    var hireDate: String
    var safetyHealthEducationCompletionDate: String
    var emergencyContactPhone: String
    var emergencyContactRelationship: String
    var fixedCommissionAmount: String
    var fixedUnitPrice: String
    var dragonCarCommission: String
    var employmentAccidentInsurance: String
    var isResignedFlag: Bool
    private let localID: UUID

    var id: String { pkID.map(String.init) ?? localID.uuidString }
    var isResigned: Bool { isResignedFlag }

    var searchText: String {
        [personName, contactPhone, positionTitle, campCode, wave, coupangID, vehiclePlateNumber, businessName]
            .joined(separator: " ")
    }

    var payload: MaroowellInfoPayload {
        MaroowellInfoPayload(
            pkId: pkID,
            personName: personName.nilIfBlank,
            contactPhone: contactPhone.nilIfBlank,
            positionTitle: positionTitle.nilIfBlank,
            campCode: campCode.nilIfBlank,
            wave: wave.nilIfBlank,
            coupangId: coupangID.nilIfBlank,
            vehiclePlateNumber: vehiclePlateNumber.nilIfBlank,
            residentRegistrationNumber: residentRegistrationNumber.nilIfBlank,
            transportQualificationNumber: transportQualificationNumber.nilIfBlank,
            subAccountInfo: subAccountInfo.nilIfBlank,
            payrollBankName: payrollBankName.nilIfBlank,
            payrollAccountNumber: payrollAccountNumber.nilIfBlank,
            businessName: businessName.nilIfBlank,
            businessRegistrationNumber: businessRegistrationNumber.nilIfBlank,
            hireDate: hireDate.nilIfBlank,
            safetyHealthEducationCompletionDate: safetyHealthEducationCompletionDate.nilIfBlank,
            emergencyContactPhone: emergencyContactPhone.nilIfBlank,
            emergencyContactRelationship: emergencyContactRelationship.nilIfBlank,
            fixedCommissionAmount: fixedCommissionAmount.nilIfBlank,
            fixedUnitPrice: fixedUnitPrice.nilIfBlank,
            dragonCarCommission: dragonCarCommission.nilIfBlank,
            employmentAccidentInsurance: employmentAccidentInsurance.nilIfBlank
        )
    }

    static var blank: MaroowellInfoRow {
        MaroowellInfoRow(
            pkID: nil,
            personName: "",
            contactPhone: "",
            positionTitle: "",
            campCode: "",
            wave: "",
            coupangID: "",
            vehiclePlateNumber: "",
            residentRegistrationNumber: "",
            transportQualificationNumber: "",
            subAccountInfo: "",
            payrollBankName: "",
            payrollAccountNumber: "",
            businessName: "",
            businessRegistrationNumber: "",
            hireDate: "",
            safetyHealthEducationCompletionDate: "",
            emergencyContactPhone: "",
            emergencyContactRelationship: "",
            fixedCommissionAmount: "",
            fixedUnitPrice: "",
            dragonCarCommission: "",
            employmentAccidentInsurance: "",
            isResignedFlag: false,
            localID: UUID()
        )
    }

    private enum CodingKeys: String, CodingKey {
        case pkID = "pk_id"
        case personName = "person_name"
        case contactPhone = "contact_phone"
        case positionTitle = "position_title"
        case campCode = "camp_code"
        case wave
        case coupangID = "coupang_id"
        case vehiclePlateNumber = "vehicle_plate_number"
        case residentRegistrationNumber = "resident_registration_number"
        case transportQualificationNumber = "transport_qualification_number"
        case subAccountInfo = "sub_account_info"
        case payrollBankName = "payroll_bank_name"
        case payrollAccountNumber = "payroll_account_number"
        case businessName = "business_name"
        case businessRegistrationNumber = "business_registration_number"
        case hireDate = "hire_date"
        case safetyHealthEducationCompletionDate = "safety_health_education_completion_date"
        case emergencyContactPhone = "emergency_contact_phone"
        case emergencyContactRelationship = "emergency_contact_relationship"
        case fixedCommissionAmount = "fixed_commission_amount"
        case fixedUnitPrice = "fixed_unit_price"
        case dragonCarCommission = "dragon_car_commission"
        case employmentAccidentInsurance = "employment_accident_insurance"
        case isResignedFlag = "is_resigned"
    }

    init(
        pkID: Int64?, personName: String, contactPhone: String, positionTitle: String,
        campCode: String, wave: String, coupangID: String, vehiclePlateNumber: String,
        residentRegistrationNumber: String, transportQualificationNumber: String,
        subAccountInfo: String, payrollBankName: String, payrollAccountNumber: String,
        businessName: String, businessRegistrationNumber: String, hireDate: String,
        safetyHealthEducationCompletionDate: String, emergencyContactPhone: String,
        emergencyContactRelationship: String, fixedCommissionAmount: String,
        fixedUnitPrice: String, dragonCarCommission: String, employmentAccidentInsurance: String,
        isResignedFlag: Bool = false,
        localID: UUID = UUID()
    ) {
        self.pkID = pkID
        self.personName = personName
        self.contactPhone = contactPhone
        self.positionTitle = positionTitle
        self.campCode = campCode
        self.wave = wave
        self.coupangID = coupangID
        self.vehiclePlateNumber = vehiclePlateNumber
        self.residentRegistrationNumber = residentRegistrationNumber
        self.transportQualificationNumber = transportQualificationNumber
        self.subAccountInfo = subAccountInfo
        self.payrollBankName = payrollBankName
        self.payrollAccountNumber = payrollAccountNumber
        self.businessName = businessName
        self.businessRegistrationNumber = businessRegistrationNumber
        self.hireDate = hireDate
        self.safetyHealthEducationCompletionDate = safetyHealthEducationCompletionDate
        self.emergencyContactPhone = emergencyContactPhone
        self.emergencyContactRelationship = emergencyContactRelationship
        self.fixedCommissionAmount = fixedCommissionAmount
        self.fixedUnitPrice = fixedUnitPrice
        self.dragonCarCommission = dragonCarCommission
        self.employmentAccidentInsurance = employmentAccidentInsurance
        self.isResignedFlag = isResignedFlag
        self.localID = localID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pkID = try c.decodeIfPresent(Int64.self, forKey: .pkID)
        personName = Self.text(c, .personName)
        contactPhone = Self.text(c, .contactPhone)
        positionTitle = Self.text(c, .positionTitle)
        campCode = Self.text(c, .campCode)
        wave = Self.text(c, .wave)
        coupangID = Self.text(c, .coupangID)
        vehiclePlateNumber = Self.text(c, .vehiclePlateNumber)
        residentRegistrationNumber = Self.text(c, .residentRegistrationNumber)
        transportQualificationNumber = Self.text(c, .transportQualificationNumber)
        subAccountInfo = Self.text(c, .subAccountInfo)
        payrollBankName = Self.text(c, .payrollBankName)
        payrollAccountNumber = Self.text(c, .payrollAccountNumber)
        businessName = Self.text(c, .businessName)
        businessRegistrationNumber = Self.text(c, .businessRegistrationNumber)
        hireDate = Self.text(c, .hireDate)
        safetyHealthEducationCompletionDate = Self.text(c, .safetyHealthEducationCompletionDate)
        emergencyContactPhone = Self.text(c, .emergencyContactPhone)
        emergencyContactRelationship = Self.text(c, .emergencyContactRelationship)
        fixedCommissionAmount = Self.text(c, .fixedCommissionAmount)
        fixedUnitPrice = Self.text(c, .fixedUnitPrice)
        dragonCarCommission = Self.text(c, .dragonCarCommission)
        employmentAccidentInsurance = Self.text(c, .employmentAccidentInsurance)
        isResignedFlag = (try? c.decodeIfPresent(Bool.self, forKey: .isResignedFlag)) ?? false
        localID = UUID()
    }

    private static func text(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String {
        if let value = try? c.decode(String.self, forKey: key) { return value }
        if let value = try? c.decode(Int.self, forKey: key) { return String(value) }
        if let value = try? c.decode(Double.self, forKey: key) { return String(value) }
        return ""
    }
}

private struct MaroowellInfoPayload: Encodable {
    let pkId: Int64?
    let personName: String?
    let contactPhone: String?
    let positionTitle: String?
    let campCode: String?
    let wave: String?
    let coupangId: String?
    let vehiclePlateNumber: String?
    let residentRegistrationNumber: String?
    let transportQualificationNumber: String?
    let subAccountInfo: String?
    let payrollBankName: String?
    let payrollAccountNumber: String?
    let businessName: String?
    let businessRegistrationNumber: String?
    let hireDate: String?
    let safetyHealthEducationCompletionDate: String?
    let emergencyContactPhone: String?
    let emergencyContactRelationship: String?
    let fixedCommissionAmount: String?
    let fixedUnitPrice: String?
    let dragonCarCommission: String?
    let employmentAccidentInsurance: String?

    enum CodingKeys: String, CodingKey {
        case pkId = "pk_id"
        case personName = "person_name"
        case contactPhone = "contact_phone"
        case positionTitle = "position_title"
        case campCode = "camp_code"
        case wave
        case coupangId = "coupang_id"
        case vehiclePlateNumber = "vehicle_plate_number"
        case residentRegistrationNumber = "resident_registration_number"
        case transportQualificationNumber = "transport_qualification_number"
        case subAccountInfo = "sub_account_info"
        case payrollBankName = "payroll_bank_name"
        case payrollAccountNumber = "payroll_account_number"
        case businessName = "business_name"
        case businessRegistrationNumber = "business_registration_number"
        case hireDate = "hire_date"
        case safetyHealthEducationCompletionDate = "safety_health_education_completion_date"
        case emergencyContactPhone = "emergency_contact_phone"
        case emergencyContactRelationship = "emergency_contact_relationship"
        case fixedCommissionAmount = "fixed_commission_amount"
        case fixedUnitPrice = "fixed_unit_price"
        case dragonCarCommission = "dragon_car_commission"
        case employmentAccidentInsurance = "employment_accident_insurance"
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
