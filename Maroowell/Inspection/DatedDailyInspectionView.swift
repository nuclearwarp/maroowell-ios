import SwiftUI

struct DatedDailyInspectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = InspectionStore.shared

    let date: Date

    @State private var profile = InspectionStore.shared.loadProfile()
    @State private var signature = InspectionStore.shared.loadSignature()
    @State private var statuses = Array(repeating: "", count: InspectionSchema.items.count)
    @State private var actionNote = ""
    @State private var showSignatureSheet = false
    @State private var showDeleteConfirm = false
    @State private var showMessage = false
    @State private var message = ""

    private var dayNumber: Int { store.dayNumber(for: date) }
    private var savedRecord: InspectionDayRecord? { store.loadDay(date) }
    private var isFuture: Bool { store.isFuture(date) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                dateCard
                profileCard
                checklistCard
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(MaroowellTheme.background)
        .navigationTitle("일상점검")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
        .alert("마루웰", isPresented: $showMessage) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(message)
        }
        .confirmationDialog("일상점검 삭제", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { deleteRecord() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(dayNumber)일에 저장된 일상점검을 삭제할까요?")
        }
        .sheet(isPresented: $showSignatureSheet) {
            signatureSheet
        }
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date.formatted(.dateTime.year().month().day().weekday(.wide).locale(Locale(identifier: "ko_KR"))))
                .font(.title2.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)

            HStack(spacing: 8) {
                statusPill(savedRecord != nil ? "점검 완료" : "점검 미완료", color: savedRecord != nil ? .green : .red)
                if isFuture {
                    statusPill("미래 일자", color: .gray)
                }
            }

            if let savedRecord {
                Text("저장: \(savedRecord.savedAt.formatted(.dateTime.hour().minute().locale(Locale(identifier: "ko_KR"))))")
                    .font(.caption)
                    .foregroundStyle(MaroowellTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .datedInspectionCard()
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("점검표 정보")
                .font(.headline.weight(.black))

            if profile.isComplete {
                Text("\(profile.carrierName) · \(profile.vehicleNumber) · \(profile.driverName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MaroowellTheme.ink)
            } else {
                Text("운송사업자명, 차량번호, 운수종사자명을 입력해주세요.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            field("운송사업자명", placeholder: "마루웰", text: $profile.carrierName)
            field("차량번호", placeholder: "경기00아0000", text: $profile.vehicleNumber)
            field("운수종사자명", placeholder: "이쿠팡", text: $profile.driverName)

            Button {
                showSignatureSheet = true
            } label: {
                Label(signature.isEmpty ? "점검자 서명 등록" : "점검자 서명 수정", systemImage: "signature")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .datedInspectionCard()
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("운행 전 일상점검")
                        .font(.headline.weight(.black))
                    Text("11개 항목을 O / X로 선택하세요.")
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                Button("전체 양호") {
                    guard !isFuture else { return }
                    statuses = Array(repeating: "O", count: InspectionSchema.items.count)
                }
                .font(.caption.weight(.black))
                .disabled(isFuture)
            }

            ForEach(Array(InspectionSchema.groups.enumerated()), id: \.offset) { groupIndex, group in
                Text(group.title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.red)
                    .padding(.top, 4)

                ForEach(Array(group.items.enumerated()), id: \.offset) { itemIndex, item in
                    let index = InspectionSchema.globalIndex(groupIndex: groupIndex, itemIndex: itemIndex)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(index + 1). \(item)")
                            .font(.subheadline)
                            .foregroundStyle(MaroowellTheme.ink)
                        HStack(spacing: 8) {
                            statusButton("O", index: index, color: .green)
                            statusButton("X", index: index, color: .red)
                        }
                    }
                    .padding(.vertical, 5)
                    Divider()
                }
            }

            TextField("불량상태 조치 기록", text: $actionNote, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(MaroowellTheme.border, lineWidth: 1) }
                .disabled(isFuture)

            Button {
                saveRecord()
            } label: {
                Text(isFuture ? "미래 일자는 점검할 수 없습니다" : (savedRecord == nil ? "일상점검 저장" : "일상점검 수정 저장"))
                    .font(.headline.weight(.black))
                    .foregroundStyle(isFuture ? Color.secondary : MaroowellTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isFuture ? Color.gray.opacity(0.18) : MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isFuture)

            if savedRecord != nil {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text("이 날짜 일상점검 삭제")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .datedInspectionCard()
    }

    private var signatureSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("손가락으로 직접 서명하세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                SignaturePad(signature: $signature)
                HStack(spacing: 10) {
                    Button("지우기") { signature.clear() }
                        .buttonStyle(.bordered)
                    Button("저장") {
                        guard !signature.isEmpty else {
                            present("서명을 입력해주세요.")
                            return
                        }
                        store.saveSignature(signature)
                        showSignatureSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MaroowellTheme.yellow)
                    .foregroundStyle(MaroowellTheme.ink)
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("점검자 서명")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { showSignatureSheet = false }
                }
            }
        }
    }

    private func statusButton(_ value: String, index: Int, color: Color) -> some View {
        let active = statuses[index] == value
        return Button(value) {
            guard !isFuture else { return }
            statuses[index] = value
        }
        .font(.headline.weight(.black))
        .foregroundStyle(active ? Color.white : color)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(active ? color : Color.white, in: RoundedRectangle(cornerRadius: 11))
        .overlay { RoundedRectangle(cornerRadius: 11).stroke(color.opacity(0.45), lineWidth: 1) }
        .disabled(isFuture)
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MaroowellTheme.muted)
            TextField(placeholder, text: text)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(MaroowellTheme.border, lineWidth: 1) }
        }
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.black))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.10), in: Capsule())
    }

    private func load() {
        profile = store.loadProfile()
        signature = store.loadSignature()
        statuses = Array(repeating: "", count: InspectionSchema.items.count)
        if let record = store.loadDay(date) {
            for index in statuses.indices where record.statuses.indices.contains(index) {
                statuses[index] = record.statuses[index]
            }
            actionNote = record.actionNote
        } else {
            actionNote = ""
        }
    }

    private func saveRecord() {
        guard !isFuture else { return }
        guard profile.isComplete else {
            present("운송사업자명, 차량번호, 운수종사자명을 모두 입력해주세요.")
            return
        }
        guard !signature.isEmpty else {
            present("점검자 서명을 먼저 등록해주세요.")
            return
        }
        guard statuses.allSatisfy({ !$0.isEmpty }) else {
            present("11개 점검항목을 모두 선택해주세요.")
            return
        }
        if statuses.contains("X") && actionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            present("불량(X) 항목이 있으면 조치 기록을 입력해주세요.")
            return
        }

        store.saveProfile(profile)
        store.saveSignature(signature)
        store.saveDay(
            date,
            record: InspectionDayRecord(
                statuses: statuses,
                actionNote: actionNote.trimmingCharacters(in: .whitespacesAndNewlines),
                savedAt: .now
            )
        )
        present("\(dayNumber)일 점검 저장 완료")
    }

    private func deleteRecord() {
        store.deleteDay(date)
        statuses = Array(repeating: "", count: InspectionSchema.items.count)
        actionNote = ""
        present("\(dayNumber)일 일상점검을 삭제했습니다.")
    }

    private func present(_ text: String) {
        message = text
        showMessage = true
    }
}

private extension View {
    func datedInspectionCard() -> some View {
        self.background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(MaroowellTheme.border.opacity(0.85), lineWidth: 1)
            }
    }
}