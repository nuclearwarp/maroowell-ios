import Foundation

struct AccountState: Decodable {
    let approvalStatus: String
    let appOnly: Bool
    let maroowellInfoID: Int64?

    enum CodingKeys: String, CodingKey {
        case approvalStatus = "approval_status"
        case appOnly = "app_only"
        case maroowellInfoID = "maroowell_info_id"
    }
}

struct AccountAccess: Decodable {
    let isMaroowell: Bool
    let isAdmin: Bool
    let maxRoleLevel: Int
    let isDragonCarAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case isMaroowell = "is_maroowell"
        case isAdmin = "is_admin"
        case maxRoleLevel = "max_role_level"
        case isDragonCarAdmin = "is_dragon_car_admin"
    }
}

struct DisplayNameRow: Decodable {
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

struct AppSession: Equatable {
    let userID: UUID
    let email: String
    let displayName: String
    let isMaroowell: Bool
    let isAdmin: Bool
    let roleLevel: Int
    let isDragonCarAdmin: Bool
    let visiblePaths: Set<String>

    var isTeamLeader: Bool {
        isMaroowell && roleLevel >= 30
    }

    var isManager: Bool {
        isMaroowell && roleLevel >= 60
    }

    var isSuperAdmin: Bool {
        isMaroowell && isAdmin && roleLevel >= 90
    }

    func canView(_ path: String) -> Bool {
        visiblePaths.contains(AppAccessPolicy.basePath(path))
    }
}

enum MaroowellAuthError: LocalizedError {
    case accountPending
    case accountRejected
    case accountStateUnavailable
    case accessUnavailable

    var errorDescription: String? {
        switch self {
        case .accountPending:
            return "가입 승인 대기 중입니다. 관리자 승인 후 이용할 수 있습니다."
        case .accountRejected:
            return "가입 승인이 거절된 계정입니다. 관리자에게 문의해주세요."
        case .accountStateUnavailable:
            return "계정 승인 상태를 확인하지 못했습니다. 잠시 후 다시 시도해주세요."
        case .accessUnavailable:
            return "계정 권한을 확인하지 못했습니다. 잠시 후 다시 시도해주세요."
        }
    }
}
