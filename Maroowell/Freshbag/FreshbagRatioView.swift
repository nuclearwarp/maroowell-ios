import Foundation
import SwiftUI
import UIKit

struct FreshbagRatioView: View {
    @StateObject private var store = FreshbagRatioStore()
    @State private var shareImage: UIImage?
    @State private var isSharing = false

    let session: AppSession

    var body: some View {
        Group {
            if session.isMaroowell {
                content
            } else {
                permissionDenied
            }
        }
        .navigationTitle("마루웰 회수율")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if session.isMaroowell {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        renderAndShareReport()
                    } label: {
                        Label("이미지 공유", systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.result == nil || store.isLoading)
                }
            }
        }
        .sheet(isPresented: $isSharing, onDismiss: { shareImage = nil }) {
            if let shareImage {
                FreshbagRatioShareSheet(items: [shareImage])
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("마루웰 회수율", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 13) {
                filterCard
                statusRow

                if let result = store.result, let query = store.currentQuery {
                    summaryCard(result)
                    sectionHeader("월 누적 회수율", detail: "\(query.periodStart) ~ \(query.periodEnd)")

                    if result.totalRows.isEmpty {
                        emptyCard("월 누적 데이터가 없습니다.")
                    } else {
                        ForEach(result.totalRows) { row in
                            monthlyCard(row)
                        }
                    }

                    sectionHeader("주차별 일자 회수율", detail: "정산월에 포함된 날짜만 표시")
                    if result.routeRows.isEmpty {
                        emptyCard("일자별 데이터가 없습니다.")
                    } else {
                        ForEach(FreshbagWeekBlock.build(startISO: query.periodStart, endISO: query.periodEnd)) { week in
                            weekCard(week, result: result)
                        }
                    }
                } else if !store.isLoading {
                    emptyCard("정산월과 캠프를 선택한 뒤 조회하세요.\n라우트를 비우면 캠프 전체를 조회합니다.")
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 13)
            .padding(.bottom, 30)
        }
        .background(MaroowellTheme.background)
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("조회 조건")
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                    Text("월 누적 · 주차별 일자 회수율")
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                if store.result != nil {
                    Text("조회완료")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(MaroowellTheme.deepYellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(MaroowellTheme.yellow.opacity(0.16), in: Capsule())
                }
            }

            HStack(spacing: 9) {
                pickerField("연도") {
                    Picker("연도", selection: $store.selectedYear) {
                        ForEach(store.availableYears, id: \.self) { year in
                            Text("\(year)년").tag(year)
                        }
                    }
                }
                pickerField("정산월") {
                    Picker("정산월", selection: $store.selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)월").tag(month)
                        }
                    }
                }
            }

            HStack(spacing: 9) {
                pickerField("Camp") {
                    Picker("Camp", selection: $store.selectedCampIndex) {
                        ForEach(Array(FreshbagCampOption.options.enumerated()), id: \.offset) { index, option in
                            Text(option.display).tag(index)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("주간/야간")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(MaroowellTheme.muted)
                    Text(store.selectedCamp.waveLabel)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 42)
                        .padding(.horizontal, 11)
                        .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Route")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MaroowellTheme.muted)
                TextField("예: 126A / 126B / 126C (비우면 전체)", text: $store.routeText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Label(store.periodLabel, systemImage: "calendar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MaroowellTheme.muted)

            HStack(spacing: 9) {
                Button {
                    Task { await store.load() }
                } label: {
                    HStack(spacing: 7) {
                        if store.isLoading { ProgressView().controlSize(.small).tint(.white) }
                        Text(store.isLoading ? "조회 중..." : "조회")
                            .font(.subheadline.weight(.black))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.15, green: 0.39, blue: 0.87))
                .disabled(store.isLoading)

                Button {
                    store.clearResults()
                } label: {
                    Text("초기화")
                        .font(.subheadline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(store.isLoading)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }

    private func pickerField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MaroowellTheme.muted)
            content()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 42)
                .padding(.horizontal, 7)
                .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            if store.isLoading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: store.result == nil ? "info.circle" : "checkmark.circle.fill")
                    .foregroundStyle(store.result == nil ? MaroowellTheme.muted : Color.green)
            }
            Text(store.statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MaroowellTheme.muted)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func summaryCard(_ result: FreshbagRatioResult) -> some View {
        HStack(spacing: 8) {
            summaryMetric("월누적", value: result.totalRows.count)
            summaryMetric("일자별", value: result.dailyRows.count)
            summaryMetric("라우트", value: result.routeRows.count)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }

    private func summaryMetric(_ title: String, value: Int) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MaroowellTheme.muted)
            Text("\(value)")
                .font(.title3.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        HStack(alignment: .bottom) {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
            Spacer()
            Text(detail)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(MaroowellTheme.muted)
        }
        .padding(.top, 5)
        .padding(.horizontal, 2)
    }

    private func monthlyCard(_ row: FreshbagRatioRow) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("\(row.camp) - \(row.route) \(row.waveLabel)")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
                Spacer()
                Text(row.waveLabel)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(MaroowellTheme.deepYellow)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(MaroowellTheme.yellow.opacity(0.16), in: Capsule())
            }

            HStack(spacing: 8) {
                FreshbagRatioValue(label: "가중1", value: row.g1, wave: row.wave)
                FreshbagRatioValue(label: "가중2", value: row.g2, wave: row.wave)
            }

            if !row.periodStart.isEmpty {
                Text("\(row.periodStart) ~ \(row.periodEnd)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MaroowellTheme.muted)
            }
        }
        .padding(13)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }

    private func weekCard(_ week: FreshbagWeekBlock, result: FreshbagRatioResult) -> some View {
        let daily = Dictionary(uniqueKeysWithValues: result.dailyRows.map { ($0.dailyKey, $0) })

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(week.sequence)주차")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
                Spacer()
                Text("\(FreshbagDate.short(week.start)) ~ \(FreshbagDate.short(week.end))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MaroowellTheme.muted)
            }

            ForEach(result.routeRows) { route in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(route.camp) - \(route.route) \(route.waveLabel)")
                        .font(.caption.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(week.days, id: \.self) { date in
                                let item = daily["\(route.wave)|\(route.camp)|\(route.route)|\(date)"]
                                dailyCell(date: date, wave: route.wave, row: item)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(13)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }

    private func dailyCell(date: String, wave: String, row: FreshbagRatioRow?) -> some View {
        VStack(spacing: 5) {
            Text(FreshbagDate.koreanDay(date))
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(MaroowellTheme.ink)
            FreshbagRatioValue(label: "가중1", value: row?.g1, wave: wave, compact: true)
            FreshbagRatioValue(label: "가중2", value: row?.g2, wave: wave, compact: true)
        }
        .padding(6)
        .frame(width: 92)
        .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MaroowellTheme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 15)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(MaroowellTheme.border, lineWidth: 1)
            }
    }

    private var permissionDenied: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(MaroowellTheme.muted)
            Text("마루웰 소속 계정만 이용할 수 있습니다.")
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaroowellTheme.background)
    }

    @MainActor
    private func renderAndShareReport() {
        guard let query = store.currentQuery, let result = store.result else { return }
        let report = FreshbagRatioReportView(query: query, result: result)
            .frame(width: 900)
            .fixedSize(horizontal: false, vertical: true)
        let renderer = ImageRenderer(content: report)
        renderer.scale = 2
        renderer.isOpaque = true
        guard let image = renderer.uiImage else {
            store.errorMessage = "회수율 이미지를 만들지 못했습니다."
            return
        }
        shareImage = image
        isSharing = true
    }
}

