import SwiftUI
import Supabase

struct FeaturePlaceholderView: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MaroowellTheme.yellow.opacity(0.2))
                Image(systemName: symbol)
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(MaroowellTheme.deepYellow)
            }
            .frame(width: 112, height: 112)

            Text(title)
                .font(.title2.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(MaroowellTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)

            Text("iOS 네이티브 이식 진행 중")
                .font(.caption.weight(.bold))
                .foregroundStyle(MaroowellTheme.deepYellow)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(MaroowellTheme.yellow.opacity(0.14), in: Capsule())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaroowellTheme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScheduleCampOption: Identifiable, Hashable {
    let name: String
    let wave: String
    let waveLabel: String

    var id: String { "\(name)|\(wave)" }

    static let all: [ScheduleCampOption] = [
        .init(name: "일산2", wave: "WAVE2", waveLabel: "주간"),
        .init(name: "용인1", wave: "WAVE2", waveLabel: "주간"),
        .init(name: "용인3", wave: "WAVE2", waveLabel: "주간"),
        .init(name: "대구2", wave: "WAVE2", waveLabel: "주간"),
        .init(name: "대구3", wave: "WAVE2", waveLabel: "주간"),
        .init(name: "M익산1", wave: "WAVE1", waveLabel: "야간")
    ]
}

private struct ScheduleWeekData: Decodable {
    let routes: [ScheduleRouteSource]
    let schedules: [ScheduleAssignment]
    let drivers: [ScheduleDriverSource]

    enum CodingKeys: String, CodingKey { case routes, schedules, drivers }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routes = try container.decodeIfPresent([ScheduleRouteSource].self, forKey: .routes) ?? []
        schedules = try container.decodeIfPresent([ScheduleAssignment].self, forKey: .schedules) ?? []
        drivers = try container.decodeIfPresent([ScheduleDriverSource].self, forKey: .drivers) ?? []
    }
}

private struct ScheduleRouteSource: Decodable {
    let camp: String
    let route: String
    let sub: String
    let subSub: String
    let routeLabel: String
    let parentRouteLabel: String
    let description: String
    let memo: String
    let sortOrder: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case camp, route, sub, description, memo
        case subSub = "sub_sub"
        case routeLabel = "route_label"
        case parentRouteLabel = "parent_route_label"
        case sortOrder = "sort_order"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        camp = c.flexibleString(.camp)
        route = c.flexibleString(.route)
        sub = c.flexibleString(.sub)
        subSub = c.flexibleString(.subSub)
        routeLabel = c.flexibleString(.routeLabel)
        parentRouteLabel = c.flexibleString(.parentRouteLabel)
        description = c.flexibleString(.description)
        memo = c.flexibleString(.memo)
        sortOrder = c.flexibleInt(.sortOrder)
        isActive = c.flexibleBool(.isActive, fallback: true)
    }
}

private struct ScheduleAssignment: Decodable {
    let scheduleDate: String
    let wave: String
    let routeLabel: String
    let driverName: String
    let driverDisplayName: String
    let driverOwnerName: String
    let driverExportName: String
    let driverCoupangID: String
    let driverAccountType: String
    let memo: String
    let rowOrder: Int
    let cellColor: String
    let isActive: Bool

    var displayValue: String { driverDisplayName.isEmpty ? driverName : driverDisplayName }

    enum CodingKeys: String, CodingKey {
        case wave, memo
        case scheduleDate = "schedule_date"
        case routeLabel = "route_label"
        case driverName = "driver_name"
        case driverDisplayName = "driver_display_name"
        case driverOwnerName = "driver_owner_name"
        case driverExportName = "driver_export_name"
        case driverCoupangID = "driver_coupang_id"
        case driverAccountType = "driver_account_type"
        case rowOrder = "row_order"
        case cellColor = "cell_color"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scheduleDate = c.flexibleString(.scheduleDate)
        wave = ScheduleTools.normalizeWave(c.flexibleString(.wave))
        routeLabel = ScheduleTools.normalizeRoute(c.flexibleString(.routeLabel))
        driverName = c.flexibleString(.driverName)
        driverDisplayName = c.flexibleString(.driverDisplayName)
        driverOwnerName = c.flexibleString(.driverOwnerName)
        driverExportName = c.flexibleString(.driverExportName)
        driverCoupangID = c.flexibleString(.driverCoupangID)
        driverAccountType = c.flexibleString(.driverAccountType)
        memo = c.flexibleString(.memo)
        rowOrder = c.flexibleInt(.rowOrder)
        cellColor = c.flexibleString(.cellColor)
        isActive = c.flexibleBool(.isActive, fallback: true)
    }

