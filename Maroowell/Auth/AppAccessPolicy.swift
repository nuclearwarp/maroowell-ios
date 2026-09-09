import Foundation

enum AppAccessPolicy {
    static let schedulePath = "/maroowell_schedule"
    static let metaRealtimePath = "local://meta-realtime"
    static let pushPath = "/maroowell_push"
    static let accountStatsPath = "/maroowell_account"
    static let campMapPath = "/coupang_camp_map"

    static func visiblePaths(
        isMaroowell: Bool,
        isAdmin: Bool,
        roleLevel: Int,
        isDragonCarAdmin: Bool,
        canCleansingHistory: Bool
    ) -> Set<String> {
        var paths: Set<String> = []

        if isMaroowell {
            paths.insert("/maroowell_route_info")
            paths.insert("/maroowell_freshbag_ratio")
        }

        if isMaroowell && roleLevel >= 30 {
            paths.formUnion([
                "/zipcode_search",
                "/coupangRouteMap.html",
                "/coupang_camp",
                campMapPath,
                "/coupang_freshbag",
                schedulePath,
                accountStatsPath,
                "/dragon_car_schedule",
                pushPath,
                metaRealtimePath
            ])
        }

        if isMaroowell && roleLevel >= 60 {
            paths.insert("/maroowell_info")
            paths.insert("/maroowell_route")
        }

        let isSuperAdmin = isMaroowell && isAdmin && roleLevel >= 90
        if isSuperAdmin {
            paths.insert("/maroowell_payout")
            paths.insert("/admin_access.html")
        }

        if isSuperAdmin || canCleansingHistory {
            paths.insert("/cleansing_history")
        }

        if isDragonCarAdmin {
            paths.insert("/dragon_car_index")
            paths.insert("/dragon_car_schedule")
        }

        return paths
    }

    static func basePath(_ raw: String) -> String {
        let path = raw.split(separator: "?", maxSplits: 1).first.map(String.init) ?? raw
        return path.isEmpty ? "/" : path
    }

    static func permissionBadge(for path: String, session: AppSession) -> String? {
        switch basePath(path) {
        case schedulePath, accountStatsPath, pushPath, metaRealtimePath, campMapPath:
            return "팀장"
        case "/maroowell_info", "/maroowell_route":
            return "관리자"
        case "/cleansing_history":
            return "클히"
        case "/maroowell_route_info", "/maroowell_freshbag_ratio":
            return "마루웰"
        case "/dragon_car_index":
            return "용차관리자"
        case "/dragon_car_schedule":
            return session.isDragonCarAdmin ? "용차" : "팀장/용차"
        case "/admin_access.html":
            return "최고관리자"
        default:
            return nil
        }
    }
}