private struct FreshbagRatioValue: View {
    let label: String
    let value: Double?
    let wave: String
    var compact = false

    var body: some View {
        let state = FreshbagRatioThreshold.state(label: label, value: value, wave: wave)
        Text("\(label) \(FreshbagRatioFormat.percent(value))")
            .font(.system(size: compact ? 9 : 12, weight: .black))
            .foregroundStyle(state.foreground)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 26 : 40)
            .background(state.background, in: RoundedRectangle(cornerRadius: compact ? 7 : 10, style: .continuous))
    }
}

@MainActor
private final class FreshbagRatioStore: ObservableObject {
    @Published var selectedYear: Int
    @Published var selectedMonth: Int
    @Published var selectedCampIndex = 0
    @Published var routeText = ""
    @Published var isLoading = false
    @Published var statusText = "정산월과 캠프를 선택한 뒤 조회하세요. 라우트를 비우면 캠프 전체를 조회합니다."
    @Published var result: FreshbagRatioResult?
    @Published var currentQuery: FreshbagRatioQuery?
    @Published var errorMessage: String?

    private let api = FreshbagRatioAPI()

    init() {
        let parts = FreshbagDate.currentYearMonth()
        selectedYear = parts.year
        selectedMonth = parts.month
    }

    var availableYears: [Int] {
        let current = FreshbagDate.currentYearMonth().year
        return Array(stride(from: current + 1, through: current - 8, by: -1))
    }

