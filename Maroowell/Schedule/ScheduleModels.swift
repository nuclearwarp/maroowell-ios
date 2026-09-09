import Foundation

struct ScheduleCampOption: Identifiable, Hashable {
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

struct ScheduleWeekData: Decodable {
    let routes: [ScheduleRouteSource]
    let schedules: [ScheduleAssignment]
    let drivers: [ScheduleDriverSource]

    enum CodingKeys: String, CodingKey {
        case routes
        case schedules
        case drivers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        routes = try container.decodeIfPresent([ScheduleRouteSource].self, forKey: .routes) ?? []
        schedules = try container.decodeIfPresent([ScheduleAssignment].self, forKey: .schedules) ?? []
        drivers = try container.decodeIfPresent([ScheduleDriverSource].self, forKey: .drivers) ?? []
    }
}

struct ScheduleRouteSource: Decodable, Hashable {
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
        case camp
        case route
        case sub
        case subSub = "sub_sub"
        case routeLabel = "route_label"
        case parentRouteLabel = "parent_route_label"
        case description
        case memo
        case sortOrder = "sort_order"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        camp = container.string(forKey: .camp)
        route = container.string(forKey: .route)
        sub = container.string(forKey: .sub)
        subSub = container.string(forKey: .subSub)
        routeLabel = container.string(forKey: .routeLabel)
        parentRouteLabel = container.string(forKey: .parentRouteLabel)
        description = container.string(forKey: .description)
        memo = container.string(forKey: .memo)
        sortOrder = container.int(forKey: .sortOrder)
        isActive = container.bool(forKey: .isActive, defaultValue: true)
    }
}

struct ScheduleAssignment: Decodable, Hashable {
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

    var displayValue: String {
        driverDisplayName.isEmpty ? driverName : driverDisplayName
    }

    enum CodingKeys: String, CodingKey {
        case scheduleDate = "schedule_date"
        case wave
        case routeLabel = "route_label"
        case driverName = "driver_name"
        case driverDisplayName = "driver_display_name"
        case driverOwnerName = "driver_owner_name"
        case driverExportName = "driver_export_name"
        case driverCoupangID = "driver_coupang_id"
        case driverAccountType = "driver_account_type"
        case memo
        case rowOrder = "row_order"
        case cellColor = "cell_color"
        case isActive = "is_active"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheduleDate = container.string(forKey: .scheduleDate)
        wave = ScheduleNormalization.wave(container.string(forKey: .wave))
        routeLabel = ScheduleNormalization.route(container.string(forKey: .routeLabel))
        driverName = container.string(forKey: .driverName)
        driverDisplayName = container.string(forKey: .driverDisplayName)
        driverOwnerName = container.string(forKey: .driverOwnerName)
        driverExportName = container.string(forKey: .driverExportName)
        driverCoupangID = container.string(forKey: .driverCoupangID)
        driverAccountType = container.string(forKey: .driverAccountType)
        memo = container.string(forKey: .memo)
        rowOrder = container.int(forKey: .rowOrder)
        cellColor = container.string(forKey: .cellColor)
        isActive = container.bool(forKey: .isActive, defaultValue: true)
    }

    func replacingRouteLabel(_ label: String, rowOrder: Int) -> ScheduleAssignment {
        ScheduleAssignment(
            scheduleDate: scheduleDate,
            wave: wave,
            routeLabel: label,
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

    private init(
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
}

struct ScheduleDriverSource: Decodable, Hashable {
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
        let container = try decoder.container(keyedBy: CodingKeys.self)
        personName = container.string(forKey: .personName).ifEmpty(container.string(forKey: .name))
        camp = container.string(forKey: .campCode).ifEmpty(container.string(forKey: .camp))
        wave = container.string(forKey: .waveRaw).ifEmpty(container.string(forKey: .wave))
        coupangID = container.string(forKey: .coupangID)
        coupangAdminName = container.string(forKey: .coupangAdminName)
        position = container.string(forKey: .position)
    }
}

struct ScheduleDriverAccount: Identifiable, Hashable {
    let displayName: String
    let ownerName: String
    let exportName: String
    let exportID: String
    let accountType: String

    var id: String { ScheduleNormalization.accountKey(displayName) }
}

struct ScheduleSaveResult: Decodable {
    let saved: Int
    let deleted: Int
    let skipped: Int

    enum CodingKeys: String, CodingKey {
        case saved
        case deleted
        case skipped
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        saved = container.int(forKey: .saved)
        deleted = container.int(forKey: .deleted)
        skipped = container.int(forKey: .skipped)
    }
}

struct ScheduleRouteRow: Identifiable, Hashable {
    let label: String
    let parentKey: String
    let isChild: Bool
    let hasChildren: Bool
    let isOff: Bool
    let description: String
    let rowOrder: Int

    var id: String { "\(parentKey)|\(label)|\(isChild ? 1 : 0)" }
}

struct ScheduleCellKey: Hashable {
    let date: String
    let routeLabel: String
}

struct ScheduleSaveRow: Encodable {
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
        case scheduleDate = "schedule_date"
        case isoYear = "iso_year"
        case isoWeek = "iso_week"
        case weekLabel = "week_label"
        case camp
        case wave
        case routeLabel = "route_label"
        case driverName = "driver_name"
        case driverDisplayName = "driver_display_name"
        case driverOwnerName = "driver_owner_name"
        case driverExportName = "driver_export_name"
        case driverCoupangID = "driver_coupang_id"
        case driverAccountType = "driver_account_type"
        case memo
        case rowOrder = "row_order"
        case cellColor = "cell_color"
        case isActive = "is_active"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(scheduleDate, forKey: .scheduleDate)
        try container.encode(isoYear, forKey: .isoYear)
        try container.encode(isoWeek, forKey: .isoWeek)
        try container.encode(weekLabel, forKey: .weekLabel)
        try container.encode(camp, forKey: .camp)
        try container.encode(wave, forKey: .wave)
        try container.encode(routeLabel, forKey: .routeLabel)
        try container.encodeNullable(driverName, forKey: .driverName)
        try container.encodeNullable(driverDisplayName, forKey: .driverDisplayName)
        try container.encodeNullable(driverOwnerName, forKey: .driverOwnerName)
        try container.encodeNullable(driverExportName, forKey: .driverExportName)
        try container.encodeNullable(driverCoupangID, forKey: .driverCoupangID)
        try container.encodeNullable(driverAccountType, forKey: .driverAccountType)
        try container.encodeNullable(memo, forKey: .memo)
        try container.encode(rowOrder, forKey: .rowOrder)
        try container.encodeNullable(cellColor, forKey: .cellColor)
        try container.encode(isActive, forKey: .isActive)
    }
}

struct ScheduleSaveEnvelope: Encodable {
    let rows: [ScheduleSaveRow]
}

enum ScheduleNormalization {
    static let offRouteLabel = "휴무자"

