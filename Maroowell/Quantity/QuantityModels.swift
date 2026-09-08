import Foundation

struct QuantityValue: Codable, Equatable {
    var count: Int = 0
    var unitPrice: Int = 0
}

enum QuantityLineKey: String, CaseIterable, Codable, Identifiable {
    case delivery
    case deliveryStop = "delivery_stop"
    case returns = "return"
    case freshbag
    case loss

    var id: String { rawValue }

    var label: String {
        switch self {
        case .delivery: return "배송완료"
        case .deliveryStop: return "배송중단"
        case .returns: return "회수완료"
        case .freshbag: return "프레시백"
        case .loss: return "사고·분실"
        }
    }

    var isNegative: Bool { self == .loss }
    var followsDeliveryPrice: Bool { self == .deliveryStop || self == .returns }
}

struct QuantityRouteRecord: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var routeName: String
    var campName: String
    var values: [String: QuantityValue]

    init(id: UUID = UUID(), routeName: String, campName: String = "", values: [String: QuantityValue]) {
        self.id = id
        self.routeName = routeName
        self.campName = campName
        self.values = values
    }
}

struct QuantityRecord: Codable, Equatable {
    var memo: String = ""
    var savedAt: Date = .now
    var routes: [QuantityRouteRecord] = []
}

struct QuantitySettlementSummary: Equatable {
    let settlementYear: Int
    let settlementMonth: Int
    let startDate: Date
    let endDate: Date
    let days: Int
    let total: Int64
}

struct QuantitySettlementCounts: Equatable {
    var delivery: Int64 = 0
    var returns: Int64 = 0
    var freshbag: Int64 = 0

    var mainCount: Int64 { delivery + returns }
}

struct QuantityTrendPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let label: String
    let amount: Int64
    let count: Int64
}

struct QuantityMonthSummary: Equatable {
    let days: Int
    let total: Int64
    let count: Int64
}
