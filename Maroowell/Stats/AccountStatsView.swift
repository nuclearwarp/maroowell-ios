import Foundation
import SwiftUI
import UIKit

struct AccountStatsView: View {
    @StateObject private var store = AccountStatsStore()
    @State private var filtersCollapsed = false
    @State private var collapsedSections: Set<String> = ["일별 수량 통계"]

    let session: AppSession

    var body: some View {
        Group {
            if session.canView("/maroowell_account") {
                content
            } else {
                permissionDenied
            }
        }
        .navigationTitle("통계조회")
        .navigationBarTitleDisplayMode(.inline)
        .alert("통계조회", isPresented: Binding(
            get: { store.alertMessage != nil },
            set: { if !$0 { store.alertMessage = nil } }
        )) {
            Button("확인", role: .cancel) { store.alertMessage = nil }
        } message: {
            Text(store.alertMessage ?? "")
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                filterCard
                statusRow

                if let snapshot = store.snapshot {
                    summaryCard(snapshot)
                    statsSection("노선별 수량 통계", values: snapshot.routes, includeOriginals: true)
                    statsSection("일별 수량 통계", values: snapshot.daily)
                    statsSection("요일별 수량 통계", values: snapshot.weekday)
                    statsSection("월별 수량 통계", values: snapshot.monthly)
                } else if !store.isLoading {
                    emptyCard("조회된 통계가 없습니다.")
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 13)
            .padding(.bottom, 30)
        }
        .background(MaroowellTheme.background)
    }