    var selectedCamp: FreshbagCampOption {
        FreshbagCampOption.options.indices.contains(selectedCampIndex)
            ? FreshbagCampOption.options[selectedCampIndex]
            : FreshbagCampOption.options[0]
    }

    var periodLabel: String {
        let period = FreshbagDate.period(year: selectedYear, month: selectedMonth)
        return "\(selectedYear)년 \(selectedMonth)월 정산 기준 · \(period.start) ~ \(period.end)"
    }

    func load() async {
        let query = FreshbagRatioQuery.make(
            year: selectedYear,
            month: selectedMonth,
            camp: selectedCamp,
            routeText: routeText
        )
        isLoading = true
        statusText = "회수율 조회 중…"
        result = nil
        currentQuery = nil
        defer { isLoading = false }

        do {
            let loaded = try await api.query(query)
            result = loaded
            currentQuery = query
            statusText = "조회 완료 · 월누적 \(loaded.totalRows.count)건 · 일자별 \(loaded.dailyRows.count)건 · 라우트 \(loaded.routeRows.count)개"
        } catch {
            statusText = "조회 실패"
            errorMessage = FreshbagRatioAPI.friendly(error)
        }
    }

    func clearResults() {
        routeText = ""
        result = nil
        currentQuery = nil
        statusText = "조회 결과를 초기화했습니다."
    }
}

private struct FreshbagCampOption: Hashable {
    let display: String
    let db: String
    let wave: String

    var waveLabel: String { FreshbagRatioFormat.waveLabel(wave) }

    static let options: [FreshbagCampOption] = [
        .init(display: "M익산1", db: "M_익산1", wave: "W1"),
        .init(display: "대구3", db: "대구3", wave: "W2"),
        .init(display: "용인1", db: "용인1", wave: "W2"),
        .init(display: "용인3", db: "용인3", wave: "W2"),
        .init(display: "일산2", db: "일산2", wave: "W2")
    ]
}

private struct FreshbagRatioQuery: Hashable {
    let year: Int
    let month: Int
    let campDisplay: String
    let campDB: String
    let wave: String
    let periodStart: String
    let periodEnd: String
    let routes: [String]

    static func make(year: Int, month: Int, camp: FreshbagCampOption, routeText: String) -> FreshbagRatioQuery {
        let period = FreshbagDate.period(year: year, month: month)
        let routes = routeText
            .components(separatedBy: CharacterSet(charactersIn: ",/| \t\n"))
            .map(FreshbagRatioFormat.normalizeRoute)
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, route in
                if !result.contains(route) { result.append(route) }
            }
        return FreshbagRatioQuery(
            year: year,
            month: month,
            campDisplay: camp.display,
            campDB: camp.db,
            wave: camp.wave,
            periodStart: period.start,
            periodEnd: period.end,
            routes: routes
        )
    }
}

private struct FreshbagRatioResult {
    let totalRows: [FreshbagRatioRow]
    let dailyRows: [FreshbagRatioRow]
    let routeRows: [FreshbagRatioRow]
}

private struct FreshbagRatioRow: Identifiable, Hashable {
    let wave: String
    let camp: String
    let route: String
    let g1: Double?
    let g2: Double?
    let periodStart: String
    let periodEnd: String
    let date: String

    var id: String { "\(wave)|\(camp)|\(route)|\(date)|\(periodStart)" }
    var waveLabel: String { FreshbagRatioFormat.waveLabel(wave) }
    var dailyKey: String { "\(wave)|\(camp)|\(route)|\(date)" }
}