    init(
        scheduleDate: String,
        wave: String,
        routeLabel: String,
        driverName: String,
        driverDisplayName: String,
        driverOwnerName: String,
        driverExportName: String,
        driverCoupangID: String,
        driverAccountType: String,
        memo: String,
        rowOrder: Int,
        cellColor: String,
        isActive: Bool
    ) {
        self.scheduleDate = scheduleDate
        self.wave = wave
        self.routeLabel = routeLabel
        self.driverName = driverName
        self.driverDisplayName = driverDisplayName
        self.driverOwnerName = driverOwnerName
        self.driverExportName = driverExportName
        self.driverCoupangID = driverCoupangID
        self.driverAccountType = driverAccountType
        self.memo = memo
        self.rowOrder = rowOrder
        self.cellColor = cellColor
        self.isActive = isActive
    }

    func promoted(to route: String, rowOrder: Int) -> ScheduleAssignment {
        .init(
            scheduleDate: scheduleDate,
            wave: wave,
            routeLabel: route,
            driverName: driverName,
            driverDisplayName: driverDisplayName,
            driverOwnerName: driverOwnerName,
            driverExportName: driverExportName,
            driverCoupangID: driverCoupangID,
            driverAccountType: driverAccountType,
            memo: memo,
            rowOrder: rowOrder,
            cellColor: cellColor,
            isActive: isActive
        )
    }
}

private struct ScheduleDriverSource: Decodable {
    let personName: String
    let camp: String
    let wave: String
    let coupangID: String
    let coupangAdminName: String
    let position: String

    enum CodingKeys: String, CodingKey {
        case personName = "person_name"
        case name
        case campCode = "camp_code"
        case camp
        case waveRaw = "wave_raw"
        case wave
        case coupangID = "coupang_id"
        case coupangAdminName = "coupang_admin_name"
        case position = "position_title"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let primaryName = c.flexibleString(.personName)
        personName = primaryName.isEmpty ? c.flexibleString(.name) : primaryName
        let primaryCamp = c.flexibleString(.campCode)
        camp = primaryCamp.isEmpty ? c.flexibleString(.camp) : primaryCamp
        let primaryWave = c.flexibleString(.waveRaw)
        wave = primaryWave.isEmpty ? c.flexibleString(.wave) : primaryWave
        coupangID = c.flexibleString(.coupangID)
        coupangAdminName = c.flexibleString(.coupangAdminName)
        position = c.flexibleString(.position)
    }
}

private struct ScheduleDriverAccount: Identifiable, Hashable {
    let displayName: String
    let ownerName: String
    let exportName: String
    let exportID: String
    let accountType: String

    var id: String { ScheduleTools.accountKey(displayName) }
}

private struct ScheduleRouteRow: Identifiable, Hashable {
    let label: String
    let parentKey: String
    let isChild: Bool
    let hasChildren: Bool
    let isOff: Bool
    let description: String
    let rowOrder: Int

    var id: String { "\(parentKey)|\(label)|\(isChild ? "1" : "0")" }
}

private struct ScheduleCellKey: Hashable {
    let date: String
    let routeLabel: String
}

private struct ScheduleSaveRow: Encodable {
    let scheduleDate: String
    let isoYear: Int
    let isoWeek: Int
    let weekLabel: String
    let camp: String
    let wave: String
    let routeLabel: String
    let driverName: String?
    let driverDisplayName: String?
    let driverOwnerName: String?
    let driverExportName: String?
    let driverCoupangID: String?
    let driverAccountType: String?
    let memo: String?
    let rowOrder: Int
    let cellColor: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case camp, wave, memo
        case scheduleDate = "schedule_date"
        case isoYear = "iso_year"
        case isoWeek = "iso_week"
        case weekLabel = "week_label"
        case routeLabel = "route_label"
        case driverName = "driver_name"
        case driverDisplayName = "driver_display_name"
        case driverOwnerName = "driver_owner_name"
        case driverExportName = "driver_export_name"
        case driverCoupangID = "driver_coupang_id"
        case driverAccountType = "driver_account_type"
        case rowOrder = "row_order"
        case cellColor = "cell_color"
        case isActive = "is_active"
    }
}

private struct ScheduleSaveEnvelope: Encodable { let rows: [ScheduleSaveRow] }

private struct ScheduleSaveResult: Decodable {
    let saved: Int?
    let deleted: Int?
    let skipped: Int?
}

private enum ScheduleTools {
    static let offRouteLabel = "휴무자"
    private static let locale = Locale(identifier: "ko_KR")

