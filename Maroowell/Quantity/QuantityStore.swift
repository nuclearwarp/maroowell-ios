import Combine
import Foundation

@MainActor
final class QuantityStore: ObservableObject {
    static let shared = QuantityStore()

    @Published private(set) var revision: Int = 0

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var calendar: Calendar
    private let isoFormatter: DateFormatter

    private init() {
        defaults = UserDefaults(suiteName: "maroowell_quantity_ios") ?? .standard

        var configuredCalendar = Calendar(identifier: .gregorian)
        configuredCalendar.locale = Locale(identifier: "ko_KR")
        configuredCalendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        calendar = configuredCalendar

        let formatter = DateFormatter()
        formatter.calendar = configuredCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = configuredCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        isoFormatter = formatter
    }

    func dateKey(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    func date(from key: String) -> Date? {
        isoFormatter.date(from: key)
    }

    func load(_ date: Date) -> QuantityRecord? {
        load(dateKey: dateKey(date))
    }

    func load(dateKey: String) -> QuantityRecord? {
        guard let data = defaults.data(forKey: "record_\(dateKey)") else { return nil }
        return try? decoder.decode(QuantityRecord.self, from: data)
    }

    func hasRecord(_ date: Date) -> Bool {
        defaults.object(forKey: "record_\(dateKey(date))") != nil
    }

    func save(_ record: QuantityRecord, for date: Date) throws {
        let data = try encoder.encode(record)
        defaults.set(data, forKey: "record_\(dateKey(date))")
        revision &+= 1
    }

    func settlementPeriod(containing anchor: Date) -> (start: Date, end: Date) {
        let components = calendar.dateComponents([.year, .month, .day], from: anchor)
        let day = components.day ?? 1

        if day <= 25 {
            let end = calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: components.year,
                month: components.month,
                day: 25,
                hour: 12
            )) ?? anchor
            let previous = calendar.date(byAdding: .month, value: -1, to: end) ?? anchor
            let previousComponents = calendar.dateComponents([.year, .month], from: previous)
            let start = calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: previousComponents.year,
                month: previousComponents.month,
                day: 26,
                hour: 12
            )) ?? anchor
            return (start, end)
        }

        let start = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: components.year,
            month: components.month,
            day: 26,
            hour: 12
        )) ?? anchor
        let next = calendar.date(byAdding: .month, value: 1, to: start) ?? anchor
        let nextComponents = calendar.dateComponents([.year, .month], from: next)
        let end = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: nextComponents.year,
            month: nextComponents.month,
            day: 25,
            hour: 12
        )) ?? anchor
        return (start, end)
    }

    func settlementSummary(anchor: Date) -> QuantitySettlementSummary {
        let period = settlementPeriod(containing: anchor)
        let dates = recordDates(in: period.start...period.end)
        let records = dates.compactMap(load)
        let endComponents = calendar.dateComponents([.year, .month], from: period.end)

        return QuantitySettlementSummary(
            settlementYear: endComponents.year ?? 0,
            settlementMonth: endComponents.month ?? 0,
            startDate: period.start,
            endDate: period.end,
            days: records.count,
            total: records.reduce(0) { $0 + amount(of: $1) }
        )
    }

    func settlementCounts(anchor: Date) -> QuantitySettlementCounts {
        let period = settlementPeriod(containing: anchor)
        var result = QuantitySettlementCounts()

        for record in recordDates(in: period.start...period.end).compactMap(load) {
            for route in record.routes {
                result.delivery += Int64(route.values[QuantityLineKey.delivery.rawValue]?.count ?? 0)
                result.delivery += Int64(route.values[QuantityLineKey.deliveryStop.rawValue]?.count ?? 0)
                result.returns += Int64(route.values[QuantityLineKey.returns.rawValue]?.count ?? 0)
                result.freshbag += Int64(route.values[QuantityLineKey.freshbag.rawValue]?.count ?? 0)
            }
        }
        return result
    }

    func monthSummary(containing date: Date) -> QuantityMonthSummary {
        let start = monthStart(date)
        guard let next = calendar.date(byAdding: .month, value: 1, to: start),
              let end = calendar.date(byAdding: .second, value: -1, to: next) else {
            return QuantityMonthSummary(days: 0, total: 0, count: 0)
        }

        let records = recordDates(in: start...end).compactMap(load)
        return QuantityMonthSummary(
            days: records.count,
            total: records.reduce(0) { $0 + amount(of: $1) },
            count: records.reduce(0) { $0 + count(of: $1) }
        )
    }

    func monthlyTrendPoints(endingAt selectedMonth: Date, monthCount: Int = 6) -> [QuantityTrendPoint] {
        let endMonth = monthStart(selectedMonth)
        return (0..<monthCount).reversed().compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: endMonth) else { return nil }
            let summary = monthSummary(containing: month)
            let components = calendar.dateComponents([.year, .month], from: month)
            let label = String(format: "%02d.%02d", (components.year ?? 0) % 100, components.month ?? 0)
            return QuantityTrendPoint(date: month, label: label, amount: summary.total, count: summary.count)
        }
    }

    func settlementDailyPoints(anchor: Date) -> [QuantityTrendPoint] {
        let period = settlementPeriod(containing: anchor)
        return recordDates(in: period.start...period.end).compactMap { date in
            guard let record = load(date) else { return nil }
            let components = calendar.dateComponents([.month, .day], from: date)
            let label = String(format: "%02d/%02d", components.month ?? 0, components.day ?? 0)
            return QuantityTrendPoint(
                date: date,
                label: label,
                amount: amount(of: record),
                count: count(of: record)
            )
        }
    }

    func recentRoutePrices(anchor: Date, campName: String, routeName: String) -> [QuantityLineKey: Int] {
        let normalizedCamp = campName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRoute = routeName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalizedRoute.isEmpty else { return [:] }

        let period = settlementPeriod(containing: anchor)
        let currentKey = dateKey(anchor)
        let candidateDates = recordDates(in: period.start...period.end)
            .filter { dateKey($0) < currentKey }
            .sorted(by: >)

        for date in candidateDates {
            guard let record = load(date) else { continue }
            if let route = record.routes.first(where: {
                $0.routeName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == normalizedRoute &&
                $0.campName.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedCamp
            }) {
                var result: [QuantityLineKey: Int] = [:]
                for key in QuantityLineKey.allCases {
                    let lookup = key.followsDeliveryPrice ? QuantityLineKey.delivery : key
                    result[key] = route.values[lookup.rawValue]?.unitPrice ?? 0
                }
                return result
            }
        }
        return [:]
    }

    func amount(of record: QuantityRecord) -> Int64 {
        record.routes.reduce(0) { partial, route in
            partial + route.values.reduce(0) { lineTotal, pair in
                let key = QuantityLineKey(rawValue: pair.key)
                let amount = Int64(pair.value.count) * Int64(pair.value.unitPrice)
                return lineTotal + ((key?.isNegative == true) ? -amount : amount)
            }
        }
    }

    func count(of record: QuantityRecord) -> Int64 {
        record.routes.reduce(0) { partial, route in
            partial
                + Int64(route.values[QuantityLineKey.delivery.rawValue]?.count ?? 0)
                + Int64(route.values[QuantityLineKey.deliveryStop.rawValue]?.count ?? 0)
                + Int64(route.values[QuantityLineKey.returns.rawValue]?.count ?? 0)
        }
    }

    func movingMonth(_ date: Date, by delta: Int) -> Date {
        calendar.date(byAdding: .month, value: delta, to: date) ?? date
    }

    func movingDay(_ date: Date, by delta: Int) -> Date {
        calendar.date(byAdding: .day, value: delta, to: date) ?? date
    }

    func monthStart(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: components.year,
            month: components.month,
            day: 1,
            hour: 12
        )) ?? date
    }

    private func allRecordDates() -> [Date] {
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("record_") }
            .compactMap { date(from: String($0.dropFirst("record_".count))) }
            .sorted()
    }

    private func recordDates(in range: ClosedRange<Date>) -> [Date] {
        allRecordDates().filter { range.contains($0) }
    }
}