private struct FreshbagWeekBlock: Identifiable {
    let sequence: Int
    let start: String
    let end: String
    let days: [String]

    var id: Int { sequence }

    static func build(startISO: String, endISO: String) -> [FreshbagWeekBlock] {
        guard let start = FreshbagDate.date(startISO), let end = FreshbagDate.date(endISO) else { return [] }
        var calendar = FreshbagDate.calendar
        var cursor = start
        let weekday = calendar.component(.weekday, from: cursor)
        cursor = calendar.date(byAdding: .day, value: -(weekday - 1), to: cursor) ?? cursor
        var result: [FreshbagWeekBlock] = []
        var sequence = 1

        while cursor <= end {
            var days: [String] = []
            for offset in 0...6 {
                guard let value = calendar.date(byAdding: .day, value: offset, to: cursor) else { continue }
                if value >= start && value <= end { days.append(FreshbagDate.iso(value)) }
            }
            if let first = days.first, let last = days.last {
                result.append(.init(sequence: sequence, start: first, end: last, days: days))
                sequence += 1
            }
            cursor = calendar.date(byAdding: .day, value: 7, to: cursor) ?? end.addingTimeInterval(86_400)
        }
        return result
    }
}

private enum FreshbagDate {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    static func currentYearMonth() -> (year: Int, month: Int) {
        let parts = calendar.dateComponents([.year, .month], from: Date())
        return (parts.year ?? 2026, parts.month ?? 1)
    }

    static func period(year: Int, month: Int) -> (start: String, end: String) {
        let previousYear = month == 1 ? year - 1 : year
        let previousMonth = month == 1 ? 12 : month - 1
        return (
            String(format: "%04d-%02d-26", previousYear, previousMonth),
            String(format: "%04d-%02d-25", year, month)
        )
    }

    static func date(_ iso: String) -> Date? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    static func iso(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func short(_ iso: String) -> String {
        guard iso.count >= 10 else { return iso }
        return String(iso.dropFirst(5)).replacingOccurrences(of: "-", with: "/")
    }

    static func koreanDay(_ iso: String) -> String {
        guard let date = date(iso) else { return short(iso) }
        let parts = calendar.dateComponents([.month, .day, .weekday], from: date)
        let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
        let weekday = weekdays[max(0, min(6, (parts.weekday ?? 1) - 1))]
        return "\(parts.month ?? 0)/\(parts.day ?? 0) \(weekday)"
    }
}

private enum FreshbagRatioFormat {
    static func percent(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.2f%%", value)
    }

    static func waveLabel(_ value: String) -> String {
        switch value.uppercased() {
        case "W1", "야간": return "야간"
        case "W2", "주간": return "주간"
        default: return value
        }
    }

    static func normalizeRoute(_ value: String) -> String {
        value.uppercased()
            .replacingOccurrences(of: "[^0-9A-Z가-힣]", with: "", options: .regularExpression)
    }

    static func normalizeCamp(_ value: String) -> String {
        let stripped = value.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        if stripped.uppercased().hasPrefix("M_") {
            return "M" + stripped.dropFirst(2)
        }
        return stripped
    }

    static func routeLeadingNumber(_ route: String) -> Int {
        Int(route.prefix { $0.isNumber }) ?? Int.max
    }
}

private enum FreshbagRatioThreshold {
    enum State {
        case empty, good, bad

        var background: Color {
            switch self {
            case .empty: return Color(red: 0.95, green: 0.96, blue: 0.98)
            case .good: return Color(red: 0.91, green: 0.97, blue: 0.93)
            case .bad: return Color(red: 1.0, green: 0.95, blue: 0.93)
            }
        }

        var foreground: Color {
            switch self {
            case .empty: return Color(red: 0.58, green: 0.64, blue: 0.72)
            case .good: return Color(red: 0.09, green: 0.40, blue: 0.20)
            case .bad: return Color(red: 0.76, green: 0.25, blue: 0.05)
            }
        }
    }