    private var filterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("조회 조건")
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                    Text("캠프·주/야 기준 배송·반품 통계")
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                Button(filtersCollapsed ? "펼치기" : "접기") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        filtersCollapsed.toggle()
                    }
                }
                .font(.caption.weight(.black))
                .buttonStyle(.bordered)
            }

            if !filtersCollapsed {
                HStack(spacing: 8) {
                    pickerField("연도") {
                        Picker("연도", selection: $store.year) {
                            ForEach(2024...2030, id: \.self) { value in
                                Text("\(value)년").tag(value)
                            }
                        }
                    }
                    pickerField("시작월") {
                        Picker("시작월", selection: $store.startMonth) {
                            ForEach(1...12, id: \.self) { value in
                                Text("\(value)월").tag(value)
                            }
                        }
                    }
                    pickerField("종료월") {
                        Picker("종료월", selection: $store.endMonth) {
                            ForEach(1...12, id: \.self) { value in
                                Text("\(value)월").tag(value)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("캠프 · 주/야")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(MaroowellTheme.muted)
                    Picker("캠프 · 주/야", selection: $store.targetIndex) {
                        ForEach(Array(AccountStatsTarget.options.enumerated()), id: \.offset) { index, target in
                            Text(target.label).tag(index)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 44)
                    .padding(.horizontal, 8)
                    .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("결과 필터")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(MaroowellTheme.muted)
                    TextField("ID / 캠프 / 노선 / 배송유형", text: $store.searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { store.rerenderOrLoad() }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                HStack(spacing: 9) {
                    Button {
                        Task {
                            await store.load()
                            if store.snapshot != nil { filtersCollapsed = true }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            if store.isLoading { ProgressView().controlSize(.small).tint(.white) }
                            Text(store.isLoading ? "조회 중..." : "조회")
                                .font(.subheadline.weight(.black))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.12, green: 0.43, blue: 0.38))
                    .disabled(store.isLoading)

                    Button {
                        store.clear()
                        filtersCollapsed = false
                        collapsedSections = ["일별 수량 통계"]
                    } label: {
                        Text("초기화")
                            .font(.subheadline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isLoading)
                }

                Text("선택한 캠프·주/야를 기준으로 조회합니다. 분실·파손, 미계약, 공란 노선은 통계에서 제외됩니다.")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(MaroowellTheme.muted)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }

    private func pickerField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MaroowellTheme.muted)
            content()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 42)
                .padding(.horizontal, 6)
                .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            if store.isLoading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: store.snapshot == nil ? "info.circle" : "checkmark.circle.fill")
                    .foregroundStyle(store.snapshot == nil ? MaroowellTheme.muted : Color.green)
            }
            Text(store.statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MaroowellTheme.muted)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func summaryCard(_ snapshot: AccountStatsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(snapshot.target.label) · \(snapshot.period)")
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color(red: 0.09, green: 0.25, blue: 0.23))
                    Text("집계 \(snapshot.rowCount.formatted())행 · 일자 \(snapshot.total.days)일")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.43, blue: 0.38))
            }

            HStack(spacing: 7) {
                summaryMetric("배송", value: snapshot.total.parcel)
                summaryMetric("반품", value: snapshot.total.returned)
                summaryMetric("총", value: snapshot.total.quantity)
            }

            Text("일평균 \(AccountStatsFormat.decimal(snapshot.total.average))")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.12, green: 0.43, blue: 0.38))
        }
        .padding(14)
        .background(Color(red: 0.94, green: 0.98, blue: 0.97), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color(red: 0.72, green: 0.84, blue: 0.82), lineWidth: 1)
        }
    }

    private func summaryMetric(_ title: String, value: Int64) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MaroowellTheme.muted)
            Text(value.formatted())
                .font(.title3.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func statsSection(_ title: String, values: [AccountStatsLine], includeOriginals: Bool = false) -> some View {
        let collapsed = collapsedSections.contains(title)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
                Spacer()
                Button {
                    copySectionImage(title: title, values: values, includeOriginals: includeOriginals)
                } label: {
                    Label("이미지 복사", systemImage: "doc.on.clipboard")
                        .font(.caption2.weight(.black))
                }
                .buttonStyle(.bordered)
                .disabled(values.isEmpty)

                Button(collapsed ? "펼치기" : "접기") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if collapsed { collapsedSections.remove(title) }
                        else { collapsedSections.insert(title) }
                    }
                }
                .font(.caption2.weight(.black))
                .buttonStyle(.bordered)
            }

            if !collapsed {
                if values.isEmpty {
                    emptyCard("조회 결과가 없습니다.")
                } else {
                    ForEach(Array(values.prefix(300))) { line in
                        metricCard(line, includeOriginals: includeOriginals)
                    }
                }
            }
        }
        .padding(.top, 3)
    }

    private func metricCard(_ line: AccountStatsLine, includeOriginals: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(line.label)
                .font(.subheadline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
            Text("배송 \(line.metric.parcel.formatted()) · 반품 \(line.metric.returned.formatted()) · 총 \(line.metric.quantity.formatted())")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.09, green: 0.42, blue: 0.36))
            Text("일자 \(line.metric.days)일 · 일평균 \(AccountStatsFormat.decimal(line.metric.average))")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)
            if includeOriginals && !line.metric.originals.isEmpty {
                Text("원본  \(line.metric.originals.sorted().joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(MaroowellTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MaroowellTheme.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MaroowellTheme.border, lineWidth: 1)
            }
    }

    private var permissionDenied: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(MaroowellTheme.muted)
            Text("통계조회 권한이 없습니다.")
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaroowellTheme.background)
    }

    @MainActor
    private func copySectionImage(title: String, values: [AccountStatsLine], includeOriginals: Bool) {
        guard let snapshot = store.snapshot, !values.isEmpty else { return }
        let report = AccountStatsSectionReport(
            title: title,
            snapshot: snapshot,
            values: Array(values.prefix(300)),
            includeOriginals: includeOriginals
        )
        .frame(width: 720)
        .fixedSize(horizontal: false, vertical: true)

        let renderer = ImageRenderer(content: report)
        renderer.scale = 1
        renderer.isOpaque = true
        guard let image = renderer.uiImage else {
            store.alertMessage = "통계 이미지를 만들지 못했습니다."
            return
        }
        UIPasteboard.general.image = image
        store.alertMessage = "\(title) 이미지를 클립보드에 복사했습니다."
    }
}

@MainActor
private final class AccountStatsStore: ObservableObject {
    @Published var year: Int
    @Published var startMonth: Int
    @Published var endMonth: Int
    @Published var targetIndex = 0
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var statusText = "기간과 캠프·주/야를 선택하고 조회를 누르세요."
    @Published var snapshot: AccountStatsSnapshot?
    @Published var alertMessage: String?