    static func normalizeRoute(_ value: String) -> String {
        let allowed = value.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || (0xAC00...0xD7A3).contains(scalar.value)
        }
        return String(String.UnicodeScalarView(allowed)).uppercased(with: locale)
    }

    static func normalizeWave(_ value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        return ["야간", "NIGHT", "N", "W1", "WAVE1"].contains(raw) ? "WAVE1" : "WAVE2"
    }

    static func campMatches(_ left: String, _ right: String) -> Bool {
        normalizeCamp(left) == normalizeCamp(right)
    }

    static func accountKey(_ value: String) -> String {
        value.components(separatedBy: .whitespacesAndNewlines).joined().uppercased(with: locale)
    }

    static func parseAccountToken(_ rawValue: String, defaultName: String) -> (String, String) {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return ("", defaultName.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let parts = raw.split(whereSeparator: { $0 == "/" || $0 == "／" }).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if parts.count < 2 { return (raw, defaultName.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let first = parts.first ?? ""
        let last = parts.last ?? ""
        let rest = parts.dropFirst().joined(separator: " / ")
        if looksLikeID(first), !looksLikeID(rest) { return (first, rest) }
        if !looksLikeID(first), looksLikeID(last) { return (last, first) }
        if looksLikeID(first) { return (first, rest) }
        if looksLikeID(last) { return (last, first) }
        return (first, rest)
    }

    static func excludedPosition(_ value: String) -> Bool {
        let normalized = value.replacingOccurrences(of: " ", with: "").uppercased(with: locale)
        return ["퇴사", "퇴직", "RETIRED", "RESIGNED", "INACTIVE", "서브", "SUB"].contains { normalized.contains($0) }
    }

    private static func normalizeCamp(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "").uppercased(with: locale)
    }

    private static func looksLikeID(_ value: String) -> Bool {
        !value.contains { $0 >= "가" && $0 <= "힣" } && value.contains { $0.isLetter || $0.isNumber }
    }
}

private enum ScheduleDateTools {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    private static var isoWeekCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static func iso(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func sunday(of date: Date = .now) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        return calendar.date(byAdding: .day, value: -(weekday - 1), to: start) ?? start
    }

    static func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func weekDates(_ sunday: Date) -> [Date] {
        (0...6).map { addingDays($0, to: sunday) }
    }

    static func weekInfo(_ sunday: Date) -> (Int, Int) {
        let monday = addingDays(1, to: sunday)
        let parts = isoWeekCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: monday)
        return (parts.yearForWeekOfYear ?? calendar.component(.year, from: monday), parts.weekOfYear ?? 1)
    }

    static func weekLabel(_ sunday: Date) -> String {
        let info = weekInfo(sunday)
        return "\(info.0) - \(info.1)W"
    }

    static func rangeLabel(_ sunday: Date) -> String {
        let dates = weekDates(sunday)
        guard let first = dates.first, let last = dates.last else { return "" }
        return "\(monthDay(first)) ~ \(monthDay(last))"
    }

    static func dayLabel(_ date: Date) -> String {
        "\(monthDay(date))\n\(weekday(date))"
    }

    static func fullDayLabel(_ date: Date) -> String {
        "\(monthDay(date)) (\(weekday(date)))"
    }

    static func defaultDayIndex(_ sunday: Date) -> Int {
        let today = iso(.now)
        return weekDates(sunday).firstIndex { iso($0) == today } ?? 0
    }

    private static func monthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private static func weekday(_ date: Date) -> String {
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        return names[max(1, min(7, calendar.component(.weekday, from: date))) - 1]
    }
}

private struct ScheduleAPI {
    private let baseURL = URL(string: "https://schedule.maroowell.com")!

    func loadWeek(camp: String, wave: String, weekStart: Date) async throws -> ScheduleWeekData {
        let token = try await accessToken()
        var components = URLComponents(url: baseURL.appending(path: "schedule/week"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "camp", value: camp),
            .init(name: "wave", value: wave),
            .init(name: "week_start", value: ScheduleDateTools.iso(weekStart))
        ]
        guard let url = components.url else { throw ScheduleAPIError.message("입차 스케줄 주소를 만들지 못했습니다.") }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response: response, data: data)
        return try JSONDecoder().decode(ScheduleWeekData.self, from: data)
    }

    func save(rows: [ScheduleSaveRow]) async throws -> ScheduleSaveResult {
        let token = try await accessToken()
        let url = baseURL.appending(path: "schedule/save")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(ScheduleSaveEnvelope(rows: rows))
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response: response, data: data)
        return (try? JSONDecoder().decode(ScheduleSaveResult.self, from: data)) ?? ScheduleSaveResult(saved: rows.count, deleted: nil, skipped: nil)
    }

    private func accessToken() async throws -> String {
        let session = try await SupabaseService.shared.client.auth.session
        return session.accessToken
    }

    private func check(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ScheduleAPIError.message("입차 스케줄 서버 응답을 확인하지 못했습니다.") }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 { throw ScheduleAPIError.message("로그인 세션이 만료되었습니다. 다시 로그인해주세요.") }
            if http.statusCode == 403 { throw ScheduleAPIError.message("입차 스케줄을 조회하거나 수정할 권한이 없습니다.") }
            let fallback = "입차 스케줄 서버 오류가 발생했습니다. (\(http.statusCode))"
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let detail = (object["error"] as? String) ?? (object["message"] as? String) ?? (object["detail"] as? String)
                throw ScheduleAPIError.message(detail?.isEmpty == false ? detail! : fallback)
            }
            throw ScheduleAPIError.message(fallback)
        }
    }
}