    static func state(label: String, value: Double?, wave: String) -> State {
        guard let value else { return .empty }
        let threshold: Double
        if label == "가중1" {
            threshold = 95
        } else {
            threshold = wave.uppercased() == "W1" ? 75 : 85
        }
        return value >= threshold ? .good : .bad
    }
}

private struct FreshbagRatioAPI {
    private static let baseURL = URL(string: "https://maroowellfreshbag.brain-0f6.workers.dev")!
    private let client = SupabaseService.shared.client

    func query(_ query: FreshbagRatioQuery) async throws -> FreshbagRatioResult {
        let authSession = try await client.auth.session
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("ratio/query"))
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "data_year": query.year,
            "month_no": query.month,
            "data_month": String(format: "%04d-%02d", query.year, query.month),
            "period_start": query.periodStart,
            "period_end": query.periodEnd,
            "camp": query.campDB,
            "displayCamp": query.campDisplay,
            "wave": query.wave,
            "routes": query.routes
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = (root?["error"] as? String) ?? (root?["message"] as? String)
            throw APIError.backend(status: http.statusCode, message: message)
        }
        return try parse(data)
    }

    private func parse(_ data: Data) throws -> FreshbagRatioResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decode
        }

        let totalRows = parseRows(
            array(root, keys: ["totalRows", "total_rows", "monthTotalRows", "month_total_rows", "total"]),
            daily: false
        ).sorted(by: sortRows)
        let dailyRows = parseRows(
            array(root, keys: ["dailyRows", "daily_rows", "daily"]),
            daily: true
        ).sorted(by: sortDailyRows)

        var seen = Set<String>()
        let routeRows = (totalRows + dailyRows).filter { row in
            let key = "\(row.wave)|\(row.camp)|\(row.route)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }.sorted(by: sortRows)

        return FreshbagRatioResult(totalRows: totalRows, dailyRows: dailyRows, routeRows: routeRows)
    }

    private func array(_ root: [String: Any], keys: [String]) -> [[String: Any]] {
        for key in keys {
            if let value = root[key] as? [[String: Any]] { return value }
        }
        return []
    }

    private func parseRows(_ source: [[String: Any]], daily: Bool) -> [FreshbagRatioRow] {
        source.compactMap { row in
            let route = FreshbagRatioFormat.normalizeRoute(text(row["route_norm"]).isEmpty ? text(row["route"]) : text(row["route_norm"]))
            guard !route.isEmpty else { return nil }
            return FreshbagRatioRow(
                wave: text(row["wave"]).uppercased(),
                camp: FreshbagRatioFormat.normalizeCamp(text(row["camp"])),
                route: route,
                g1: number(row["gajoong1"]),
                g2: number(row["gajoong2"]),
                periodStart: text(row["period_start"]),
                periodEnd: text(row["period_end"]),
                date: daily ? text(row["date"]) : ""
            )
        }
    }

    private func text(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }

    private func number(_ value: Any?) -> Double? {
        guard let value, !(value is NSNull) else { return nil }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String {
            return Double(string.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private func sortRows(_ lhs: FreshbagRatioRow, _ rhs: FreshbagRatioRow) -> Bool {
        let campOrder = lhs.camp.localizedStandardCompare(rhs.camp)
        if campOrder != .orderedSame { return campOrder == .orderedAscending }
        let lw = lhs.wave == "W2" ? 1 : 2
        let rw = rhs.wave == "W2" ? 1 : 2
        if lw != rw { return lw < rw }
        let ln = FreshbagRatioFormat.routeLeadingNumber(lhs.route)
        let rn = FreshbagRatioFormat.routeLeadingNumber(rhs.route)
        if ln != rn { return ln < rn }
        return lhs.route.localizedStandardCompare(rhs.route) == .orderedAscending
    }

    private func sortDailyRows(_ lhs: FreshbagRatioRow, _ rhs: FreshbagRatioRow) -> Bool {
        if sortRows(lhs, rhs) { return true }
        if sortRows(rhs, lhs) { return false }
        return lhs.date < rhs.date
    }

    static func friendly(_ error: Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .backend(let status, let message):
                if status == 401 || status == 403 {
                    return "마루웰 회수율 접근 권한 또는 로그인 세션을 확인해주세요."
                }
                return message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? message!
                    : "회수율 조회 서버 오류 (HTTP \(status))"
            case .invalidResponse:
                return "회수율 조회 서버 응답을 확인하지 못했습니다."
            case .decode:
                return "회수율 조회 응답 형식이 올바르지 않습니다."
            }
        }
        return error.localizedDescription
    }

    private enum APIError: Error {
        case backend(status: Int, message: String?)
        case invalidResponse
        case decode
    }
}