    private var rawRows: [AccountStatsRawRow]?
    private var loadedPeriod: (year: Int, startMonth: Int, endMonth: Int)?
    private let api = AccountStatsAPI()

    init() {
        let now = AccountStatsDate.currentYearMonth()
        year = min(2030, max(2024, now.year))
        startMonth = now.month
        endMonth = now.month
    }

    var target: AccountStatsTarget {
        AccountStatsTarget.options.indices.contains(targetIndex)
            ? AccountStatsTarget.options[targetIndex]
            : AccountStatsTarget.options[0]
    }

    func load() async {
        var start = startMonth
        var end = endMonth
        if start > end { swap(&start, &end) }
        startMonth = start
        endMonth = end
        let selectedTarget = target

        isLoading = true
        snapshot = nil
        statusText = "\(year)년 \(start)월~\(end)월 · \(selectedTarget.label) 조회 중…"
        defer { isLoading = false }

        do {
            let rows = try await api.query(year: year, startMonth: start, endMonth: end, target: selectedTarget)
            rawRows = rows
            loadedPeriod = (year, start, end)
            render(rows: rows, year: year, startMonth: start, endMonth: end)
        } catch {
            statusText = "조회 실패"
            alertMessage = AccountStatsAPI.friendly(error)
        }
    }

    func rerenderOrLoad() {
        if let rawRows, let period = loadedPeriod {
            render(rows: rawRows, year: period.year, startMonth: period.startMonth, endMonth: period.endMonth)
        } else {
            Task { await load() }
        }
    }

    func clear() {
        let now = AccountStatsDate.currentYearMonth()
        year = min(2030, max(2024, now.year))
        startMonth = now.month
        endMonth = now.month
        targetIndex = 0
        searchText = ""
        rawRows = nil
        loadedPeriod = nil
        snapshot = nil
        statusText = "기간과 캠프·주/야를 선택하고 조회를 누르세요."
    }

    private func render(rows source: [AccountStatsRawRow], year: Int, startMonth: Int, endMonth: Int) {
        let selectedTarget = target
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale(identifier: "ko_KR"))

        let rows: [AccountStatsRow] = source.compactMap { source in
            let classify = source.classify
            let sourceSheet = source.sourceSheet
            let route = source.route.trimmingCharacters(in: .whitespacesAndNewlines)
            let loss = sourceSheet.replacingOccurrences(of: " ", with: "").lowercased() == "분실파손list".lowercased()
                || classify.contains("분실")
                || classify.contains("파손")
            let uncontracted = classify.replacingOccurrences(of: " ", with: "").contains("미계약")
            if loss || uncontracted || route.isEmpty || ["-", "–", "—"].contains(route) { return nil }

            let row = AccountStatsRow(
                date: source.deliveryDate,
                camp: source.camp,
                wave: AccountStatsFormat.normalizeWave(source.wave),
                route: route,
                parcel: source.parcel,
                returned: source.returned,
                classify: classify,
                id: source.id
            )
            guard AccountStatsFormat.loose(row.camp) == AccountStatsFormat.loose(selectedTarget.camp),
                  row.wave == selectedTarget.wave else { return nil }

            if !query.isEmpty {
                let haystack = [row.id, row.camp, row.wave, row.route, row.classify]
                    .joined(separator: " ")
                    .lowercased(with: Locale(identifier: "ko_KR"))
                if !haystack.contains(query) && !AccountStatsFormat.loose(haystack).contains(AccountStatsFormat.loose(query)) {
                    return nil
                }
            }
            return row
        }

        var total = AccountStatsMetric()
        rows.forEach { total.add($0) }

        var routeMetric = AccountStatsMetric()
        rows.forEach { routeMetric.add($0) }
        let routeLines = rows.isEmpty ? [] : [
            AccountStatsLine(label: "\(selectedTarget.camp) · \(selectedTarget.wave) · 전체", metric: routeMetric)
        ]

