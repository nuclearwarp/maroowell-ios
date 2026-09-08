import Foundation

struct InspectionGroup: Identifiable, Hashable {
    let title: String
    let items: [String]
    var id: String { title }
}

enum InspectionSchema {
    static let groups: [InspectionGroup] = [
        InspectionGroup(
            title: "외관점검",
            items: [
                "번호판, 전면유리, 후사경 등의 청결상태",
                "후미등, 차폭등 등 등화장치 작동상태",
                "창닦이기(와이퍼) 작동상태",
                "적재함(보조지지대 포함), 측면 보호대, 후부반사판, 트레일러 연결장치의 부착 상태 및 훼손 여부"
            ]
        ),
        InspectionGroup(
            title: "상태점검",
            items: [
                "타이어 손상 및 마모(1.6mm 이상) 여부",
                "화물, 적재함 지지대(판스프링) 등의 고정상태",
                "바퀴 너트 등 균열 여부"
            ]
        ),
        InspectionGroup(
            title: "기타",
            items: [
                "냉각수, 공기압, 엔진오일 등 차량 이상 여부(계기판 확인)",
                "좌석안전띠 상태",
                "소화기 비치 여부",
                "안전삼각대 등 비치 여부"
            ]
        )
    ]

    static let items: [String] = groups.flatMap(\.items)

    static func globalIndex(groupIndex: Int, itemIndex: Int) -> Int {
        groups.prefix(groupIndex).reduce(0) { $0 + $1.items.count } + itemIndex
    }
}

struct InspectionProfile: Codable, Equatable {
    var carrierName: String = ""
    var vehicleNumber: String = ""
    var driverName: String = ""

    var isComplete: Bool {
        !carrierName.trimmed.isEmpty && !vehicleNumber.trimmed.isEmpty && !driverName.trimmed.isEmpty
    }
}

struct InspectionDayRecord: Codable, Equatable {
    var statuses: [String]
    var actionNote: String
    var savedAt: Date
}

struct SignaturePoint: Codable, Hashable {
    var x: Double
    var y: Double
}

struct InspectionSignature: Codable, Equatable {
    var strokes: [[SignaturePoint]] = []

    var isEmpty: Bool {
        strokes.allSatisfy { $0.count < 2 }
    }

    mutating func clear() {
        strokes.removeAll()
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
