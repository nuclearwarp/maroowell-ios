import Charts
import SwiftUI

struct QuantityStatsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case monthly = "전체 월별"
        case settlement = "정산월 일별"
        var id: String { rawValue }
    }

    @ObservedObject private var store = QuantityStore.shared
    @State private var mode: Mode = .settlement
    @State private var anchorDate = Date()
    @State private var showRevenue = true
    @State private var showCount = true

    let session: AppSession

    private var settlement: QuantitySettlementSummary {
        store.settlementSummary(anchor: anchorDate)
    }

    private var settlementCounts: QuantitySettlementCounts {
        store.settlementCounts(anchor: anchorDate)
    }

    private var currentMonthSummary: QuantityMonthSummary {
        store.monthSummary(containing: anchorDate)
    }

    private var points: [QuantityTrendPoint] {
        switch mode {
        case .monthly:
            return store.monthlyTrendPoints(endingAt: anchorDate)
        case .settlement:
            return store.settlementDailyPoints(anchor: anchorDate)
        }
    }

    private var averageRevenue: Int64 {
        let days = mode == .settlement ? settlement.days : currentMonthSummary.days
        let total = mode == .settlement ? settlement.total : currentMonthSummary.total
        guard days > 0 else { return 0 }
        return total / Int64(days)
    }

    private var averageCount: Int64 {
        let days = mode == .settlement ? settlement.days : currentMonthSummary.days
        let count = mode == .settlement ? settlementCounts.mainCount : currentMonthSummary.count
        guard days > 0 else { return 0 }
        return count / Int64(days)
    }

    private var workDays: Int {
        mode == .settlement ? settlement.days : currentMonthSummary.days
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                greeting
                metrics
                trendCard
                displayOptions
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(MaroowellTheme.background)
        .navigationTitle("배송 통계")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var greeting: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("\(session.displayName)님,")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(MaroowellTheme.ink)
                Text("이번 달도 수고하셨어요!")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(MaroowellTheme.ink)
                Text("마루웰과 함께하는 더 나은 하루 💛")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MaroowellTheme.muted)
            }
            Spacer(minLength: 8)
            MaroowellMark(size: 68)
        }
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            metricCard(title: "평균 매출", value: averageRevenue.krw, symbol: "banknote.fill", tone: .red)
            metricCard(title: "평균 수량", value: "\(averageCount)건", symbol: "shippingbox.fill", tone: .blue)
            metricCard(title: "근무일", value: "\(workDays)일", symbol: "calendar", tone: .orange)
        }
    }

    private func metricCard(title: String, value: String, symbol: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tone)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MaroowellTheme.muted)
            }
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(MaroowellTheme.ink)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
            Text(title == "근무일" ? "수량을 등록한 날이에요." : title == "평균 매출" ? "일평균 매출이에요." : "일평균 수량이에요.")
                .font(.system(size: 10))
                .foregroundStyle(MaroowellTheme.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MaroowellTheme.border.opacity(0.9), lineWidth: 1)
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("기간별 추이")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(MaroowellTheme.ink)
            Text("선택한 기간의 매출과 수량 추이를 확인해보세요.")
                .font(.subheadline)
                .foregroundStyle(MaroowellTheme.muted)

            Picker("통계 단위", selection: $mode) {
                ForEach(Mode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                periodButton(systemName: "chevron.left") { movePeriod(-1) }
                Text(periodTitle)
                    .font(.headline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white, in: Capsule())
                    .overlay { Capsule().stroke(MaroowellTheme.border, lineWidth: 1) }
                periodButton(systemName: "chevron.right") { movePeriod(1) }
            }

            HStack(spacing: 10) {
                legendButton(title: "매출", tint: .red, isOn: $showRevenue)
                legendButton(title: "수량", tint: .blue, isOn: $showCount)
            }

            Group {
                if points.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 28))
                            .foregroundStyle(MaroowellTheme.muted.opacity(0.7))
                        Text("이 기간에는 등록 데이터가 없습니다")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MaroowellTheme.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    Chart(points) { point in
                        if showRevenue {
                            LineMark(
                                x: .value("기간", point.label),
                                y: .value("매출", point.amount)
                            )
                            .foregroundStyle(.red)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("기간", point.label),
                                y: .value("매출", point.amount)
                            )
                            .foregroundStyle(.red)
                        }

                        if showCount {
                            LineMark(
                                x: .value("기간", point.label),
                                y: .value("수량", normalizedCount(point.count))
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("기간", point.label),
                                y: .value("수량", normalizedCount(point.count))
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 280)
                }
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MaroowellTheme.border.opacity(0.9), lineWidth: 1)
        }
    }

    private var displayOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("표시 항목")
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
            Toggle("매출", isOn: $showRevenue)
            Toggle("수량", isOn: $showCount)
        }
        .tint(MaroowellTheme.yellow)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MaroowellTheme.border.opacity(0.9), lineWidth: 1)
        }
    }

    private var periodTitle: String {
        switch mode {
        case .monthly:
            let components = Calendar.current.dateComponents([.year, .month], from: anchorDate)
            return String(format: "%d년 %02d월", components.year ?? 0, components.month ?? 0)
        case .settlement:
            return "\(settlement.startDate.isoDots) - \(settlement.endDate.isoDots)"
        }
    }

    private func movePeriod(_ delta: Int) {
        anchorDate = store.movingMonth(anchorDate, by: delta)
    }

    private func periodButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
                .frame(width: 48, height: 48)
                .background(MaroowellTheme.yellow.opacity(0.23), in: Circle())
        }
    }

    private func legendButton(title: String, tint: Color, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 12, height: 12)
                Text(title)
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(tint.opacity(isOn.wrappedValue ? 0.08 : 0.025), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(tint.opacity(isOn.wrappedValue ? 0.9 : 0.25), lineWidth: 1)
            }
        }
    }

    private func normalizedCount(_ count: Int64) -> Int64 {
        let maxAmount = points.map(\.amount).max() ?? 0
        let maxCount = points.map(\.count).max() ?? 0
        guard maxAmount > 0, maxCount > 0 else { return count }
        return count * maxAmount / maxCount
    }
}

private extension Date {
    var isoDots: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: self)
    }
}