private struct FreshbagRatioReportView: View {
    let query: FreshbagRatioQuery
    let result: FreshbagRatioResult

    private var daily: [String: FreshbagRatioRow] {
        Dictionary(uniqueKeysWithValues: result.dailyRows.map { ($0.dailyKey, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("MAROOWELL")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color(red: 0.72, green: 0.49, blue: 0.02))
                Text("마루웰 회수율")
                    .font(.system(size: 27, weight: .black))
                    .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
                Text("\(query.year)년 \(query.month)월 · \(query.campDisplay) · \(FreshbagRatioFormat.waveLabel(query.wave)) · \(query.periodStart) ~ \(query.periodEnd)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.gray)
            }

            reportSectionTitle("월 누적 회수율")
            if result.totalRows.isEmpty {
                reportEmpty("월 누적 데이터 없음")
            } else {
                ForEach(result.totalRows) { row in
                    HStack(spacing: 0) {
                        reportText(row.waveLabel, width: 70)
                        reportText(row.camp, width: 110)
                        reportText(row.route, width: 110)
                        reportRatio("가중1", value: row.g1, wave: row.wave, width: 110)
                        reportRatio("가중2", value: row.g2, wave: row.wave, width: 110)
                        reportText("\(row.periodStart) ~ \(row.periodEnd)", width: 250)
                    }
                }
            }

            ForEach(FreshbagWeekBlock.build(startISO: query.periodStart, endISO: query.periodEnd)) { week in
                reportSectionTitle("\(week.sequence)주차  \(week.start) ~ \(week.end)")
                ForEach(result.routeRows) { route in
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(route.camp) - \(route.route)")
                                .font(.system(size: 11, weight: .black))
                            Text(route.waveLabel)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.gray)
                        }
                        .padding(7)
                        .frame(width: 190, height: 62, alignment: .leading)
                        .background(Color.white)
                        .overlay(Rectangle().stroke(Color.gray.opacity(0.24), lineWidth: 1))

                        ForEach(week.days, id: \.self) { date in
                            let item = daily["\(route.wave)|\(route.camp)|\(route.route)|\(date)"]
                            VStack(spacing: 3) {
                                Text(FreshbagDate.short(date))
                                    .font(.system(size: 8, weight: .black))
                                Text(FreshbagRatioFormat.percent(item?.g1))
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(FreshbagRatioThreshold.state(label: "가중1", value: item?.g1, wave: route.wave).foreground)
                                Text(FreshbagRatioFormat.percent(item?.g2))
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(FreshbagRatioThreshold.state(label: "가중2", value: item?.g2, wave: route.wave).foreground)
                            }
                            .frame(width: 94, height: 62)
                            .background(Color.white)
                            .overlay(Rectangle().stroke(Color.gray.opacity(0.24), lineWidth: 1))
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            Text("마루웰 앱 · 회수율 조회")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.gray)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
        }
        .padding(22)
        .background(Color.white)
    }

    private func reportSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 34)
            .background(Color(red: 0.92, green: 0.95, blue: 0.98))
    }

    private func reportText(_ text: String, width: CGFloat) -> some View {
        Text(text.isEmpty ? "-" : text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.16))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(width: width, height: 34)
            .background(Color.white)
            .overlay(Rectangle().stroke(Color.gray.opacity(0.24), lineWidth: 1))
    }

    private func reportRatio(_ label: String, value: Double?, wave: String, width: CGFloat) -> some View {
        let state = FreshbagRatioThreshold.state(label: label, value: value, wave: wave)
        return Text(FreshbagRatioFormat.percent(value))
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(state.foreground)
            .frame(width: width, height: 34)
            .background(state.background)
            .overlay(Rectangle().stroke(Color.gray.opacity(0.24), lineWidth: 1))
    }

    private func reportEmpty(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.gray)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .overlay(Rectangle().stroke(Color.gray.opacity(0.24), lineWidth: 1))
    }
}

private struct FreshbagRatioShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