private enum ScheduleAPIError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(value) = self { return value }; return nil }
}

@MainActor
private final class ScheduleViewModel: ObservableObject {
    @Published var selectedCamp: ScheduleCampOption?
    @Published var weekStart = ScheduleDateTools.sunday()
    @Published var selectedDayIndex = ScheduleDateTools.defaultDayIndex(ScheduleDateTools.sunday())
    @Published var routeRows: [ScheduleRouteRow] = []
    @Published var driverAccounts: [ScheduleDriverAccount] = []
    @Published var loading = false
    @Published var saving = false
    @Published var statusText = "캠프를 선택해주세요."
    @Published var errorMessage: String?
    @Published var saveMessage: String?
    @Published var dirtyCount = 0

    private let api = ScheduleAPI()
    private var allRouteRows: [ScheduleRouteRow] = []
    private var assignments: [ScheduleCellKey: ScheduleAssignment] = [:]
    private var workingValues: [ScheduleCellKey: String] = [:]
    private var dirtyKeys: Set<ScheduleCellKey> = []
    private var accountByKey: [String: ScheduleDriverAccount] = [:]
    private var expandedParents: Set<String> = []

    var selectedDate: Date { ScheduleDateTools.weekDates(weekStart)[selectedDayIndex] }
    var selectedDateISO: String { ScheduleDateTools.iso(selectedDate) }
    var weekLabel: String { ScheduleDateTools.weekLabel(weekStart) }
    var weekRange: String { ScheduleDateTools.rangeLabel(weekStart) }
    var isBusy: Bool { loading || saving }

    func chooseCamp(_ camp: ScheduleCampOption) async {
        if selectedCamp == camp { return }
        selectedCamp = camp
        clearWeek()
        await loadWeek()
    }

    func moveWeek(by days: Int) async {
        weekStart = days == 0 ? ScheduleDateTools.sunday() : ScheduleDateTools.addingDays(days, to: weekStart)
        selectedDayIndex = ScheduleDateTools.defaultDayIndex(weekStart)
        if selectedCamp != nil { await loadWeek() }
    }

    func selectDay(_ index: Int) {
        selectedDayIndex = max(0, min(6, index))
        refreshVisibleRows()
        updateStatus()
    }

    func loadWeek() async {
        guard let camp = selectedCamp, !isBusy else { return }
        loading = true
        statusText = "\(camp.name) \(camp.waveLabel) · 조회 중"
        errorMessage = nil
        defer { loading = false }
        do {
            let data = try await api.loadWeek(camp: camp.name, wave: camp.wave, weekStart: weekStart)
            apply(data: data, camp: camp)
        } catch {
            clearWeek(keepCamp: true)
            errorMessage = error.localizedDescription
            statusText = error.localizedDescription
        }
    }

    func value(for row: ScheduleRouteRow) -> String {
        value(for: ScheduleCellKey(date: selectedDateISO, routeLabel: row.label))
    }

    func isLocked(_ row: ScheduleRouteRow) -> Bool {
        let date = selectedDateISO
        if row.hasChildren && value(for: ScheduleCellKey(date: date, routeLabel: row.label)).isEmpty {
            return childRows(row.label).contains { !value(for: ScheduleCellKey(date: date, routeLabel: $0.label)).isEmpty }
        }
        if row.isChild {
            return !value(for: ScheduleCellKey(date: date, routeLabel: row.parentKey)).isEmpty
        }
        return false
    }

    func edit(row: ScheduleRouteRow, value raw: String) {
        let date = selectedDateISO
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = ScheduleCellKey(date: date, routeLabel: row.label)
        setValue(value, for: key)
        if !value.isEmpty && row.isChild {
            setValue("", for: ScheduleCellKey(date: date, routeLabel: row.parentKey))
        } else if !value.isEmpty && row.hasChildren {
            childRows(row.label).forEach { setValue("", for: ScheduleCellKey(date: date, routeLabel: $0.label)) }
        }
        if row.hasChildren && value.isEmpty { expandedParents.insert(row.label) }
        refreshVisibleRows()
        updateStatus()
    }

    func toggle(_ row: ScheduleRouteRow) {
        guard row.hasChildren else { return }
        if expandedParents.contains(row.label) { expandedParents.remove(row.label) } else { expandedParents.insert(row.label) }
        refreshVisibleRows()
    }

