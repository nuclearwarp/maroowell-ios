import SwiftUI

struct ScheduleView: View {
    @StateObject private var model = ScheduleViewModel()
    @State private var showDiscardAlert = false
    @State private var showMetaUpload = false
    @State private var metaPreview: NativeMetaPreview?
    @State private var metaProgress = ""
    @State private var metaBusy = false
    @State private var metaAlert = false
    @State private var metaError: String?
    @FocusState private var focusedField: ScheduleCellKey?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                controls
                daySelector
                statusBar

                if model.selectedCamp == nil {
                    emptyState("캠프를 선택하면 입차 스케줄을 불러옵니다.", symbol: "building.2")
                } else if model.isLoading && model.routeRows.isEmpty {
                    ProgressView("입차 스케줄 불러오는 중…")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if model.routeRows.isEmpty {
                    emptyState("표시할 라우트가 없습니다.", symbol: "shippingbox")
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(model.routeRows) { row in
                            ScheduleRouteCard(model: model, row: row, focusedField: $focusedField)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(MaroowellTheme.background)
        .navigationTitle("입차 스케줄")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("메타어드민 스케줄 전송", isPresented: $metaAlert, titleVisibility: .visible) {
            Button("🚀 메타어드민 전송") {
                if let preview = metaPreview {
                    Task { await transferMeta(preview) }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            if let preview = metaPreview {
                Text("\(preview.camp) · \(preview.metaDate)\n기존 등록 \(preview.resetCount)명 휴무 처리 후 신규 \(preview.applyCount)명 등록합니다.")
            }
        }
        .overlay(alignment: .bottom) {
            if metaBusy {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(metaProgress).font(.caption.weight(.semibold))
                }
                .padding(12)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 12)
            }
        }
        .alert("입차 스케줄", isPresented: Binding(
            get: { model.errorMessage != nil || model.successMessage != nil },
            set: { if !$0 { model.errorMessage = nil; model.successMessage = nil } }
        )) {
            Button("확인", role: .cancel) {
                model.errorMessage = nil
                model.successMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? model.successMessage ?? "")
        }
    }

    @MainActor
    private func prepareMeta() async {
        guard model.canOpenMetaUpload, let camp = model.selectedCamp else {
            model.errorMessage = "서버에 저장한 뒤 다시 시도해주세요."
            return
        }
        metaBusy = true
        metaProgress = "메타어드민 기존 등록 확인 중"
        defer { metaBusy = false }
        do {
            let preview = try await NativeMetaAPI.shared.preview(camp: camp.name, wave: camp.wave, date: ScheduleDatePolicy.iso(model.selectedDate))
            metaPreview = preview
            metaAlert = true
        } catch {
            model.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func transferMeta(_ preview: NativeMetaPreview) async {
        metaBusy = true
        defer { metaBusy = false }
        do {
            try await NativeMetaAPI.shared.transfer(preview) { message in
                metaProgress = message
            }
            model.successMessage = "메타어드민 전송 및 실제 등록 검증 완료 · \(preview.metaDate)"
        } catch {
            model.errorMessage = "메타어드민 전송 중단: \(error.localizedDescription)"
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text("캠프 / WAVE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MaroowellTheme.muted)
                        if model.isLoading || model.isSaving {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                    Menu {
                        ForEach(ScheduleCampOption.all) { camp in
                            Button("\(camp.name) · \(camp.waveLabel)") {
                                focusedField = nil
                                Task { await model.selectCamp(camp) }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(model.selectedCamp.map { "\($0.name) · \($0.waveLabel)" } ?? "캠프 선택")
                                .font(.system(size: 15, weight: .black))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(MaroowellTheme.ink)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MaroowellTheme.deepYellow)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(ScheduleDatePolicy.weekLabel(sunday: model.weekStart))
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(MaroowellTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(ScheduleDatePolicy.rangeLabel(sunday: model.weekStart))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MaroowellTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 8) {
                weekButton("이전주", symbol: "chevron.left") { await model.moveWeek(by: -7) }
                weekButton("이번주", symbol: "calendar") { await model.currentWeek() }
                weekButton("다음주", symbol: "chevron.right") { await model.moveWeek(by: 7) }
            }

            actionButtons
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(MaroowellTheme.border.opacity(0.75)) }
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Button {
                    focusedField = nil
                    Task { await model.save() }
                } label: {
                    HStack(spacing: 5) {
                        if model.isSaving {
                            ProgressView()
                                .tint(MaroowellTheme.ink)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                        Text(model.dirtyCount > 0 ? "서버 저장 (\(model.dirtyCount))" : "서버 저장")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MaroowellTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(MaroowellTheme.yellow, in: RoundedRectangle(cornerRadius: 12))
                    .opacity(model.canSave ? 1 : 0.48)
                }
                .buttonStyle(.plain)
                .disabled(!model.canSave)
                .accessibilityIdentifier("schedule-server-save")

                Button {
                    focusedField = nil
                    if model.canOpenMetaUpload {
                        Task { await prepareMeta() }
                    } else {
                        model.errorMessage = "메타어드민 전송 전에 캠프 스케줄을 불러오고 변경사항을 서버에 저장해주세요."
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "paperplane.fill")
                        Text("🚀 메타어드민 전송")
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color(red: 0.08, green: 0.67, blue: 0.30), in: RoundedRectangle(cornerRadius: 12))
                    .opacity(model.selectedCamp == nil || model.isLoading || model.isSaving || metaBusy ? 0.48 : 1)
                }
                .buttonStyle(.plain)
                .disabled(model.selectedCamp == nil || model.isLoading || model.isSaving || metaBusy)
                .accessibilityIdentifier("schedule-meta-upload")
            }

        }
    }

    // All seven days must be visible at once, even on compact iPhone screens.
    private var daySelector: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(Array(model.weekDates.enumerated()), id: \.offset) { index, date in
                    Button {
                        focusedField = nil
                        model.selectedDayIndex = index
                    } label: {
                        let pieces = ScheduleDatePolicy.dayLabel(date).split(separator: "\n").map(String.init)
                        VStack(spacing: 3) {
                            Text(pieces.first ?? "")
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text(pieces.count > 1 ? pieces[1] : "")
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(index == 0 ? Color.red.opacity(0.78) : MaroowellTheme.ink)
                        .frame(width: max(0, (geometry.size.width - 24) / 7), height: 54)
                        .background(index == model.selectedDayIndex ? MaroowellTheme.yellow.opacity(0.22) : Color.white, in: RoundedRectangle(cornerRadius: 11))
                        .overlay {
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(index == model.selectedDayIndex ? MaroowellTheme.deepYellow : MaroowellTheme.border.opacity(0.65), lineWidth: index == model.selectedDayIndex ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ScheduleDatePolicy.fullDayLabel(date))
                }
            }
        }
        .frame(height: 54)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(MaroowellTheme.deepYellow)
            Text("\(ScheduleDatePolicy.fullDayLabel(model.selectedDate)) · 라우트 \(model.allRouteRows.filter { !$0.isOff && !$0.isChild }.count)개")
                .font(.caption.weight(.bold))
                .foregroundStyle(MaroowellTheme.muted)
            Spacer()
        }
    }

    private func weekButton(_ title: String, symbol: String, action: @escaping () async -> Void) -> some View {
        Button {
            focusedField = nil
            Task { await action() }
        } label: {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
        }
        .buttonStyle(.bordered)
        .disabled(model.isLoading || model.isSaving)
    }

    private func emptyState(_ text: String, symbol: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(MaroowellTheme.deepYellow)
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MaroowellTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct ScheduleRouteCard: View {
    @ObservedObject var model: ScheduleViewModel
    let row: ScheduleRouteRow
    @FocusState.Binding var focusedField: ScheduleCellKey?

    private var locked: Bool { model.isLocked(row) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    model.toggle(row)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(row.label)
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(MaroowellTheme.ink)
                            if row.hasChildren {
                                Image(systemName: model.expandedParents.contains(row.label) ? "chevron.up" : "chevron.down")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(MaroowellTheme.deepYellow)
                            }
                        }
                        Text(row.isOff ? "휴무" : row.isChild ? "세부 라우트" : row.hasChildren ? "세부 라우트 포함" : row.description)
                            .font(.caption2)
                            .foregroundStyle(MaroowellTheme.muted)
                            .lineLimit(1)
                    }
                    .frame(width: 96, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(!row.hasChildren)

                if locked {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text(row.isChild ? "부모 라우트 배정됨" : "세부 라우트 배정됨")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MaroowellTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color.gray.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    TextField(row.isOff ? "휴무자 (쉼표 구분)" : "기사 이름", text: Binding(
                        get: { model.value(for: row) },
                        set: { model.update(row: row, value: $0) }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: ScheduleCellKey(date: ScheduleDatePolicy.iso(model.selectedDate), routeLabel: row.label))
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 46)
                    .background(row.isOff ? MaroowellTheme.yellow.opacity(0.12) : Color.gray.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            if !row.isOff && !locked && model.value(for: row).isEmpty && !model.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.suggestions.prefix(10), id: \.self) { name in
                            Button(name) { model.update(row: row, value: name) }
                                .font(.caption2.weight(.bold))
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .padding(12)
        .padding(.leading, row.isChild ? 10 : 0)
        .background(row.isOff ? MaroowellTheme.yellow.opacity(0.08) : Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(MaroowellTheme.border.opacity(0.62)) }
    }
}
