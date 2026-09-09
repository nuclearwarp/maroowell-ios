import Foundation

extension QuantityStore {
    func settlementRecordDates(anchor: Date) -> Set<String> {
        Set(settlementDailyPoints(anchor: anchor).map { ScheduleDatePolicy.iso($0.date) })
    }
}