    func save() async {
        guard let camp = selectedCamp, !isBusy, !dirtyKeys.isEmpty else { return }
        saving = true
        errorMessage = nil
        let rows = dirtyKeys.map { makeSaveRow($0, camp: camp) }
        statusText = "변경사항 \(rows.count)건을 저장하는 중…"
        defer { saving = false }
        do {
            let result = try await api.save(rows: rows)
            let count = (result.saved ?? rows.count) + (result.deleted ?? 0)
            saveMessage = "입차 스케줄 \(count)건 저장 완료"
            await loadWeek()
        } catch {
            errorMessage = error.localizedDescription
            statusText = error.localizedDescription
        }
    }

    private func apply(data: ScheduleWeekData, camp: ScheduleCampOption) {
        assignments.removeAll()
        workingValues.removeAll()
        dirtyKeys.removeAll()
        dirtyCount = 0
        allRouteRows = buildRouteRows(data.routes, camp: camp)
        driverAccounts = buildAccounts(data.drivers, data.schedules, camp: camp)
        indexAccounts()
        let display = collapse(data.schedules)
        for assignment in display where assignment.isActive {
            let key = ScheduleCellKey(date: assignment.scheduleDate, routeLabel: ScheduleTools.normalizeRoute(assignment.routeLabel))
            assignments[key] = assignment
            workingValues[key] = assignment.displayValue
        }
        syncExpandedParents()
        updateStatus()
    }

    private func buildRouteRows(_ sources: [ScheduleRouteSource], camp: ScheduleCampOption) -> [ScheduleRouteRow] {
        struct Parent { var label: String; var description: String; var rowOrder: Int; var children: [ScheduleRouteSource] }
        let sources = sources.filter { $0.isActive && ScheduleTools.campMatches($0.camp, camp.name) }.sorted {
            let lp = parentLabel($0), rp = parentLabel($1)
            if lp != rp { return lp < rp }
            let lc = childLabel($0), rc = childLabel($1)
            if lc != rc { return lc < rc }
            return $0.sortOrder < $1.sortOrder
        }
        var parents: [String: Parent] = [:]
        var order: [String] = []
        for source in sources {
            let parent = parentLabel(source)
            let child = childLabel(source)
            if parent.isEmpty && child.isEmpty { continue }
            let key = parent.isEmpty ? child : parent
            if parents[key] == nil {
                parents[key] = Parent(label: key, description: source.description.isEmpty ? source.memo : source.description, rowOrder: source.sortOrder, children: [])
                order.append(key)
            }
            if !child.isEmpty && child != key { parents[key]?.children.append(source) }
        }
        var rows: [ScheduleRouteRow] = [.init(label: ScheduleTools.offRouteLabel, parentKey: ScheduleTools.offRouteLabel, isChild: false, hasChildren: false, isOff: true, description: "휴무 인원을 쉼표로 구분해 입력할 수 있습니다.", rowOrder: -1)]
        for key in order {
            guard let parent = parents[key] else { continue }
            rows.append(.init(label: parent.label, parentKey: parent.label, isChild: false, hasChildren: !parent.children.isEmpty, isOff: false, description: parent.description, rowOrder: parent.rowOrder))
            for child in parent.children {
                rows.append(.init(label: childLabel(child), parentKey: parent.label, isChild: true, hasChildren: false, isOff: false, description: child.description.isEmpty ? child.memo : child.description, rowOrder: child.sortOrder))
            }
        }
        return rows
    }

    private func buildAccounts(_ drivers: [ScheduleDriverSource], _ existing: [ScheduleAssignment], camp: ScheduleCampOption) -> [ScheduleDriverAccount] {
        var indexed: [String: ScheduleDriverAccount] = [:]
        for source in drivers where (source.camp.isEmpty || ScheduleTools.campMatches(source.camp, camp.name)) && !ScheduleTools.excludedPosition(source.position) {
            let parsed = ScheduleTools.parseAccountToken(source.coupangID, defaultName: source.personName)
            let display = !source.personName.isEmpty ? source.personName : (!source.coupangAdminName.isEmpty ? source.coupangAdminName : (!parsed.1.isEmpty ? parsed.1 : parsed.0))
            guard !display.isEmpty else { continue }
            let account = ScheduleDriverAccount(displayName: display, ownerName: source.personName.isEmpty ? display : source.personName, exportName: source.coupangAdminName.isEmpty ? (parsed.1.isEmpty ? display : parsed.1) : source.coupangAdminName, exportID: parsed.0, accountType: "본계정")
            indexed[ScheduleTools.accountKey(display), default: account] = indexed[ScheduleTools.accountKey(display)] ?? account
        }
        for row in existing where !row.displayValue.isEmpty {
            let display = row.displayValue
            let account = ScheduleDriverAccount(displayName: display, ownerName: row.driverOwnerName.isEmpty ? display : row.driverOwnerName, exportName: row.driverExportName.isEmpty ? display : row.driverExportName, exportID: row.driverCoupangID, accountType: row.driverAccountType.isEmpty ? "본계정" : row.driverAccountType)
            if indexed[ScheduleTools.accountKey(display)] == nil { indexed[ScheduleTools.accountKey(display)] = account }
        }
        return indexed.values.sorted { $0.displayName < $1.displayName }
    }