        var dailyMap: [String: AccountStatsMetric] = [:]
        var weekdayMap: [Int: AccountStatsMetric] = [:]
        var monthlyMap: [String: AccountStatsMetric] = [:]

        for row in rows where !row.date.isEmpty {
            var daily = dailyMap[row.date] ?? AccountStatsMetric()
            daily.add(row)
            dailyMap[row.date] = daily

            let weekday = AccountStatsDate.weekdayIndex(row.date)
            if weekday >= 0 {
                var metric = weekdayMap[weekday] ?? AccountStatsMetric()
                metric.add(row)
                weekdayMap[weekday] = metric
            }

            let month = String(row.date.prefix(7))
            var monthly = monthlyMap[month] ?? AccountStatsMetric()
            monthly.add(row)
            monthlyMap[month] = monthly
        }

        let daily = dailyMap.keys.sorted().map { date in
            AccountStatsLine(
                label: "\(date) (\(AccountStatsDate.weekdayLabel(date))) · \(selectedTarget.camp) · 전체",
                metric: dailyMap[date] ?? AccountStatsMetric()
            )
        }
        let weekday = weekdayMap.keys.sorted().map { index in
            AccountStatsLine(
                label: "\(AccountStatsDate.weekdays[index])요일 · \(selectedTarget.camp) · 전체",
                metric: weekdayMap[index] ?? AccountStatsMetric()
            )
        }
        let monthly = monthlyMap.keys.sorted().map { month in
            AccountStatsLine(
                label: "\(month) · \(selectedTarget.camp) · \(selectedTarget.wave) · 전체",
                metric: monthlyMap[month] ?? AccountStatsMetric()
            )
        }

        snapshot = AccountStatsSnapshot(
            period: "\(year)년 \(startMonth)월~\(endMonth)월",
            target: selectedTarget,
            total: total,
            rowCount: rows.count,
            routes: routeLines,
            daily: daily,
            weekday: weekday,
            monthly: monthly
        )
        statusText = "조회 완료 · \(selectedTarget.label) · 통계 대상 \(rows.count.formatted())행"
    }
}

private struct AccountStatsTarget: Hashable {
    let camp: String
    let wave: String

    var label: String { "\(camp) - \(wave)" }

    static let options: [AccountStatsTarget] = [
        .init(camp: "M익산1", wave: "야간"),
        .init(camp: "대구3", wave: "주간"),
        .init(camp: "용인1", wave: "주간"),
        .init(camp: "용인3", wave: "주간"),
        .init(camp: "일산2", wave: "주간")
    ]
}

private struct AccountStatsRawRow {
    let deliveryDate: String
    let camp: String
    let wave: String
    let route: String
    let parcel: Int64
    let returned: Int64
    let classify: String
    let id: String
    let sourceSheet: String
}

private struct AccountStatsRow {
    let date: String
    let camp: String
    let wave: String
    let route: String
    let parcel: Int64
    let returned: Int64
    let classify: String
    let id: String
}

private struct AccountStatsMetric: Hashable {
    var rows = 0
    var parcel: Int64 = 0
    var returned: Int64 = 0
    var dates: Set<String> = []
    var originals: Set<String> = []

    var quantity: Int64 { parcel + returned }
    var days: Int { dates.count }
    var average: Double { days == 0 ? 0 : Double(quantity) / Double(days) }

    mutating func add(_ row: AccountStatsRow) {
        rows += 1
        parcel += row.parcel
        returned += row.returned
        if !row.date.isEmpty { dates.insert(row.date) }
        originals.insert("\(row.camp)/\(row.route)")
    }
}

private struct AccountStatsLine: Identifiable, Hashable {
    let label: String
    let metric: AccountStatsMetric
    var id: String { label }
}

private struct AccountStatsSnapshot {
    let period: String
    let target: AccountStatsTarget
    let total: AccountStatsMetric
    let rowCount: Int
    let routes: [AccountStatsLine]
    let daily: [AccountStatsLine]
    let weekday: [AccountStatsLine]
    let monthly: [AccountStatsLine]
}