    static func route(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .filter { scalar in
                CharacterSet.alphanumerics.contains(scalar) ||
                (scalar.value >= 0xAC00 && scalar.value <= 0xD7A3)
            }
            .map(String.init)
            .joined()
            .uppercased(with: Locale(identifier: "ko_KR"))
    }

    static func wave(_ value: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        return ["야간", "NIGHT", "N", "W1", "WAVE1"].contains(normalized) ? "WAVE1" : "WAVE2"
    }

    static func campMatches(_ left: String, _ right: String) -> Bool {
        normalizeCamp(left) == normalizeCamp(right)
    }

    static func accountKey(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .uppercased(with: Locale(identifier: "ko_KR"))
    }

    private static func normalizeCamp(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased(with: Locale(identifier: "ko_KR"))
    }
}

enum ScheduleDatePolicy {
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

    private static var isoFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static var monthDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M/d"
        return formatter
    }

    static func iso(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func date(_ iso: String) -> Date? {
        isoFormatter.date(from: iso)
    }

    static func sunday(of date: Date = .now) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        return calendar.date(byAdding: .day, value: -(weekday - 1), to: start) ?? start
    }

    static func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func weekDates(sunday: Date) -> [Date] {
        (0...6).map { addingDays($0, to: sunday) }
    }

    static func weekInfo(sunday: Date) -> (year: Int, week: Int) {
        let monday = addingDays(1, to: sunday)
        let components = isoWeekCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: monday)
        return (components.yearForWeekOfYear ?? calendar.component(.year, from: monday), components.weekOfYear ?? 1)
    }

    static func weekLabel(sunday: Date) -> String {
        let info = weekInfo(sunday: sunday)
        return "\(info.year) - \(info.week)W"
    }

    static func rangeLabel(sunday: Date) -> String {
        let dates = weekDates(sunday: sunday)
        guard let first = dates.first, let last = dates.last else { return "" }
        return "\(monthDayFormatter.string(from: first)) ~ \(monthDayFormatter.string(from: last))"
    }

    static func dayLabel(_ date: Date) -> String {
        "\(monthDayFormatter.string(from: date))\n\(weekdayName(date))"
    }

    static func fullDayLabel(_ date: Date) -> String {
        "\(monthDayFormatter.string(from: date)) (\(weekdayName(date)))"
    }

    static func dayIndex(for date: Date = .now, inWeekStarting sunday: Date) -> Int {
        let target = iso(date)
        return weekDates(sunday: sunday).firstIndex { iso($0) == target } ?? 0
    }

    private static func weekdayName(_ date: Date) -> String {
        let names = ["일", "월", "화", "수", "목", "금", "토"]
        let index = max(1, min(7, calendar.component(.weekday, from: date))) - 1
        return names[index]
    }
}

private extension KeyedDecodingContainer {
    func string(forKey key: Key) -> String {
        if let value = try? decode(String.self, forKey: key) {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        return ""
    }

    func int(forKey key: Key) -> Int {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let raw = try? decode(String.self, forKey: key), let value = Int(raw) { return value }
        return 0
    }

    func bool(forKey key: Key, defaultValue: Bool) -> Bool {
        if let value = try? decode(Bool.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return value != 0 }
        if let raw = try? decode(String.self, forKey: key) {
            switch raw.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: break
            }
        }
        return defaultValue
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeNullable(_ value: String?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: @autoclosure () -> String) -> String {
        isEmpty ? fallback() : self
    }
}