    private func indexAccounts() {
        accountByKey.removeAll()
        for account in driverAccounts {
            [account.displayName, account.ownerName, account.exportName, account.exportID].filter { !$0.isEmpty }.forEach {
                if accountByKey[ScheduleTools.accountKey($0)] == nil { accountByKey[ScheduleTools.accountKey($0)] = account }
            }
        }
    }

    private func collapse(_ raw: [ScheduleAssignment]) -> [ScheduleAssignment] {
        var map: [ScheduleCellKey: ScheduleAssignment] = [:]
        for row in raw where row.isActive {
            map[ScheduleCellKey(date: row.scheduleDate, routeLabel: ScheduleTools.normalizeRoute(row.routeLabel))] = row
        }
        for parent in allRouteRows where !parent.isOff && !parent.isChild && parent.hasChildren {
            let children = childRows(parent.label)
            for date in ScheduleDateTools.weekDates(weekStart).map(ScheduleDateTools.iso) {
                let childAssignments = children.compactMap { map[ScheduleCellKey(date: date, routeLabel: $0.label)] }
                guard childAssignments.count == children.count, !childAssignments.isEmpty, childAssignments.allSatisfy({ !$0.displayValue.isEmpty }) else { continue }
                let identity = ScheduleTools.accountKey(childAssignments[0].driverOwnerName.isEmpty ? childAssignments[0].displayValue : childAssignments[0].driverOwnerName)
                guard !identity.isEmpty, childAssignments.allSatisfy({ ScheduleTools.accountKey($0.driverOwnerName.isEmpty ? $0.displayValue : $0.driverOwnerName) == identity }) else { continue }
                let parentKey = ScheduleCellKey(date: date, routeLabel: parent.label)
                if let existing = map[parentKey] {
                    let parentIdentity = ScheduleTools.accountKey(existing.driverOwnerName.isEmpty ? existing.displayValue : existing.driverOwnerName)
                    if !parentIdentity.isEmpty && parentIdentity != identity { continue }
                } else if let first = childAssignments.first {
                    map[parentKey] = first.promoted(to: parent.label, rowOrder: childAssignments.map(\.rowOrder).min() ?? first.rowOrder)
                }
                children.forEach { map.removeValue(forKey: ScheduleCellKey(date: date, routeLabel: $0.label)) }
            }
        }
        return Array(map.values)
    }

    private func syncExpandedParents() {
        expandedParents.removeAll()
        for parent in allRouteRows where !parent.isOff && !parent.isChild && parent.hasChildren {
            let children = childRows(parent.label)
            let split = ScheduleDateTools.weekDates(weekStart).map(ScheduleDateTools.iso).contains { date in
                if !value(for: ScheduleCellKey(date: date, routeLabel: parent.label)).isEmpty { return false }
                return children.contains { !value(for: ScheduleCellKey(date: date, routeLabel: $0.label)).isEmpty }
            }
            if split { expandedParents.insert(parent.label) }
        }
        refreshVisibleRows()
    }

    private func refreshVisibleRows() {
        routeRows = allRouteRows.filter { !$0.isChild || expandedParents.contains($0.parentKey) }
    }

    private func childRows(_ parent: String) -> [ScheduleRouteRow] {
        allRouteRows.filter { $0.isChild && $0.parentKey == parent }
    }

    private func value(for key: ScheduleCellKey) -> String {
        workingValues[key] ?? assignments[key]?.displayValue ?? ""
    }

    private func setValue(_ value: String, for key: ScheduleCellKey) {
        workingValues[key] = value
        let original = assignments[key]?.displayValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.trimmingCharacters(in: .whitespacesAndNewlines) == original { dirtyKeys.remove(key) } else { dirtyKeys.insert(key) }
        dirtyCount = dirtyKeys.count
    }

