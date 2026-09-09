import Foundation
import Supabase

struct HomePersonalScheduleEntry: Identifiable, Hashable {
    let date: String
    let camp: String
    let wave: String
    let waveLabel: String
    let routes: [String]

    var id: String { "\(date)|\(camp)|\(wave)" }
    var isOff: Bool { !routes.isEmpty && routes.allSatisfy { $0 == "휴무" } }
}

struct HomeUnifiedScheduleRow: Decodable {
    let scheduleDate: String
    let source: String
    let camp: String
    let wave: String
    let routeLabel: String

    enum CodingKeys: String, CodingKey {
        case scheduleDate = "schedule_date"
        case source
        case camp
        case wave
        case routeLabel = "route_label"
    }
}

private struct HomeUnifiedScheduleParams: Encodable {
    let startDate: String
    let endDate: String

    enum CodingKeys: String, CodingKey {
        case startDate = "p_start_date"
        case endDate = "p_end_date"
    }
}

@MainActor
final class HomeScheduleStore: ObservableObject {
    @Published private(set) var entriesByDate: [String: [HomePersonalScheduleEntry]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let client = SupabaseService.shared.client
    private var loadedKey: String?

    func entries(for date: Date) -> [HomePersonalScheduleEntry] {
        entriesByDate[ScheduleDatePolicy.iso(date)] ?? []
    }

    func load(dates: [Date], force: Bool = false) async {
        guard let start = dates.min(), let end = dates.max() else { return }
        let startISO = ScheduleDatePolicy.iso(start)
        let endISO = ScheduleDatePolicy.iso(end)
        let key = "\(startISO)|\(endISO)"
        guard force || loadedKey != key else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let params = HomeUnifiedScheduleParams(startDate: startISO, endDate: endISO)
            let response = try await client
                .rpc("mw_my_unified_schedule", params: params)
                .execute()
            let rows = try JSONDecoder().decode([HomeUnifiedScheduleRow].self, from: response.data)
            entriesByDate = Self.group(rows)
            loadedKey = key
        } catch {
            entriesByDate = [:]
            loadedKey = nil
            errorMessage = Self.friendlyMessage(error)
        }
    }

    private static func group(_ rows: [HomeUnifiedScheduleRow]) -> [String: [HomePersonalScheduleEntry]] {
        struct GroupKey: Hashable {
            let date: String
            let camp: String
            let wave: String
        }

        var grouped: [GroupKey: Set<String>] = [:]

        for row in rows {
            let date = row.scheduleDate.trimmingCharacters(in: .whitespacesAndNewlines)
            let sourceCamp = row.camp.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !date.isEmpty, !sourceCamp.isEmpty else { continue }

            let source = row.source.trimmingCharacters(in: .whitespacesAndNewlines)
            let camp = source == "dragon_car" ? "용차 · \(sourceCamp)" : sourceCamp
            let wave = ScheduleNormalization.wave(row.wave)
            let rawRoute: String
            if source == "dragon_car" {
                rawRoute = row.routeLabel.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            } else {
                rawRoute = ScheduleNormalization.route(row.routeLabel)
            }
            guard !rawRoute.isEmpty else { continue }
            let route = rawRoute == ScheduleNormalization.offRouteLabel ? "휴무" : rawRoute
            grouped[GroupKey(date: date, camp: camp, wave: wave), default: []].insert(route)
        }

        var result: [String: [HomePersonalScheduleEntry]] = [:]
        for (key, routes) in grouped {
            let sortedRoutes = routes.sorted {
                if $0 == "휴무" { return true }
                if $1 == "휴무" { return false }
                return $0 < $1
            }
            result[key.date, default: []].append(
                HomePersonalScheduleEntry(
                    date: key.date,
                    camp: key.camp,
                    wave: key.wave,
                    waveLabel: key.wave == "WAVE1" ? "야간" : "주간",
                    routes: sortedRoutes
                )
            )
        }

        for date in result.keys {
            result[date]?.sort {
                if $0.wave != $1.wave { return $0.wave == "WAVE2" }
                return $0.camp < $1.camp
            }
        }
        return result
    }

    private static func friendlyMessage(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.contains("401") || raw.localizedCaseInsensitiveContains("jwt") {
            return "로그인 세션이 만료되어 내 스케줄을 불러오지 못했습니다."
        }
        if raw.contains("403") {
            return "내 기사정보 또는 스케줄 조회 권한이 없습니다."
        }
        return "내 입차 스케줄을 불러오지 못했습니다."
    }
}
