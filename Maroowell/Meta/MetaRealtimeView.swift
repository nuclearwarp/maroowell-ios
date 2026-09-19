import SwiftUI

struct MetaRealtimeView: View {
    @ObservedObject var store: MetaRealtimeStore

    init(store: MetaRealtimeStore) {
        self.store = store
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                filters
                MetaRealtimeSummaryCard(summary: store.summary, lastPolledAt: store.lastPolledAt)

                if store.loading && store.rows.isEmpty {
                    ProgressView("실시간 배송 현황을 불러오는 중...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if store.filteredRows.isEmpty {
                    ContentUnavailableView(
                        "조회된 배송 현황이 없습니다.",
                        systemImage: "shippingbox",
                        description: Text("현재 배송을 시작한 기사 기준으로 표시됩니다.")
                    )
                    .padding(.vertical, 30)
                } else {
                    ForEach(store.campSummaries) { camp in
                        MetaCampSummaryCard(camp: camp)
                    }
                    ForEach(store.filteredRows) { row in
                        MetaDriverCard(row: row)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(MaroowellTheme.background)
        .navigationTitle("실시간 배송 현황")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.rows.isEmpty { await store.load() }
        }
        .refreshable {
            await store.load()
        }
        .alert("실시간 배송 현황", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
    }

    private var filters: some View {
        VStack(spacing: 10) {
            HStack {
                Menu {
                    Button("전체 캠프") { store.selectedCamp = "ALL" }
                    ForEach(store.camps, id: \.self) { camp in
                        Button(camp) { store.selectedCamp = camp }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "building.2.fill")
                        Text(store.selectedCamp == "ALL" ? "전체 캠프" : store.selectedCamp)
                            .fontWeight(.bold)
                        Image(systemName: "chevron.down")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await store.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(store.loading)
            }

            HStack(spacing: 8) {
                waveButton("전체", wave: "ALL")
                waveButton("주간", wave: "WAVE2")
                waveButton("야간", wave: "WAVE1")
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(MaroowellTheme.border) }
    }

    private func waveButton(_ title: String, wave: String) -> some View {
        Button {
            store.selectedWave = wave
        } label: {
            Text(title)
                .font(.subheadline.weight(.black))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
        }
        .buttonStyle(.borderedProminent)
        .tint(store.selectedWave == wave ? MaroowellTheme.deepYellow : Color.gray.opacity(0.18))
        .foregroundStyle(store.selectedWave == wave ? Color.white : MaroowellTheme.ink)
    }
}

struct MetaRealtimeSummaryCard: View {
    let summary: MetaRealtimeSummary
    let lastPolledAt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("전체 실시간 현황")
                        .font(.headline.weight(.black))
                    Text("캠프 \(summary.campCount) · 배송중 \(summary.workers)명 · 주간 \(summary.dayCount) · 야간 \(summary.nightCount)")
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                if !lastPolledAt.isEmpty {
                    Text(lastPolledAt.shortMetaTime)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(MaroowellTheme.muted)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                MetaMetricPanel(title: "배송", primary: "\(summary.delivery.completed)/\(summary.delivery.total)", secondary: "진행 \(summary.delivery.rate.percent1)")
                MetaMetricPanel(title: "회수", primary: "\(summary.returns.collected)/\(summary.returns.total)", secondary: "회수 \(summary.returns.collectionRate.percent1)")
                MetaMetricPanel(title: "프백", primary: "\(summary.freshbag.collected)/\(summary.freshbag.total)", secondary: "회수 \(summary.freshbag.collectionRate.percent1)")
                MetaMetricPanel(title: "프레시 배송", primary: summary.freshDelivery.hasData ? "\(summary.freshDelivery.completed)/\(summary.freshDelivery.total)" : "-", secondary: summary.freshDelivery.hasData ? summary.freshDelivery.rate.percent1 : "데이터 없음")
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(MaroowellTheme.border) }
    }
}

private struct MetaMetricPanel: View {
    let title: String
    let primary: String
    let secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(MaroowellTheme.muted)
            Text(primary).font(.headline.weight(.black)).foregroundStyle(MaroowellTheme.ink)
            Text(secondary).font(.caption2.weight(.bold)).foregroundStyle(MaroowellTheme.deepYellow)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MetaCampSummaryCard: View {
    let camp: MetaCampSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(camp.camp).font(.headline.weight(.black))
                Text(camp.wave == "WAVE1" ? "야간" : "주간")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(camp.wave == "WAVE1" ? Color.indigo : MaroowellTheme.deepYellow)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background((camp.wave == "WAVE1" ? Color.indigo : MaroowellTheme.deepYellow).opacity(0.10), in: Capsule())
                Spacer()
                Text("\(camp.workers)명")
                    .font(.caption.weight(.black))
                    .foregroundStyle(MaroowellTheme.muted)
            }
            Text("배송 \(camp.delivery.completed)/\(camp.delivery.total) · \(camp.delivery.rate.percent1) · 회수 \(camp.returns.collected)/\(camp.returns.total) · 프백 \(camp.freshbag.collected)/\(camp.freshbag.total)")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)
            if camp.scheduledCount > 0 {
                Text("스케줄 \(camp.scheduledCount)명" + (camp.absentNames.isEmpty ? "" : " · 미출근 \(camp.absentNames.joined(separator: ", "))"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(camp.absentNames.isEmpty ? MaroowellTheme.muted : .orange)
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(MaroowellTheme.border) }
    }
}

struct MetaDriverCard: View {
    let row: MetaDriverRow

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.driver)
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                    Text([row.camp, row.wave == "WAVE1" ? "야간" : "주간", row.routes.joined(separator: ", ")].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                Text(row.delivery.rate.percent1)
                    .font(.headline.weight(.black))
                    .foregroundStyle(row.status == .external ? Color.red : row.status == .mismatch ? Color.orange : MaroowellTheme.deepYellow)
            }

            if !row.warns.isEmpty {
                ForEach(row.warns, id: \.self) { warning in
                    Text(warning)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(row.status == .external ? Color.red : Color.orange)
                }
            }

            HStack(spacing: 6) {
                MetaTinyMetric(label: "총", value: row.delivery.total)
                MetaTinyMetric(label: "미스캔", value: row.delivery.misscan)
                MetaTinyMetric(label: "배송중", value: row.delivery.remaining)
                MetaTinyMetric(label: "완료", value: row.delivery.completed)
            }

            HStack(spacing: 8) {
                Text("회수 \(row.returns.collected)/\(row.returns.total)")
                Text("프백 \(row.freshbag.collected)/\(row.freshbag.total)")
                if row.freshDelivery.hasData {
                    Text("프레시배송 \(row.freshDelivery.completed)/\(row.freshDelivery.total)")
                }
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(MaroowellTheme.muted)
        }
        .padding(13)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 17))
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .stroke(row.status == .external ? Color.red.opacity(0.55) : row.status == .mismatch ? Color.orange.opacity(0.55) : MaroowellTheme.border, lineWidth: row.status == .ok ? 1 : 1.5)
        }
    }
}