    private func makeSaveRow(_ key: ScheduleCellKey, camp: ScheduleCampOption) -> ScheduleSaveRow {
        let value = value(for: key).trimmingCharacters(in: .whitespacesAndNewlines)
        let original = assignments[key]
        let unchanged = original?.displayValue.trimmingCharacters(in: .whitespacesAndNewlines) == value
        let account = accountByKey[ScheduleTools.accountKey(value)]
        let route = allRouteRows.first { $0.label == key.routeLabel }
        let info = ScheduleDateTools.weekInfo(weekStart)
        let active = !value.isEmpty
        return ScheduleSaveRow(
            scheduleDate: key.date,
            isoYear: info.0,
            isoWeek: info.1,
            weekLabel: ScheduleDateTools.weekLabel(weekStart),
            camp: camp.name,
            wave: camp.wave,
            routeLabel: ScheduleTools.normalizeRoute(key.routeLabel),
            driverName: active ? value : nil,
            driverDisplayName: active ? value : nil,
            driverOwnerName: !active ? nil : (unchanged ? (original?.driverOwnerName.isEmpty == false ? original?.driverOwnerName : value) : (account?.ownerName ?? value)),
            driverExportName: !active ? nil : (unchanged ? (original?.driverExportName.isEmpty == false ? original?.driverExportName : value) : (account?.exportName ?? value)),
            driverCoupangID: !active ? nil : (unchanged ? original?.driverCoupangID.nonEmpty : account?.exportID.nonEmpty),
            driverAccountType: !active ? nil : (unchanged ? (original?.driverAccountType.nonEmpty ?? "직접입력") : (account?.accountType ?? "직접입력")),
            memo: active && unchanged ? original?.memo.nonEmpty : nil,
            rowOrder: original?.rowOrder ?? route?.rowOrder ?? 0,
            cellColor: !active ? nil : (unchanged ? original?.cellColor.nonEmpty : nil),
            isActive: active
        )
    }

    private func parentLabel(_ source: ScheduleRouteSource) -> String {
        ScheduleTools.normalizeRoute(!source.parentRouteLabel.isEmpty ? source.parentRouteLabel : (!(source.route + source.sub).isEmpty ? source.route + source.sub : source.routeLabel))
    }

    private func childLabel(_ source: ScheduleRouteSource) -> String {
        let parent = parentLabel(source)
        guard !source.subSub.isEmpty else { return parent }
        let normalized = ScheduleTools.normalizeRoute(source.routeLabel)
        return !normalized.isEmpty && normalized != parent ? normalized : ScheduleTools.normalizeRoute(source.route + source.sub + source.subSub)
    }

    private func updateStatus() {
        guard let camp = selectedCamp else { statusText = "캠프를 선택해주세요."; return }
        statusText = "\(ScheduleDateTools.fullDayLabel(selectedDate)) · \(camp.name) \(camp.waveLabel) · 라우트 \(allRouteRows.filter { !$0.isOff && !$0.isChild }.count)개"
    }

    private func clearWeek(keepCamp: Bool = false) {
        if !keepCamp { selectedCamp = nil }
        assignments.removeAll(); workingValues.removeAll(); dirtyKeys.removeAll(); accountByKey.removeAll(); expandedParents.removeAll()
        allRouteRows = []; routeRows = []; driverAccounts = []; dirtyCount = 0
    }
}

struct ScheduleView: View {
    let session: AppSession
    @StateObject private var model = ScheduleViewModel()
    @State private var pendingCamp: ScheduleCampOption?
    @State private var pendingWeekDelta: Int?
    @State private var showDiscardAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                controls
                dayStrip
                statusBar

