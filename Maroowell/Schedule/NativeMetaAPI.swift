import Foundation
import Supabase

struct NativeMetaPreview: Decodable {
    let camp: String
    let wave: String
    let metaDate: String
    let scheduleDate: String
    let resetCount: Int
    let applyCount: Int
    let fingerprint: String
    enum CodingKeys: String, CodingKey {
        case camp, wave, fingerprint
        case metaDate = "meta_date"
        case scheduleDate = "schedule_date"
        case resetCount = "reset_count"
        case applyCount = "apply_count"
    }
}

private struct NativeMetaTransferRequest: Encodable {
    let camp: String
    let wave: String
    let date: String
    let phase: String
    let fingerprint: String
}
private struct NativeMetaVerifyRequest: Encodable {
    let camp: String
    let wave: String
    let date: String
    let phase: String
}
private struct NativeMetaReply: Decodable {
    let workflowID: String?
    let skipped: Bool?
    let status: String?
    let verified: Bool?
    let failureMessage: String?
    enum CodingKeys: String, CodingKey {
        case skipped, status, verified
        case workflowID = "workflow_id"
        case failureMessage = "failure_message"
    }
}
private struct NativeMetaContinue: Encodable {
    let workflowID: String
    enum CodingKeys: String, CodingKey { case workflowID = "workflow_id" }
}

struct NativeMetaAPI {
    static let shared = NativeMetaAPI()
    private let baseURL = URL(string: "https://schedule.maroowell.com")!

    private func request(path: String, query: [URLQueryItem] = [], body: Data? = nil) async throws -> Data {
        var parts = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        parts.queryItems = query.isEmpty ? nil : query
        guard let url = parts.url else { throw ScheduleAPIError.invalidResponse }
        let session = try await SupabaseService.shared.client.auth.session
        var request = URLRequest(url: url)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.timeoutInterval = 35
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw ScheduleAPIError.invalidResponse }
        guard (200...299).contains(response.statusCode) else {
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let name = (obj?["error"] as? String) ?? "HTTP \(response.statusCode)"
            let detail = obj?["detail"] as? [String: Any]
            throw ScheduleAPIError.server("\(name) \(detail?.description ?? "")")
        }
        return data
    }

    func preview(camp: String, wave: String, date: String) async throws -> NativeMetaPreview {
        let bytes = try await request(path: "schedule/meta/native/preview", query: [
            .init(name: "camp", value: camp), .init(name: "wave", value: wave), .init(name: "date", value: date)
        ])
        return try JSONDecoder().decode(NativeMetaPreview.self, from: bytes)
    }

    private func poll(_ id: String) async throws {
        var continued = false
        for _ in 0..<120 {
            let result = try JSONDecoder().decode(NativeMetaReply.self, from: request(path: "schedule/meta/workflow", query: [.init(name:"workflow_id",value:id)]))
            let status = (result.status ?? "").uppercased()
            if status == "SUCCESS" || status == "COMPLETED" { return }
            if status == "WAIT_FOR_DOWNLOAD" && !continued {
                _ = try await request(path: "schedule/meta/continue", body: JSONEncoder().encode(NativeMetaContinue(workflowID: id)))
                continued = true
            } else if !["RUNNING", "PENDING", "QUEUED", "WAIT_FOR_UPLOAD", "WAIT_FOR_VALIDATION", "PROCESSING", "DOWNLOAD_READY", "WAIT_FOR_DOWNLOAD"].contains(status) {
                throw ScheduleAPIError.server(result.failureMessage ?? "META 처리 실패: \(status)")
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        throw ScheduleAPIError.server("META 처리 제한 시간을 초과했습니다. 실제 등록 상태를 확인해주세요.")
    }

    @MainActor
    private func verify(_ preview: NativeMetaPreview, phase: String) async throws {
        for index in 0..<8 {
            if index > 0 { try await Task.sleep(nanoseconds: 1_200_000_000) }
            let value = try JSONEncoder().encode(NativeMetaVerifyRequest(camp:preview.camp,wave:preview.wave,date:preview.scheduleDate,phase:phase))
            let result = try JSONDecoder().decode(NativeMetaReply.self, from: request(path: "schedule/meta/native/verify", body:value))
            if result.verified == true { return }
        }
        throw ScheduleAPIError.server("META 실제 등록 검증 실패 · \(phase)")
    }

    @MainActor
    func transfer(_ preview: NativeMetaPreview, progress: (String) -> Void) async throws {
        for phase in ["reset", "apply"] {
            progress(phase == "reset" ? "기존 등록자 휴무 처리 중" : "새 출근 스케줄 등록 중")
            if phase == "reset" && preview.resetCount == 0 { continue }
            if phase == "apply" && preview.applyCount == 0 { continue }
            let body = try JSONEncoder().encode(NativeMetaTransferRequest(camp:preview.camp,wave:preview.wave,date:preview.scheduleDate,phase:phase,fingerprint:preview.fingerprint))
            let submitted = try JSONDecoder().decode(NativeMetaReply.self, from: request(path: "schedule/meta/native/submit",body:body))
            if let id = submitted.workflowID { try await poll(id) }
            progress("메타어드민 실제 반영 확인 중")
            try await verify(preview,phase:phase)
        }
    }
}
