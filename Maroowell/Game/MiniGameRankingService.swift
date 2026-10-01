import Foundation
import Supabase

struct MiniGameConfig: Decodable, Identifiable {
    let gameKey: String
    let displayName: String
    let seasonKey: String
    let sortOrder: Int

    var id: String { gameKey }

    enum CodingKeys: String, CodingKey {
        case gameKey = "game_key"
        case displayName = "display_name"
        case seasonKey = "season_key"
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
    let currentUserID: UUID?
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
            .select("game_key,display_name,season_key,sort_order")
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
    ) async throws {
        let params = MiniGameScoreParams(
            pGameKey: gameKey,
            pScore: max(0, score),
            pCountAttempt: countAttempt
        )
        _ = try await client
            .rpc("app_submit_minigame_score", params: params)
            .execute()
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
        currentUserID: nil
    )
    @Published var isLoading = false
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
                    currentUserID: nil
                )
                return
            }

            activeGame = upup
            let localBest = UserDefaults.standard.integer(forKey: "upup_best_score")
            if localBest > 0 {
                try await MiniGameRankingService.submitScore(
                    gameKey: upup.gameKey,
                    score: localBest,
                    countAttempt: false
                )
            }

            leaderboard = try await MiniGameRankingService.loadLeaderboard(
                gameKey: upup.gameKey,
                seasonKey: upup.seasonKey
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
