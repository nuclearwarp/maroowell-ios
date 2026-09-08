import SwiftUI

@MainActor
final class QuantityViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var routes: [QuantityRouteRecord]
    @Published var memo: String
    @Published var saveMessage: String?

    private let store: QuantityStore

    init(store: QuantityStore = .shared, date: Date = .now) {
        self.store = store
        self.selectedDate = date
        let record = store.load(date)
        self.routes = record?.routes.isEmpty == false ? record!.routes : [Self.emptyRoute()]
        self.memo = record?.memo ?? ""
    }

    var selectedDateTitle: String {
        selectedDate.formatted(.dateTime.year().month().day().weekday(.abbreviated).locale(Locale(identifier: "ko_KR")))
    }

    var selectedTotal: Int64 {
        store.amount(of: QuantityRecord(memo: memo, savedAt: .now, routes: routes))
    }

    var settlementSummary: QuantitySettlementSummary {
        store.settlementSummary(anchor: selectedDate)
    }

    func moveDay(_ delta: Int) {
        selectedDate = store.movingDay(selectedDate, by: delta)
        reload()
    }

    func moveToToday() {
        selectedDate = .now
        reload()
    }

    func addRoute() {
        routes.append(Self.emptyRoute())
    }

    func deleteRoute(id: UUID) {
        guard routes.count > 1 else { return }
        routes.removeAll { $0.id == id }
    }

    func applyRecentPrices(to routeID: UUID) {
        guard let index = routes.firstIndex(where: { $0.id == routeID }) else { return }
        let route = routes[index]
        let prices = store.recentRoutePrices(
            anchor: selectedDate,
            campName: route.campName,
            routeName: route.routeName
        )
        guard prices.values.contains(where: { $0 > 0 }) else {
            saveMessage = "저장된 최근 단가가 없습니다."
            return
        }

        for key in QuantityLineKey.allCases {
            var value = routes[index].values[key.rawValue] ?? QuantityValue()
            value.unitPrice = prices[key] ?? 0
            routes[index].values[key.rawValue] = value
        }
        syncLinkedDeliveryPrices(routeIndex: index)
        saveMessage = "최근 단가를 불러왔습니다."
    }

    func updateCount(routeID: UUID, key: QuantityLineKey, value: String) {
        guard let index = routes.firstIndex(where: { $0.id == routeID }) else { return }
        var line = routes[index].values[key.rawValue] ?? QuantityValue()
        line.count = Int(value.replacingOccurrences(of: ",", with: "")) ?? 0
        routes[index].values[key.rawValue] = line
    }

    func updatePrice(routeID: UUID, key: QuantityLineKey, value: String) {
        guard let index = routes.firstIndex(where: { $0.id == routeID }) else { return }
        var line = routes[index].values[key.rawValue] ?? QuantityValue()
        line.unitPrice = Int(value.replacingOccurrences(of: ",", with: "")) ?? 0
        routes[index].values[key.rawValue] = line

        if key == .delivery {
            syncLinkedDeliveryPrices(routeIndex: index)
        }
    }

    func amount(routeID: UUID, key: QuantityLineKey) -> Int64 {
        guard let route = routes.first(where: { $0.id == routeID }) else { return 0 }
        let value = route.values[key.rawValue] ?? QuantityValue()
        let amount = Int64(value.count) * Int64(value.unitPrice)
        return key.isNegative ? -amount : amount
    }

    func save() {
        let normalized = routes.enumerated().map { index, route in
            var copy = route
            copy.campName = route.campName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRoute = route.routeName.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            copy.routeName = trimmedRoute.isEmpty && routes.count == 1 ? "기본" : trimmedRoute
            return copy
        }

        if let invalid = normalized.firstIndex(where: { $0.routeName.isEmpty }) {
            saveMessage = "\(invalid + 1)번째 라우트명을 입력해주세요."
            return
        }

        do {
            try store.save(
                QuantityRecord(
                    memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
                    savedAt: .now,
                    routes: normalized
                ),
                for: selectedDate
            )
            routes = normalized
            saveMessage = "저장 완료"
        } catch {
            saveMessage = "저장하지 못했습니다. 다시 시도해주세요."
        }
    }

    private func reload() {
        let record = store.load(selectedDate)
        routes = record?.routes.isEmpty == false ? record!.routes : [Self.emptyRoute()]
        memo = record?.memo ?? ""
        saveMessage = nil
    }

    private func syncLinkedDeliveryPrices(routeIndex: Int) {
        let deliveryPrice = routes[routeIndex].values[QuantityLineKey.delivery.rawValue]?.unitPrice ?? 0
        for key in [QuantityLineKey.deliveryStop, .returns] {
            var value = routes[routeIndex].values[key.rawValue] ?? QuantityValue()
            value.unitPrice = deliveryPrice
            routes[routeIndex].values[key.rawValue] = value
        }
    }

    private static func emptyRoute() -> QuantityRouteRecord {
        QuantityRouteRecord(
            routeName: "",
            campName: "",
            values: Dictionary(uniqueKeysWithValues: QuantityLineKey.allCases.map { ($0.rawValue, QuantityValue()) })
        )
    }
}
