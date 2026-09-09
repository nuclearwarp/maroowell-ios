import Foundation
import Supabase

enum ScheduleAPIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case forbidden
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "입차 스케줄 서버 응답을 확인하지 못했습니다."
        case .unauthorized:
            return "로그인 세션이 만료되었습니다. 다시 로그인해주세요."
        case .forbidden:
            return "입차 스케줄을 조회하거나 수정할 권한이 없습니다."
        case .server(let message):
            return message.isEmpty ? "입차 스케줄 서버 오류가 발생했습니다." : message
        }
    }
}

struct ScheduleAPI {
    private let baseURL = URL(string: "https://schedule.maroowell.com")!
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func loadWeek(camp: String, wave: String, weekStart: Date) async throws -> ScheduleWeekData {
        var components = URLComponents(url: baseURL.appendingPathComponent("schedule/week"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "camp", value: camp),
            URLQueryItem(name: "wave", value: wave),
            URLQueryItem(name: "week_start", value: ScheduleDatePolicy.iso(weekStart))
        ]
        guard let url = components.url else { throw ScheduleAPIError.invalidResponse }
        let data = try await request(url: url, method: "GET", body: Optional<Data>.none)
        return try JSONDecoder().decode(ScheduleWeekData.self, from: data)
    }

    func save(rows: [ScheduleSaveRow]) async throws -> ScheduleSaveResult {
        let url = baseURL.appendingPathComponent("schedule/save")
        let body = try JSONEncoder().encode(ScheduleSaveEnvelope(rows: rows))
        let data = try await request(url: url, method: "POST", body: body)
        return try JSONDecoder().decode(ScheduleSaveResult.self, from: data)
    }

    private func request(url: URL, method: String, body: Data?) async throws -> Data {
        let authSession = try await SupabaseService.shared.client.auth.session
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ScheduleAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            switch http.statusCode {
            case 401: throw ScheduleAPIError.unauthorized
            case 403: throw ScheduleAPIError.forbidden
            default: throw ScheduleAPIError.server(responseDetail(data))
            }
        }
        return data
    }

    private func responseDetail(_ data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        for key in ["error", "message", "detail"] {
            if let value = object[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return ""
    }
}
