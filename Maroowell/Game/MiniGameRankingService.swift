import Foundation
import Supabase

struct MiniGameConfig: Decodable, Identifiable {
    let gameKey: String
    let displayName: String
    let seasonKey: String
    let seasonNo: Int
    let sortOrder: Int

    var id: String { gameKey }

    enum CodingKeys: String, CodingKey {
        case gameKey = "game_key"
        case displayName = "display_name"
        case seasonKey = "season_key"
        case seasonNo = "season_no"
        case sortOrder = "sort_order"
    }
}

struct MiniGameRankRow: Decodable, Identifiable {
    let rank: Int
    let userID: UUID
    let organizationLabel: String
    let displayName: String
    let groupLabel: String
    let score: Int
    let attempts: Int

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case rank
        case userID = "user_id"
        case organizationLabel = "organization_label"
        case displayName = "display_name"
        case groupLabel = "group_label"
        case score, attempts
    }
}
struct MiniGameLeaderboardSnapshot {
    let rows: [MiniGameRankRow]
    let myRank: Int?
    let myScore: Int?
    let topScore: Int?
    let currentUserID: UUID?
}

private struct MiniGameScoreResult: Decodable {
    let score: Int
}

private struct MiniGameScoreParams: Encodable {
    let pGameKey: String
    let pScore: Int
    let pCountAttempt: Bool

    enum CodingKeys: String, CodingKey {
        case pGameKey = "p_game_key"
        case pScore = "p_score"
        case pCountAttempt = "p_count_attempt"
    }
}

enum MiniGameRankingService {
    private static let client = SupabaseService.shared.client

    static func loadActiveGames() async throws -> [MiniGameConfig] {
        try await client
            .from("app_minigame_games")
            .select("game_key,display_name,season_key,season_no,sort_order")
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .order("game_key", ascending: true)
            .execute()
            .value
    }
    static func submitScore(
        gameKey: String,
        score: Int,
        countAttempt: Bool
    ) async throws -> Int {
        let params = MiniGameScoreParams(
            pGameKey: gameKey,
            pScore: max(0, score),
            pCountAttempt: countAttempt
        )
        let session = try await client.auth.session
        try await verifyIntegritySession(accessToken: session.accessToken)

        let endpoint = AppConfig.supabaseURL
            .appendingPathComponent("rest/v1/rpc/app_submit_minigame_score")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        if let appCheckToken = await AppIntegrity.token() {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }
        request.httpBody = try JSONEncoder().encode(params)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "MiniGameScore",
                code: status,
                userInfo: [NSLocalizedDescriptionKey: "점수 등록 실패 (\(status)): \(body.prefix(160))"]
            )
        }
        let rows = try JSONDecoder().decode([MiniGameScoreResult].self, from: data)
        return rows.first?.score ?? max(0, score)
    }

    private static func verifyIntegritySession(accessToken: String) async throws {
        let first = try await integrityRequest(accessToken: accessToken, forceRefresh: false)
        if (200..<300).contains(first.status) { return }

        if first.status == 401 {
            let second = try await integrityRequest(accessToken: accessToken, forceRefresh: true)
            if (200..<300).contains(second.status) { return }
            throw NSError(
                domain: "AppIntegrity",
                code: second.status,
                userInfo: [NSLocalizedDescriptionKey: "앱 무결성 확인 실패 (\(second.status)): \(second.body.prefix(160))"]
            )
        }

        throw NSError(
            domain: "AppIntegrity",
            code: first.status,
            userInfo: [NSLocalizedDescriptionKey: "앱 무결성 확인 실패 (\(first.status)): \(first.body.prefix(160))"]
        )
    }

    private static func integrityRequest(
        accessToken: String,
        forceRefresh: Bool
    ) async throws -> (status: Int, body: String) {
        guard let appCheckToken = await AppIntegrity.token(forceRefresh: forceRefresh) else {
            throw NSError(
                domain: "AppIntegrity",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "앱 무결성 토큰을 발급받지 못했습니다."]
            )
        }

        let endpoint = AppConfig.supabaseURL
            .appendingPathComponent("functions/v1/app-integrity-verify")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        return (
            (response as? HTTPURLResponse)?.statusCode ?? -1,
            String(data: data, encoding: .utf8) ?? ""
        )
    }

    static func loadLeaderboard(
        gameKey: String,
        seasonKey: String
    ) async throws -> MiniGameLeaderboardSnapshot {
        let session = try await client.auth.session
        let rows: [MiniGameRankRow] = try await client
            .from("app_minigame_leaderboard")
            .select("rank,user_id,organization_label,display_name,group_label,score,attempts")
            .eq("game_key", value: gameKey)
            .eq("season_key", value: seasonKey)
            .order("rank", ascending: true)
            .limit(10)
            .execute()
            .value

        if let mine = rows.first(where: { $0.userID == session.user.id }) {
            return MiniGameLeaderboardSnapshot(
                rows: rows,
                myRank: mine.rank,
                myScore: mine.score,
                topScore: rows.first?.score,
                currentUserID: session.user.id
            )
        }
        let mineRows: [MiniGameRankRow] = try await client
            .from("app_minigame_leaderboard")
            .select("rank,user_id,organization_label,display_name,group_label,score,attempts")
            .eq("game_key", value: gameKey)
            .eq("season_key", value: seasonKey)
            .eq("user_id", value: session.user.id.uuidString)
            .limit(1)
            .execute()
            .value

        let mine = mineRows.first
        return MiniGameLeaderboardSnapshot(
            rows: rows,
            myRank: mine?.rank,
            myScore: mine?.score,
            topScore: rows.first?.score,
            currentUserID: session.user.id
        )
    }
}
@MainActor
final class MiniGameHubModel: ObservableObject {
    @Published var activeGame: MiniGameConfig?
    @Published var leaderboard = MiniGameLeaderboardSnapshot(
        rows: [],
        myRank: nil,
        myScore: nil,
        topScore: nil,
        currentUserID: nil
    )
    @Published var isLoading = false
    @Published var isRefreshingRanking = false
    @Published var errorMessage: String?

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let games = try await MiniGameRankingService.loadActiveGames()
            guard let upup = games.first(where: { $0.gameKey == "upup" }) else {
                activeGame = nil
                leaderboard = MiniGameLeaderboardSnapshot(
                    rows: [],
                    myRank: nil,
                    myScore: nil,
                    topScore: nil,
                    currentUserID: nil
                )
                return
            }

            activeGame = upup
            leaderboard = try await MiniGameRankingService.loadLeaderboard(
                gameKey: upup.gameKey,
                seasonKey: upup.seasonKey
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshLeaderboard() async {
        guard let game = activeGame, !isRefreshingRanking else { return }
        isRefreshingRanking = true
        errorMessage = nil
        defer { isRefreshingRanking = false }

        do {
            leaderboard = try await MiniGameRankingService.loadLeaderboard(
                gameKey: game.gameKey,
                seasonKey: game.seasonKey
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
