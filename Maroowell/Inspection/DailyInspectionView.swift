import SwiftUI
import UIKit

struct DailyInspectionView: View {
    @ObservedObject private var store = InspectionStore.shared

    @State private var month = InspectionStore.shared.startOfMonth(Date())
    @State private var selectedDay = Calendar.current.component(.day, from: Date())
    @State private var profile = InspectionStore.shared.loadProfile()
    @State private var signature = InspectionStore.shared.loadSignature()
    @State private var statuses = Array(repeating: "", count: InspectionSchema.items.count)
    @State private var actionNote = ""
    @State private var profileCollapsed = false
    @State private var showSignatureSheet = false
    @State private var showDeleteConfirm = false
    @State private var showMessage = false
    @State private var message = ""
    @State private var pdfURL: URL?
    @State private var showShareSheet = false

    private var selectedDate: Date { store.date(inMonth: month, day: selectedDay) }
    private var savedMonth: [Int: InspectionDayRecord] { store.loadMonth(month) }
    private var isFuture: Bool { store.isFuture(selectedDate) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    monthCard(proxy: proxy)
                    profileCard
                    checklistCard
                    exportCard
                }
                .padding(16)
                .padding(.bottom, 28)
            }
            .background(Color(red: 0.965, green: 0.973, blue: 0.98))
        }
        .navigationTitle("운수종사자 일상점검")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSelectedDay()
            profileCollapsed = profile.isComplete
        }
        .alert("마루웰", isPresented: $showMessage) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(message)
        }
        .confirmationDialog("일상점검 삭제", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { deleteCurrentDay() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(selectedDay)일에 저장된 일상점검을 삭제할까요? 삭제한 내용은 복구할 수 없습니다.")
        }
        .sheet(isPresented: $showSignatureSheet) {
            signatureSheet
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfURL {
                ActivityView(items: [pdfURL])
            }
        }
    }

    private func monthCard(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 12) {
            HStack {
                monthButton("chevron.left") { changeMonth(-1) }
                Spacer()
                Text(monthTitle)
                    .font(.title3.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
                Spacer()
                monthButton("chevron.right") { changeMonth(1) }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(1...store.daysInMonth(month), id: \.self) { day in
                        let date = store.date(inMonth: month, day: day)
                        let selected = day == selectedDay
                        let saved = savedMonth[day] != nil
                        Button {
                            selectedDay = day
                            loadSelectedDay()
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(day)")
                                    .font(.subheadline.weight(.black))
                                Text(store.weekdayLabel(for: date))
                                    .font(.caption2.weight(.bold))
                                if saved {
                                    Circle().fill(selected ? Color.white : MaroowellTheme.deepYellow).frame(width: 5, height: 5)
                                } else {
                                    Color.clear.frame(width: 5, height: 5)
                                }
                            }
                            .foregroundStyle(dayForeground(date: date, selected: selected))
                            .frame(width: 50, height: 58)
                            .background(selected ? MaroowellTheme.yellow : Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(selected ? MaroowellTheme.yellow : Color.black.opacity(0.10), lineWidth: 1)
                            }
                        }
                        .id(day)
                    }
                }
            }
            .onChange(of: selectedDay) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }

            Text(summaryText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isFuture ? .red : MaroowellTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .inspectionCard()
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("점검표 정보")
                    .font(.headline.weight(.black))
                Spacer()
                Button(profileCollapsed ? "펼치기" : "접기") {
                    withAnimation(.easeInOut(duration: 0.18)) { profileCollapsed.toggle() }
                }
                .font(.caption.weight(.bold))
            }

            Text(profileSummary)
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)

            if !profileCollapsed {
                Text("입력값과 서명은 이 iPhone에만 저장됩니다.")
                    .font(.caption)
                    .foregroundStyle(MaroowellTheme.muted)

                labeledField("운송사업자명", placeholder: "마루웰", text: $profile.carrierName)
                labeledField("차량번호", placeholder: "경기00아0000", text: $profile.vehicleNumber)
                labeledField("운수종사자명", placeholder: "이쿠팡", text: $profile.driverName)

                Button {
                    showSignatureSheet = true
                } label: {
                    Label(signature.isEmpty ? "점검자 서명 등록" : "점검자 서명 수정", systemImage: "signature")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)

                Button {
                    guard profile.isComplete else {
                        present("운송사업자명, 차량번호, 운수종사자명을 모두 입력해주세요.")
                        return
                    }
                    store.saveProfile(profile)
                    profileCollapsed = true
                    present("점검표 정보를 저장했습니다.")
                } label: {
                    Text("점검표 정보 저장")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(MaroowellTheme.ink)
                }
            }
        }
        .padding(16)
        .inspectionCard()
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("일상점검")
                .font(.headline.weight(.black))
            Text("운행 전 11개 항목을 O / X로 직접 선택하세요.")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)

            ForEach(Array(InspectionSchema.groups.enumerated()), id: \.offset) { groupIndex, group in
                Text(group.title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.red)
                    .padding(.top, 4)

                ForEach(Array(group.items.enumerated()), id: \.offset) { itemIndex, item in
                    let globalIndex = InspectionSchema.globalIndex(groupIndex: groupIndex, itemIndex: itemIndex)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(globalIndex + 1). \(item)")
                            .font(.subheadline)
                            .foregroundStyle(MaroowellTheme.ink)

                        HStack(spacing: 8) {
                            statusButton("O", index: globalIndex)
                            statusButton("X", index: globalIndex)
                        }
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            }

            Button {
                guard !isFuture else { return }
                statuses = Array(repeating: "O", count: InspectionSchema.items.count)
            } label: {
                Label("전체 양호", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.green)
            }
            .disabled(isFuture)

            TextField("불량상태 조치 기록", text: $actionNote, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.10), lineWidth: 1) }
                .disabled(isFuture)

            Button("현재 화면 초기화") {
                statuses = Array(repeating: "", count: InspectionSchema.items.count)
                actionNote = ""
            }
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .buttonStyle(.bordered)
            .disabled(isFuture)

            Button {
                saveCurrentDay()
            } label: {
                Text(isFuture ? "미래 일자는 점검할 수 없습니다" : "이 날짜 일상점검 저장")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(isFuture ? Color.gray.opacity(0.25) : MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 15))
                    .foregroundStyle(isFuture ? .secondary : MaroowellTheme.ink)
            }
            .disabled(isFuture)

            if savedMonth[selectedDay] != nil {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Text("이 날짜 일상점검 삭제")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .inspectionCard()
    }

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("월간 점검표 PDF")
                .font(.headline.weight(.black))
            Text("저장된 점검기록으로 월간 점검표를 만들고 파일 공유·인쇄가 가능합니다.")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)

            Button {
                createPDFAndShare()
            } label: {
                Label("PDF 생성 및 공유", systemImage: "doc.richtext.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(MaroowellTheme.ink)
            }

            Button {
                printPDF()
            } label: {
                Label("인쇄", systemImage: "printer.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .inspectionCard()
    }

    private var signatureSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("손가락으로 직접 서명하세요. 서명은 이 기기에만 저장됩니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

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
            .navigationTitle("점검자 서명 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { showSignatureSheet = false }
                }
            }
        }
    }

    private func statusButton(_ value: String, index: Int) -> some View {
        let active = statuses[index] == value
        let color: Color = value == "O" ? .green : .red
        return Button(value) {
            guard !isFuture else { return }
            statuses[index] = value
        }
        .font(.headline.weight(.black))
        .foregroundStyle(active ? Color.white : color)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(active ? color : Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(color.opacity(active ? 1 : 0.45), lineWidth: 1) }
        .disabled(isFuture)
    }

    private func labeledField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(MaroowellTheme.muted)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.1), lineWidth: 1) }
        }
    }

    private func monthButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
                .frame(width: 44, height: 44)
                .background(MaroowellTheme.yellow.opacity(0.2), in: Circle())
        }
    }

    private func changeMonth(_ delta: Int) {
        store.saveProfile(profile)
        month = store.startOfMonth(store.movingMonth(month, by: delta))
        let today = Date()
        if store.monthKey(for: month) == store.monthKey(for: today) {
            selectedDay = store.dayNumber(for: today)
        } else {
            selectedDay = 1
        }
        loadSelectedDay()
    }

    private func loadSelectedDay() {
        let record = store.loadDay(selectedDate)
        statuses = Array(repeating: "", count: InspectionSchema.items.count)
        if let record {
            for index in statuses.indices {
                statuses[index] = record.statuses.indices.contains(index) ? record.statuses[index] : ""
            }
            actionNote = record.actionNote
        } else {
            actionNote = ""
        }
    }

    private func saveCurrentDay() {
        guard !isFuture else {
            present("오늘 이후 미래 일자는 일상점검을 등록할 수 없습니다.")
            return
        }
        guard profile.isComplete else {
            present("운송사업자명, 차량번호, 운수종사자명을 먼저 입력해주세요.")
            return
        }
        guard !signature.isEmpty else {
            present("점검자 서명을 먼저 등록해주세요.")
            return
        }
        guard statuses.allSatisfy({ !$0.isEmpty }) else {
            present("11개 점검항목을 모두 O / X 중 하나로 선택해주세요.")
            return
        }
        if statuses.contains("X") && actionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            present("불량(X) 항목이 있으면 조치 기록을 입력해주세요.")
            return
        }

        store.saveProfile(profile)
        store.saveSignature(signature)
        store.saveDay(selectedDate, record: InspectionDayRecord(statuses: statuses, actionNote: actionNote.trimmingCharacters(in: .whitespacesAndNewlines), savedAt: .now))
        profileCollapsed = true
        present("\(selectedDay)일 점검 저장 완료")
    }

    private func deleteCurrentDay() {
        store.deleteDay(selectedDate)
        statuses = Array(repeating: "", count: InspectionSchema.items.count)
        actionNote = ""
        present("\(selectedDay)일 일상점검을 삭제했습니다.")
    }

    private func makePDF() -> URL? {
        guard profile.isComplete else {
            present("점검표 기본정보를 먼저 입력해주세요.")
            return nil
        }
        guard !signature.isEmpty else {
            present("점검자 서명을 먼저 등록해주세요.")
            return nil
        }
        let records = store.loadMonth(month)
        guard !records.isEmpty else {
            present("이 달에 PDF로 만들 점검 기록이 없습니다.")
            return nil
        }
        do {
            return try InspectionPDFRenderer.create(month: month, profile: profile, records: records, signature: signature)
        } catch {
            present("PDF 생성 실패: \(error.localizedDescription)")
            return nil
        }
    }

    private func createPDFAndShare() {
        guard let url = makePDF() else { return }
        pdfURL = url
        showShareSheet = true
    }

    private func printPDF() {
        guard let url = makePDF(), let data = try? Data(contentsOf: url) else { return }
        let controller = UIPrintInteractionController.shared
        controller.printingItem = data
        controller.present(animated: true)
    }

    private func present(_ text: String) {
        message = text
        showMessage = true
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: month)
    }

    private var summaryText: String {
        let saved = savedMonth.count
        if isFuture && savedMonth[selectedDay] != nil {
            return "미래 일자는 점검할 수 없습니다 · 잘못 저장된 기록은 삭제할 수 있습니다."
        }
        if isFuture { return "미래 일자는 일상점검을 등록할 수 없습니다." }
        return "저장된 점검일 \(saved) / \(store.daysInMonth(month))일 · 선택일 \(selectedDay)일"
    }

    private var profileSummary: String {
        guard profile.isComplete else { return "기본정보 미등록" }
        return "\(profile.carrierName) · \(profile.vehicleNumber) · \(profile.driverName) · \(signature.isEmpty ? "서명 미등록" : "서명 등록")"
    }

    private func dayForeground(date: Date, selected: Bool) -> Color {
        if selected { return MaroowellTheme.ink }
        if store.isSunday(date) { return .red }
        if store.isSaturday(date) { return .blue }
        return MaroowellTheme.ink
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension View {
    func inspectionCard() -> some View {
        self.background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            }
    }
}