                if model.loading {
                    ProgressView("입차 스케줄 조회 중…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                } else if model.selectedCamp == nil {
                    emptyState("캠프를 선택하면 해당 주의 라우트 스케줄을 불러옵니다.")
                } else if model.routeRows.isEmpty {
                    emptyState("표시할 라우트가 없습니다.")
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(model.routeRows) { row in
                            ScheduleRouteEditor(model: model, row: row)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 80)
        }
        .background(MaroowellTheme.background)
        .navigationTitle("입차 스케줄")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { saveBar }
        .alert("변경사항을 버릴까요?", isPresented: $showDiscardAlert) {
            Button("계속 편집", role: .cancel) {}
            Button("버리고 이동", role: .destructive) { applyPendingNavigation() }
        } message: {
            Text("저장하지 않은 입차 스케줄 변경사항이 있습니다.")
        }
        .alert("입차 스케줄 오류", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("확인", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert("저장 완료", isPresented: Binding(get: { model.saveMessage != nil }, set: { if !$0 { model.saveMessage = nil } })) {
            Button("확인", role: .cancel) { model.saveMessage = nil }
        } message: {
            Text(model.saveMessage ?? "")
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.weekLabel).font(.headline.weight(.black))
                    Text(model.weekRange).font(.caption).foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                Text(model.selectedCamp?.waveLabel ?? "-")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(MaroowellTheme.yellow.opacity(0.18), in: Capsule())
            }

            HStack(spacing: 8) {
                Menu {
                    ForEach(ScheduleCampOption.all) { camp in
                        Button("\(camp.name) · \(camp.waveLabel)") { requestCamp(camp) }
                    }
                } label: {
                    Label(model.selectedCamp?.name ?? "캠프 선택", systemImage: "building.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MaroowellTheme.deepYellow)
                .disabled(model.isBusy)
            }

            HStack(spacing: 8) {
                Button("이전주") { requestWeek(-7) }
                Button("이번주") { requestWeek(0) }
                Button("다음주") { requestWeek(7) }
            }
            .buttonStyle(.bordered)
            .disabled(model.isBusy)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MaroowellTheme.border.opacity(0.8)) }
    }

    private var dayStrip: some View {
        HStack(spacing: 5) {
            ForEach(Array(ScheduleDateTools.weekDates(model.weekStart).enumerated()), id: \.offset) { index, date in
                Button {
                    model.selectDay(index)
                } label: {
                    Text(ScheduleDateTools.dayLabel(date))
                        .font(.system(size: 11, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(index == 0 ? Color.red : MaroowellTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(index == model.selectedDayIndex ? MaroowellTheme.yellow.opacity(0.22) : Color.white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).stroke(index == model.selectedDayIndex ? MaroowellTheme.deepYellow : MaroowellTheme.border.opacity(0.7), lineWidth: index == model.selectedDayIndex ? 2 : 1) }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Text(model.statusText).lineLimit(2)
            Spacer()
            Text("미저장 \(model.dirtyCount)").fontWeight(.bold)
        }
        .font(.caption)
        .foregroundStyle(MaroowellTheme.muted)
        .padding(.horizontal, 4)
    }

    private var saveBar: some View {
        Button {
            Task { await model.save() }
        } label: {
            HStack {
                if model.saving { ProgressView().tint(.white) }
                Text(model.dirtyCount > 0 ? "변경사항 \(model.dirtyCount)건 저장" : "변경사항 없음")
                    .font(.headline.weight(.black))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(MaroowellTheme.deepYellow)
        .disabled(model.dirtyCount == 0 || model.isBusy)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(MaroowellTheme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 50)
    }

    private func requestCamp(_ camp: ScheduleCampOption) {
        if model.dirtyCount > 0 { pendingCamp = camp; showDiscardAlert = true }
        else { Task { await model.chooseCamp(camp) } }
    }

    private func requestWeek(_ delta: Int) {
        if model.dirtyCount > 0 { pendingWeekDelta = delta; showDiscardAlert = true }
        else { Task { await model.moveWeek(by: delta) } }
    }

    private func applyPendingNavigation() {
        if let camp = pendingCamp {
            pendingCamp = nil
            Task { await model.chooseCamp(camp) }
        } else if let delta = pendingWeekDelta {
            pendingWeekDelta = nil
            Task { await model.moveWeek(by: delta) }
        }
    }
}

private struct ScheduleRouteEditor: View {
    @ObservedObject var model: ScheduleViewModel
    let row: ScheduleRouteRow

    var body: some View {
        let locked = model.isLocked(row)
        let current = model.value(for: row)
        HStack(alignment: .center, spacing: 10) {
            Button {
                model.toggle(row)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(row.label).font(.subheadline.weight(.black)).foregroundStyle(MaroowellTheme.ink)
                        if row.hasChildren { Image(systemName: "chevron.down").font(.caption2) }
                    }
                    if row.isOff { Text("휴무").foregroundStyle(MaroowellTheme.deepYellow) }
                    else if row.isChild { Text("세부 라우트").foregroundStyle(MaroowellTheme.muted) }
                    else if !row.description.isEmpty { Text(row.description).lineLimit(1).foregroundStyle(MaroowellTheme.muted) }
                }
                .font(.caption2)
                .frame(width: 92, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(!row.hasChildren)

            VStack(spacing: 5) {
                TextField(row.isOff ? "휴무자 (쉼표 구분)" : (locked ? "상·하위 라우트 배정됨" : "기사명 입력"), text: Binding(get: { model.value(for: row) }, set: { model.edit(row: row, value: $0) }))
                    .textFieldStyle(.roundedBorder)
                    .disabled(locked || model.isBusy)

                if !row.isOff && !locked {
                    Menu {
                        ForEach(model.driverAccounts) { account in
                            Button(account.displayName) { model.edit(row: row, value: account.displayName) }
                        }
                        if !current.isEmpty { Button("배정 지우기", role: .destructive) { model.edit(row: row, value: "") } }
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                            Text("기사 선택")
                            Spacer()
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }
        }
        .padding(12)
        .background(row.isOff ? MaroowellTheme.yellow.opacity(0.10) : Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(MaroowellTheme.border.opacity(0.75)) }
        .padding(.leading, row.isChild ? 14 : 0)
    }
}

private extension KeyedDecodingContainer {
    func flexibleString(_ key: Key) -> String {
        if let value = try? decode(String.self, forKey: key) { return value.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        return ""
    }

    func flexibleInt(_ key: Key) -> Int {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let raw = try? decode(String.self, forKey: key), let value = Int(raw) { return value }
        return 0
    }

    func flexibleBool(_ key: Key, fallback: Bool) -> Bool {
        if let value = try? decode(Bool.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return value != 0 }
        if let raw = try? decode(String.self, forKey: key) {
            if ["true", "1", "yes"].contains(raw.lowercased()) { return true }
            if ["false", "0", "no"].contains(raw.lowercased()) { return false }
        }
        return fallback
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