private struct MetaTinyMetric: View {
    let label: String
    let value: Int
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(MaroowellTheme.muted)
            Text("\(value)").font(.caption.weight(.black)).foregroundStyle(MaroowellTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 9))
    }
}

enum MetaDriverStatus: String, Hashable {
    case ok, mismatch, external
}

struct MetaDelivery: Hashable {
    var total = 0
    var misscan = 0
    var remaining = 0
    var completed = 0
    var impossible = 0
    var pddMiss = 0
    var hasData = false

    var rate: Double {
        guard total > 0 else { return 0 }
        return Double(completed + impossible + misscan + pddMiss) * 100 / Double(total)
    }

    mutating func add(_ other: MetaDelivery) {
        total += other.total
        misscan += other.misscan
        remaining += other.remaining
        completed += other.completed
        impossible += other.impossible
        pddMiss += other.pddMiss
        hasData = hasData || other.hasData
    }
}

struct MetaCollection: Hashable {
    var total = 0
    var assigned = 0
    var collected = 0
    var uncollected = 0
    var absent = 0

    var completionRate: Double {
        total > 0 ? Double(collected + uncollected) * 100 / Double(total) : 0
    }
    var collectionRate: Double {
        total > 0 ? Double(collected) * 100 / Double(total) : 0
    }

