import Foundation

@MainActor
final class HomeCalendarMemoStore: ObservableObject {
    static let shared = HomeCalendarMemoStore()

    @Published private(set) var revision = 0
    private let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: "maroowell_calendar_memos_ios") ?? .standard
    }

    func memo(for date: Date) -> String {
        memo(forKey: ScheduleDatePolicy.iso(date))
    }

    func memo(forKey dateKey: String) -> String {
        defaults.string(forKey: "memo_\(dateKey)")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func save(_ value: String, for date: Date) {
        save(value, forKey: ScheduleDatePolicy.iso(date))
    }

    func save(_ value: String, forKey dateKey: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: "memo_\(dateKey)")
        } else {
            defaults.set(trimmed, forKey: "memo_\(dateKey)")
        }
        revision &+= 1
    }
}

private struct HomeHolidayRow: Decodable {
    let date: String
    let localName: String?
    let name: String?
}

@MainActor
final class HomeHolidayStore: ObservableObject {
    @Published private(set) var holidaysByDate: [String: String] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var loadedYears: Set<Int> = []
    private var calendar: Calendar

    init() {
        var configured = Calendar(identifier: .gregorian)
        configured.locale = Locale(identifier: "ko_KR")
        configured.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        calendar = configured
    }

    func holiday(for date: Date) -> String {
        holidaysByDate[ScheduleDatePolicy.iso(date)] ?? ""
    }

    func load(dates: [Date], force: Bool = false) async {
        let years = Set(dates.map { calendar.component(.year, from: $0) })
        let targets = force ? years : years.subtracting(loadedYears)
        guard !targets.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var merged = holidaysByDate
            for year in targets.sorted() {
                let rows = try await fetch(year: year)
                for row in rows {
                    let date = row.date.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { continue }
                    let local = row.localName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let english = row.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    merged[date] = !local.isEmpty ? local : (!english.isEmpty ? english : "공휴일")
                }
                loadedYears.insert(year)
            }
            holidaysByDate = merged
        } catch {
            errorMessage = "공휴일 정보를 불러오지 못했습니다."
        }
    }

    private func fetch(year: Int) async throws -> [HomeHolidayRow] {
        guard let url = URL(string: "https://date.nager.at/api/v3/PublicHolidays/\(year)/KR") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Maroowell-iOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([HomeHolidayRow].self, from: data)
    }
}