private struct AccountStatsAPI {
    private static let endpoint = URL(string: "https://maroowellaccount.brain-0f6.workers.dev/account/query")!
    private let client = SupabaseService.shared.client

    func query(year: Int, startMonth: Int, endMonth: Int, target: AccountStatsTarget) async throws -> [AccountStatsRawRow] {
        let authSession = try await client.auth.session
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "period": [
                "year": year,
                "startMonth": startMonth,
                "endMonth": endMonth
            ],
            "refs": [[
                "camp": target.camp,
                "route": "",
                "current": true
            ]]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = (root?["error"] as? String) ?? (root?["message"] as? String)
            throw APIError.backend(status: http.statusCode, message: message)
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decode
        }
        let rows = root["rows"] as? [[String: Any]] ?? []
        return rows.map { row in
            AccountStatsRawRow(
                deliveryDate: text(row["delivery_date"]),
                camp: text(row["camp"]),
                wave: text(row["wave"]),
                route: text(row["route"]),
                parcel: integer(row["parcel"]),
                returned: integer(row["return"]),
                classify: text(row["classify"]),
                id: text(row["id"]),
                sourceSheet: text(row["source_sheet"])
            )
        }
    }

    private func text(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value)
    }

    private func integer(_ value: Any?) -> Int64 {
        guard let value, !(value is NSNull) else { return 0 }
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String {
            return Int64(Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
        }
        return 0
    }

    static func friendly(_ error: Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .backend(let status, let message):
                if status == 401 || status == 403 {
                    return "통계조회 접근 권한 또는 로그인 세션을 확인해주세요."
                }
                return message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? message!
                    : "통계조회 서버 오류 (HTTP \(status))"
            case .invalidResponse:
                return "통계조회 서버 응답을 확인하지 못했습니다."
            case .decode:
                return "통계조회 응답 형식이 올바르지 않습니다."
            }
        }
        return error.localizedDescription
    }

    private enum APIError: Error {
        case backend(status: Int, message: String?)
        case invalidResponse
        case decode
    }
}

private enum AccountStatsFormat {
    static func normalizeWave(_ value: String) -> String {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: " ", with: "")
        switch raw {
        case "WAVE2", "2W", "W2", "주간", "DAY": return "주간"
        case "WAVE1", "1W", "W1", "야간", "심야", "새벽", "NIGHT": return "야간"
        default:
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "-" : trimmed
        }
    }

    static func loose(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[\\s_-]", with: "", options: .regularExpression)
            .lowercased(with: Locale(identifier: "ko_KR"))
    }

    static func decimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

private enum AccountStatsDate {
    static let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    static func currentYearMonth() -> (year: Int, month: Int) {
        let parts = calendar.dateComponents([.year, .month], from: Date())
        return (parts.year ?? 2026, parts.month ?? 1)
    }

    static func weekdayIndex(_ iso: String) -> Int {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) else {
            return -1
        }
        return calendar.component(.weekday, from: date) - 1
    }

    static func weekdayLabel(_ iso: String) -> String {
        let index = weekdayIndex(iso)
        return weekdays.indices.contains(index) ? weekdays[index] : ""
    }
}

private struct AccountStatsSectionReport: View {
    let title: String
    let snapshot: AccountStatsSnapshot
    let values: [AccountStatsLine]
    let includeOriginals: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(.white)
                Text("\(snapshot.target.label) · \(snapshot.period)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.83))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(red: 0.13, green: 0.37, blue: 0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            ForEach(values) { line in
                VStack(alignment: .leading, spacing: 5) {
                    Text(line.label)
                        .font(.system(size: 15, weight: .black))
                    Text("배송 \(line.metric.parcel.formatted()) · 반품 \(line.metric.returned.formatted()) · 총 \(line.metric.quantity.formatted())")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.09, green: 0.42, blue: 0.36))
                    Text("일자 \(line.metric.days)일 · 일평균 \(AccountStatsFormat.decimal(line.metric.average))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)
                    if includeOriginals && !line.metric.originals.isEmpty {
                        Text("원본  \(line.metric.originals.sorted().joined(separator: ", "))")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .background(Color(red: 0.96, green: 0.97, blue: 0.98))
    }
}