    mutating func add(_ other: MetaCollection) {
        total += other.total
        assigned += other.assigned
        collected += other.collected
        uncollected += other.uncollected
        absent += other.absent
    }
}

struct MetaDriverRow: Identifiable, Hashable {
    let id: String
    let batchID: String
    let scheduleDate: String
    let camp: String
    let wave: String
    let driver: String
    let coupangID: String
    let routes: [String]
    let delivery: MetaDelivery
    let freshDelivery: MetaDelivery
    let returns: MetaCollection
    let freshbag: MetaCollection
    let status: MetaDriverStatus
    let warns: [String]
}

struct MetaCampSummary: Identifiable, Hashable {
    var id: String { "\(camp)|\(wave)" }
    let camp: String
    let wave: String
    var workers = 0
    var scheduledCount = 0
    var absentNames: [String] = []
    var delivery = MetaDelivery()
    var freshDelivery = MetaDelivery()
    var returns = MetaCollection()
    var freshbag = MetaCollection()
}

struct MetaRealtimeSummary: Hashable {
    var campCount = 0
    var workers = 0
    var dayCount = 0
    var nightCount = 0
    var delivery = MetaDelivery()
    var freshDelivery = MetaDelivery()
    var returns = MetaCollection()
    var freshbag = MetaCollection()
}

@MainActor
final class MetaRealtimeStore: ObservableObject {
    @Published var rows: [MetaDriverRow] = []
    @Published var campSource: [MetaCampSummary] = []
    @Published var selectedCamp = "ALL"
    @Published var selectedWave = "ALL"
    @Published var loading = false
    @Published var message: String?
    @Published var lastPolledAt = ""

    var camps: [String] {
        Array(Set(rows.map(\.camp).filter { !$0.isEmpty })).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var filteredRows: [MetaDriverRow] {
        rows.filter {
            (selectedCamp == "ALL" || $0.camp == selectedCamp) &&
            (selectedWave == "ALL" || $0.wave == selectedWave)
        }
    }

    var campSummaries: [MetaCampSummary] {
        campSource.filter {
            (selectedCamp == "ALL" || $0.camp == selectedCamp) &&
            (selectedWave == "ALL" || $0.wave == selectedWave)
        }
    }

    var summary: MetaRealtimeSummary {
        var result = MetaRealtimeSummary()
        let visible = filteredRows
        result.workers = visible.count
        result.campCount = Set(visible.map(\.camp)).count
        result.dayCount = visible.filter { $0.wave == "WAVE2" }.count
        result.nightCount = visible.filter { $0.wave == "WAVE1" }.count
        for camp in campSummaries {
            result.delivery.add(camp.delivery)
            result.freshDelivery.add(camp.freshDelivery)
            result.returns.add(camp.returns)
            result.freshbag.add(camp.freshbag)
        }
        return result
    }

    func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }

