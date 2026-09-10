import Combine
import Foundation

@MainActor
final class InspectionStore: ObservableObject {
    static let shared = InspectionStore()

    @Published private(set) var revision = 0

    private let defaults: UserDefaults
    private let legacyDefaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var calendar: Calendar
    private let isoFormatter: DateFormatter

    private init() {
        defaults = .standard
        legacyDefaults = UserDefaults(suiteName: "maroowell_daily_inspection_ios")

        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ko_KR")
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        calendar = cal

        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = cal.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        isoFormatter = formatter

        migrateLegacyStorageIfNeeded()
    }

    func loadProfile() -> InspectionProfile {
        guard let data = storedData(forKey: "profile") else { return InspectionProfile() }
        return (try? decoder.decode(InspectionProfile.self, from: data)) ?? InspectionProfile()
    }

    func saveProfile(_ profile: InspectionProfile) {
        if let data = try? encoder.encode(profile) {
            storeData(data, forKey: "profile")
            revision &+= 1
        }
    }

    func loadSignature() -> InspectionSignature {
        guard let data = storedData(forKey: "signature") else { return InspectionSignature() }
        return (try? decoder.decode(InspectionSignature.self, from: data)) ?? InspectionSignature()
    }

    func saveSignature(_ signature: InspectionSignature) {
        if let data = try? encoder.encode(signature) {
            storeData(data, forKey: "signature")
            revision &+= 1
        }
    }

    func hasSignature() -> Bool {
        !loadSignature().isEmpty
    }

    func monthKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }

    func dayNumber(for date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    func loadMonth(_ date: Date) -> [Int: InspectionDayRecord] {
        let key = "month_\(monthKey(for: date))"
        guard let data = storedData(forKey: key) else { return [:] }
        return (try? decoder.decode([Int: InspectionDayRecord].self, from: data)) ?? [:]
    }

    func loadDay(_ date: Date) -> InspectionDayRecord? {
        loadMonth(date)[dayNumber(for: date)]
    }

    func hasDay(_ date: Date) -> Bool {
        loadDay(date) != nil
    }

    func saveDay(_ date: Date, record: InspectionDayRecord) {
        var month = loadMonth(date)
        month[dayNumber(for: date)] = record
        persistMonth(month, for: date)
    }

    func deleteDay(_ date: Date) {
        var month = loadMonth(date)
        month.removeValue(forKey: dayNumber(for: date))
        persistMonth(month, for: date)
    }

    func movingMonth(_ date: Date, by delta: Int) -> Date {
        calendar.date(byAdding: .month, value: delta, to: date) ?? date
    }

    func startOfMonth(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: comps.year,
            month: comps.month,
            day: 1,
            hour: 12
        )) ?? date
    }

    func date(inMonth month: Date, day: Int) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: month)
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: comps.year,
            month: comps.month,
            day: day,
            hour: 12
        )) ?? month
    }

    func daysInMonth(_ date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    func isFuture(_ date: Date) -> Bool {
        let selected = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        return selected > today
    }

    func missingPastDays(in month: Date) -> [Int] {
        let records = loadMonth(month)
        let monthStart = startOfMonth(month)
        let today = Date()
        let currentMonth = startOfMonth(today)
        let endDay: Int

        if monthStart > currentMonth {
            endDay = 0
        } else if monthStart < currentMonth {
            endDay = daysInMonth(month)
        } else {
            endDay = max(0, calendar.component(.day, from: today) - 1)
        }

        guard endDay > 0 else { return [] }
        return (1...endDay).filter { records[$0] == nil }
    }

    func weekdayLabel(for date: Date) -> String {
        switch calendar.component(.weekday, from: date) {
        case 1: return "일"
        case 2: return "월"
        case 3: return "화"
        case 4: return "수"
        case 5: return "목"
        case 6: return "금"
        case 7: return "토"
        default: return ""
        }
    }

    func isSunday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 1
    }

    func isSaturday(_ date: Date) -> Bool {
        calendar.component(.weekday, from: date) == 7
    }

    private func persistMonth(_ month: [Int: InspectionDayRecord], for date: Date) {
        let key = "month_\(monthKey(for: date))"
        if month.isEmpty {
            defaults.removeObject(forKey: key)
            legacyDefaults?.removeObject(forKey: key)
        } else if let data = try? encoder.encode(month) {
            storeData(data, forKey: key)
        }
        revision &+= 1
    }

    private func storedData(forKey key: String) -> Data? {
        if let data = defaults.data(forKey: key) {
            return data
        }
        if let data = legacyDefaults?.data(forKey: key) {
            defaults.set(data, forKey: key)
            return data
        }
        return nil
    }

    private func storeData(_ data: Data, forKey key: String) {
        defaults.set(data, forKey: key)
        legacyDefaults?.set(data, forKey: key)
    }

    private func migrateLegacyStorageIfNeeded() {
        guard let legacyDefaults else { return }
        for (key, value) in legacyDefaults.dictionaryRepresentation() {
            guard key == "profile" || key == "signature" || key.hasPrefix("month_") else { continue }
            guard defaults.object(forKey: key) == nil else { continue }
            defaults.set(value, forKey: key)
        }
    }
}