        do {
            let auth = try await SupabaseService.shared.client.auth.session
            let batches = try await get(
                "meta_realtime_batch",
                query: [
                    .init(name: "select", value: "id,schedule_date,meta_work_date,camp_code,camp_name,wave,status,worker_count,last_polled_at,next_poll_at,last_error,updated_at"),
                    .init(name: "status", value: "in.(collecting,completion_candidate,overdue,error,paused)"),
                    .init(name: "order", value: "updated_at.desc")
                ],
                token: auth.accessToken
            ).filter { Self.isCurrentShift($0) }

            guard !batches.isEmpty else {
                rows = []
                campSource = []
                lastPolledAt = ""
                return
            }

            let batchIDs = batches.compactMap { Self.text($0["id"]).nilIfEmpty }
            let dates = Array(Set(batches.compactMap { Self.text($0["schedule_date"]).nilIfEmpty }))
            let idFilter = "in.(\(batchIDs.joined(separator: ",")))"

            async let currentTask = get(
                "meta_realtime_current",
                query: [
                    .init(name: "select", value: "batch_id,meta_worker_key,driver_pk,camp_code,camp_name,wave,coupang_id,driver_name,scheduled_routes,actual_routes,extra_routes,delivery_assigned,delivery_scanned,delivery_completed,delivery_impossible,delivery_pdd_miss,delivery_total,delivery_complete_rate,return_pending,return_collected,return_uncollected,return_uncollected_raw,return_absent_raw,return_total,return_attempt_rate,return_collection_rate,freshbag_pending,freshbag_collected,freshbag_uncollected,freshbag_total,freshbag_attempt_rate,freshbag_collection_rate,scan_started_at,all_completed_at,last_seen_at,all_done,dawn_miss,fresh_miss,raw_payload"),
                    .init(name: "batch_id", value: idFilter)
                ],
                token: auth.accessToken
            )
            async let freshTask = get(
                "meta_realtime_fresh_current",
                query: [
                    .init(name: "select", value: "batch_id,meta_worker_key,driver_pk,coupang_id,driver_name,delivery_assigned,delivery_scanned,delivery_completed,delivery_impossible,delivery_pdd_miss,delivery_total,delivery_complete_rate,fresh_miss"),
                    .init(name: "batch_id", value: idFilter)
                ],
                token: auth.accessToken
            )
            async let scheduleTask = dates.isEmpty ? [] : get(
                "maroowell_schedule",
                query: [
                    .init(name: "select", value: "schedule_date,camp,wave,route_label,driver_name,driver_display_name,driver_owner_name,driver_coupang_id,is_active"),
                    .init(name: "schedule_date", value: "in.(\(dates.joined(separator: ",")))"),
                    .init(name: "is_active", value: "eq.true")
                ],
                token: auth.accessToken
            )

            let (current, fresh, schedules) = try await (currentTask, freshTask, scheduleTask)
            let merged = Self.mergeFresh(current: current, fresh: fresh)
            let built = Self.build(batches: batches, current: merged, schedules: schedules)
            rows = built.rows
            campSource = built.camps
            lastPolledAt = built.lastPolledAt

            if selectedCamp != "ALL", !camps.contains(selectedCamp) {
                selectedCamp = "ALL"
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func get(_ table: String, query: [URLQueryItem], token: String) async throws -> [[String: Any]] {
        var components = URLComponents(
            url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = query
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "MetaRealtime", code: code, userInfo: [NSLocalizedDescriptionKey: "실시간 DB 조회 실패 (\(code)): \(body.prefix(140))"])
        }
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }

    private static func build(
        batches: [[String: Any]],
        current: [[String: Any]],
        schedules: [[String: Any]]
    ) -> (rows: [MetaDriverRow], camps: [MetaCampSummary], lastPolledAt: String) {
        let batchByID = Dictionary(uniqueKeysWithValues: batches.compactMap { row -> (String, [String: Any])? in
            let id = text(row["id"])
            return id.isEmpty ? nil : (id, row)
        })

        var scheduledByKey: [String: [String: String]] = [:]
        for row in schedules {
            guard bool(row["is_active"]) else { continue }
            let route = normalizeRoute(text(row["route_label"]))
            if route == "휴무" { continue }
            let camp = cleanCamp(text(row["camp"]))
            let wave = text(row["wave"]).uppercased()
            let date = text(row["schedule_date"])
            let display = ["driver_display_name", "driver_name", "driver_owner_name", "driver_coupang_id"]
                .map { text(row[$0]) }.first(where: { !$0.isEmpty }) ?? ""
            let cid = text(row["driver_coupang_id"]).lowercased()
            guard !camp.isEmpty, !wave.isEmpty, !date.isEmpty, !display.isEmpty else { continue }
            let identity = cid.isEmpty ? "name:\(nameKey(display))" : "id:\(cid)"
            scheduledByKey["\(date)|\(camp)|\(wave)", default: [:]][identity] = display
        }

        var rows: [MetaDriverRow] = []
        var camps: [String: MetaCampSummary] = [:]

        for source in current where isStarted(source) {
            let batchID = text(source["batch_id"])
            let batch = batchByID[batchID] ?? [:]
            let wave = (text(source["wave"]).isEmpty ? text(batch["wave"]) : text(source["wave"])).uppercased()
            let camp = cleanCamp(
                text(source["camp_name"]).isEmpty ? text(batch["camp_name"]) : text(source["camp_name"]),
                fallback: text(source["camp_code"]).isEmpty ? text(batch["camp_code"]) : text(source["camp_code"])
            )
            let scheduleDate = text(batch["schedule_date"])
            let delivery = delivery(source, prefix: "delivery")
            let freshDelivery = delivery(source, prefix: "fresh_delivery")
            let returns = collection(source, prefix: "return", includeAbsent: true)
            let freshbag = collection(source, prefix: "freshbag", includeAbsent: false)

            let routeSource = array(source["scheduled_routes"]).isEmpty ? array(source["actual_routes"]) : array(source["scheduled_routes"])
            let routes = Array(Set(routeSource.map { normalizeRoute(text($0)) }.filter { !$0.isEmpty })).sorted()

            var status: MetaDriverStatus = .ok
            var warns: [String] = []
            let alerts = (dict(source["raw_payload"])["route_alerts"] as? [[String: Any]]) ?? []
            var borrowed: [String] = []
            var external: [String] = []
            for alert in alerts {
                let route = normalizeRoute(text(alert["route"]))
                switch text(alert["type"]).lowercased() {
                case "borrowed": if !route.isEmpty && !borrowed.contains(route) { borrowed.append(route) }
                case "uncontracted": if !route.isEmpty && !external.contains(route) { external.append(route) }
                default: break
                }
            }
            if !borrowed.isEmpty {
                warns.append("다른 담당 라우트: \(borrowed.joined(separator: ", "))")
                status = .mismatch
            }
            if !external.isEmpty {
                warns.append("마루웰 관리 라우트 아님: \(external.joined(separator: ", "))")
                status = .external
            }

            let driver = text(source["driver_name"]).nilIfEmpty ?? text(source["coupang_id"]).nilIfEmpty ?? "담당 확인"
            let coupangID = text(source["coupang_id"]).lowercased()
            let identity = [
                batchID,
                text(source["meta_worker_key"]),
                text(source["driver_pk"]),
                coupangID,
                nameKey(driver)
            ].joined(separator: "|")

            let row = MetaDriverRow(
                id: identity,
                batchID: batchID,
                scheduleDate: scheduleDate,
                camp: camp,
                wave: wave,
                driver: driver,
                coupangID: coupangID,
                routes: routes,
                delivery: delivery,
                freshDelivery: freshDelivery,
                returns: returns,
                freshbag: freshbag,
                status: status,
                warns: warns
            )
            rows.append(row)

            let key = "\(camp)|\(wave)"
            var summary = camps[key] ?? MetaCampSummary(camp: camp, wave: wave)
            summary.workers += 1
            summary.delivery.add(delivery)
            summary.freshDelivery.add(freshDelivery)
            summary.returns.add(returns)
            summary.freshbag.add(freshbag)
            camps[key] = summary
        }

        for key in Array(camps.keys) {
            guard var summary = camps[key] else { continue }
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            let camp = parts.first ?? ""
            let wave = parts.count > 1 ? parts[1] : ""
            let date = rows.first(where: { $0.camp == camp && $0.wave == wave })?.scheduleDate ?? ""
            let scheduled = scheduledByKey["\(date)|\(camp)|\(wave)"] ?? [:]
            summary.scheduledCount = scheduled.count

            let presentIDs = Set(rows.filter { $0.camp == camp && $0.wave == wave }.map(\.coupangID).filter { !$0.isEmpty })
            let presentNames = Set(rows.filter { $0.camp == camp && $0.wave == wave }.map { nameKey($0.driver) }.filter { !$0.isEmpty })
            summary.absentNames = scheduled.compactMap { identity, display in
                if identity.hasPrefix("id:") {
                    return presentIDs.contains(String(identity.dropFirst(3))) ? nil : display
                }
                return presentNames.contains(nameKey(display)) ? nil : display
            }.sorted()
            camps[key] = summary
        }

        rows.sort {
            if $0.delivery.rate != $1.delivery.rate { return $0.delivery.rate < $1.delivery.rate }
            if $0.delivery.misscan != $1.delivery.misscan { return $0.delivery.misscan > $1.delivery.misscan }
            if $0.camp != $1.camp { return $0.camp.localizedStandardCompare($1.camp) == .orderedAscending }
            return $0.driver.localizedStandardCompare($1.driver) == .orderedAscending
        }

        let last = batches.map { text($0["last_polled_at"]) }.filter { !$0.isEmpty }.max() ?? ""
        return (
            rows,
            camps.values.sorted {
                if $0.delivery.rate != $1.delivery.rate { return $0.delivery.rate < $1.delivery.rate }
                if $0.camp != $1.camp { return $0.camp.localizedStandardCompare($1.camp) == .orderedAscending }
                return $0.wave < $1.wave
            },
            last
        )
    }

    private static func mergeFresh(current: [[String: Any]], fresh: [[String: Any]]) -> [[String: Any]] {
        var byDriverPK: [String: [String: Any]] = [:]
        var byWorkerKey: [String: [String: Any]] = [:]
        var byCoupang: [String: [String: Any]] = [:]
        var byName: [String: [String: Any]] = [:]

        for row in fresh {
            let batch = text(row["batch_id"])
            let driverPK = text(row["driver_pk"])
            if !driverPK.isEmpty { byDriverPK["\(batch)|\(driverPK)"] = row }
            let worker = text(row["meta_worker_key"]).lowercased()
            if !worker.isEmpty { byWorkerKey["\(batch)|\(worker)"] = row }
            let coupang = text(row["coupang_id"]).lowercased()
            if !coupang.isEmpty { byCoupang["\(batch)|\(coupang)"] = row }
            let name = nameKey(text(row["driver_name"]))
            if !name.isEmpty { byName["\(batch)|\(name)"] = row }
        }

        return current.map { source in
            var row = source
            let batch = text(row["batch_id"])
            let driverPK = text(row["driver_pk"])
            let worker = text(row["meta_worker_key"]).lowercased()
            let coupang = text(row["coupang_id"]).lowercased()
            let name = nameKey(text(row["driver_name"]))
            let match =
                (!driverPK.isEmpty ? byDriverPK["\(batch)|\(driverPK)"] : nil) ??
                (!worker.isEmpty ? byWorkerKey["\(batch)|\(worker)"] : nil) ??
                (!coupang.isEmpty ? byCoupang["\(batch)|\(coupang)"] : nil) ??
                (!name.isEmpty ? byName["\(batch)|\(name)"] : nil)

            if let match {
                for suffix in ["assigned", "scanned", "completed", "impossible", "pdd_miss", "total", "complete_rate"] {
                    row["fresh_delivery_\(suffix)"] = match["delivery_\(suffix)"] ?? NSNull()
                }
                if match["fresh_miss"] != nil { row["fresh_miss"] = match["fresh_miss"] }
            } else {
                row["fresh_delivery_total"] = NSNull()
            }
            return row
        }
    }

    private static func delivery(_ row: [String: Any], prefix: String) -> MetaDelivery {
        let totalValue = row["\(prefix)_total"]
        let total = totalValue is NSNull ? 0 : int(totalValue)
        return MetaDelivery(
            total: total,
            misscan: int(row["\(prefix)_assigned"]),
            remaining: int(row["\(prefix)_scanned"]),
            completed: int(row["\(prefix)_completed"]),
            impossible: int(row["\(prefix)_impossible"]),
            pddMiss: int(row["\(prefix)_pdd_miss"]),
            hasData: prefix == "fresh_delivery" ? !(totalValue is NSNull) && total > 0 : total > 0
        )
    }

    private static func collection(_ row: [String: Any], prefix: String, includeAbsent: Bool) -> MetaCollection {
        let assigned = int(row["\(prefix)_pending"])
        let collected = int(row["\(prefix)_collected"])
        let rawUncollected = row["\(prefix)_uncollected"]
        let uncollected = rawUncollected is NSNull || rawUncollected == nil ? int(row["\(prefix)_uncollected_raw"]) : int(rawUncollected)
        let absent = includeAbsent ? int(row["\(prefix)_absent_raw"]) : 0
        let declared = int(row["\(prefix)_total"])
        let total = declared > 0 ? declared : assigned + collected + uncollected + absent
        return MetaCollection(total: total, assigned: assigned, collected: collected, uncollected: uncollected, absent: absent)
    }

    private static func isStarted(_ row: [String: Any]) -> Bool {
        if !text(row["scan_started_at"]).isEmpty { return true }
        return ["delivery_scanned", "delivery_completed", "delivery_impossible", "delivery_pdd_miss"].contains { int(row[$0]) > 0 }
    }

    private static func isCurrentShift(_ row: [String: Any]) -> Bool {
        text(row["schedule_date"]) == activeScheduleDate(wave: text(row["wave"]))
    }

    private static func activeScheduleDate(wave: String) -> String {
        let zone = TimeZone(identifier: "Asia/Seoul")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var date = Date()
        if wave.uppercased() == "WAVE1", calendar.component(.hour, from: date) < 12 {
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func normalizeRoute(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isLetter || $0.isNumber }
            .uppercased()
    }

    private static func cleanCamp(_ name: String, fallback: String = "") -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("M_") { return "M" + String(value.dropFirst(2)) }
        return value.isEmpty ? fallback.trimmingCharacters(in: .whitespacesAndNewlines) : value
    }

    private static func nameKey(_ value: String) -> String {
        value.filter { !$0.isWhitespace }.lowercased()
    }

    private static func array(_ value: Any?) -> [Any] {
        if let value = value as? [Any] { return value }
        return []
    }

    private static func dict(_ value: Any?) -> [String: Any] {
        if let value = value as? [String: Any] { return value }
        if let text = value as? String,
           let data = text.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }
        return [:]
    }

    private static func text(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        if let value = value as? String { return value.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let value = value as? NSNumber { return value.stringValue }
        return String(describing: value)
    }

    private static func int(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return Int(text(value)) ?? 0
    }

    private static func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return ["true", "1", "y", "yes"].contains(text(value).lowercased())
    }
}

struct MetaRealtimeReportView: View {
    @ObservedObject var store: MetaRealtimeStore
    let includeDrivers: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MAROOWELL")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(MaroowellTheme.deepYellow)
                    Text("실시간 배송 현황")
                        .font(.system(size: 24, weight: .black))
                }
                Spacer()
                Text(Date().metaReportTime)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MaroowellTheme.muted)
            }

            MetaRealtimeSummaryCard(summary: store.summary, lastPolledAt: store.lastPolledAt)

            ForEach(store.campSummaries) { camp in
                MetaCampSummaryCard(camp: camp)
            }

            if includeDrivers {
                ForEach(store.filteredRows) { row in
                    MetaDriverCard(row: row)
                }
            }
        }
        .padding(28)
        .frame(width: 1080, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.white)
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let self, !self.isEmpty else { return nil }
        return self
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
    var shortMetaTime: String {
        replacingOccurrences(of: "T", with: " ").prefix(16).description
    }
}

private extension Double {
    var percent1: String {
        String(format: "%.1f%%", self)
    }
}

private extension Date {
    var metaReportTime: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "yyyy.MM.dd HH:mm"
        return f.string(from: self)
    }
}
