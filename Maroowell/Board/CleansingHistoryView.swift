import Foundation
import SwiftUI

struct CleansingHistoryView: View {
    let session: AppSession
    @StateObject private var store = CleansingHistoryStore()

    var body: some View {
        Group {
            if session.canView("/cleansing_history") {
                content
            } else {
                permissionDenied
            }
        }
        .navigationTitle("클렌징 히스토리")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard session.canView("/cleansing_history"), store.rows.isEmpty else { return }
            await store.bootstrap()
        }
        .alert("클렌징 히스토리", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                searchCard

                if store.loading && store.rows.isEmpty {
                    ProgressView("최신 데이터를 불러오는 중...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if store.rows.isEmpty {
                    emptyState
                } else {
                    ForEach(store.rows) { row in
                        CleansingHistoryRowCard(row: row)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .background(MaroowellTheme.background)
        .refreshable { await store.search() }
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("캠프 · 라우트 · 우편번호 통합 검색")
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                    Text(store.week.isEmpty ? "최신 주차 확인 중" : "최신 주차 · \(store.week)")
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                Text("\(store.rows.count)건")
                    .font(.caption.weight(.black))
                    .foregroundStyle(MaroowellTheme.deepYellow)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(MaroowellTheme.yellow.opacity(0.18), in: Capsule())
            }

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MaroowellTheme.muted)
                    TextField("캠프 · 라우트 · 우편번호 · 업체 · 사유", text: $store.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await store.search() } }
                    if !store.query.isEmpty {
                        Button {
                            store.query = ""
                            Task { await store.search() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(MaroowellTheme.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                Button {
                    Task { await store.search() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .black))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.loading)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(MaroowellTheme.muted)
            Text("조회된 클렌징 이력이 없습니다.")
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
            Text(store.week.isEmpty ? "최신 주차 데이터가 없습니다." : "검색 조건을 바꿔보세요.")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
    }

    private var permissionDenied: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill").font(.largeTitle)
            Text("클렌징 히스토리 권한이 필요합니다.")
                .font(.headline.weight(.black))
        }
        .foregroundStyle(MaroowellTheme.muted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaroowellTheme.background)
    }
}

private struct CleansingHistoryRowCard: View {
    let row: CleansingHistoryRow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(MaroowellTheme.ink)
                Spacer()
                if !row.waveLabel.isEmpty {
                    Text(row.waveLabel)
                        .font(.caption.weight(.black))
                        .foregroundStyle(row.waveLabel == "주간" ? MaroowellTheme.deepYellow : MaroowellTheme.ink)
                }
            }

            Divider()

            detail("우편번호", row.zip)
            detail("배송 필요", row.demand)
            detail("배송 완료", row.complete)
            detail("수행률", row.executionRateLabel)
            detail("등급", row.executionRateGrade)
            detail("사유", row.reason)
            detail("업체", row.vendorName)
            detail("사업자번호", row.businessNumber)
            detail("단가", row.priceLabel)
        }
        .padding(14)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardBorder, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func detail(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MaroowellTheme.muted)
                    .frame(width: 82, alignment: .leading)
                Text(value)
                    .font(.subheadline.weight(label == "우편번호" ? .bold : .regular))
                    .foregroundStyle(MaroowellTheme.ink)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
        }
    }

    private var cardBackground: Color {
        switch row.status {
        case "클렌징": return Color(red: 1.0, green: 0.95, blue: 0.96)
        case "경고": return Color(red: 1.0, green: 0.97, blue: 0.92)
        default: return .white
        }
    }

    private var cardBorder: Color {
        switch row.status {
        case "클렌징": return Color(red: 0.99, green: 0.79, blue: 0.79)
        case "경고": return Color(red: 0.99, green: 0.84, blue: 0.67)
        default: return MaroowellTheme.border
        }
    }
}

private struct CleansingHistoryRow: Identifiable, Hashable {
    let id: String
    let week: String
    let camp: String
    let wave: String
    let route: String
    let zip: String
    let demand: String
    let complete: String
    let executionRate: String
    let executionRateGrade: String
    let reason: String
    let vendorName: String
    let businessNumber: String
    let price: String
    let status: String

    var title: String {
        let normalizedCamp = camp.replacingOccurrences(of: "^M_", with: "M", options: .regularExpression)
        return [normalizedCamp, route.uppercased()].filter { !$0.isEmpty }.joined(separator: " - ").isEmpty
            ? "클렌징 이력"
            : [normalizedCamp, route.uppercased()].filter { !$0.isEmpty }.joined(separator: " - ")
    }

    var waveLabel: String {
        switch wave.uppercased() {
        case "1W", "W1", "WAVE1", "야간": return "야간"
        case "2W", "W2", "WAVE2", "주간": return "주간"
        default: return wave
        }
    }

    var executionRateLabel: String {
        guard !executionRate.isEmpty else { return "" }
        return executionRate.hasSuffix("%") ? executionRate : "\(executionRate)%"
    }

    var priceLabel: String {
        guard !price.isEmpty else { return "" }
        if let value = Double(price) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return "\(formatter.string(from: NSNumber(value: value)) ?? price)원"
        }
        return price
    }
}

@MainActor
private final class CleansingHistoryStore: ObservableObject {
    @Published var rows: [CleansingHistoryRow] = []
    @Published var query = ""
    @Published var week = ""
    @Published var loading = false
    @Published var message: String?

    private let cleansingAPI = URL(string: "https://cleansinghistory.maroowell.com/api/cleansing-history")!

    func bootstrap() async {
        loading = true
        defer { loading = false }
        do {
            week = try await latestWeek()
            guard !week.isEmpty else {
                rows = []
                return
            }
            rows = try await fetchRows(query: "")
        } catch {
            rows = []
            message = error.localizedDescription
        }
    }

    func search() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            if week.isEmpty { week = try await latestWeek() }
            rows = week.isEmpty ? [] : try await fetchRows(query: query.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            rows = []
            message = error.localizedDescription
        }
    }

    private func latestWeek() async throws -> String {
        let auth = try await SupabaseService.shared.client.auth.session
        var components = URLComponents(
            url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/cleansing_history"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "select", value: "week"),
            URLQueryItem(name: "week", value: "not.is.null"),
            URLQueryItem(name: "limit", value: "1000")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, fallback: "최근 주차 조회 실패")
        let payload = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return payload.compactMap { Self.text($0["week"]) }.filter { !$0.isEmpty }.max(by: {
            Self.weekSortKey($0) < Self.weekSortKey($1)
        }) ?? ""
    }

    private func fetchRows(query: String) async throws -> [CleansingHistoryRow] {
        let auth = try await SupabaseService.shared.client.auth.session
        var components = URLComponents(url: cleansingAPI, resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "limit", value: "1000"), URLQueryItem(name: "week", value: week)]
        if !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response, fallback: "클렌징 이력 조회 실패")

        let root = try JSONSerialization.jsonObject(with: data)
        let rawRows: [[String: Any]]
        if let array = root as? [[String: Any]] {
            rawRows = array
        } else if let object = root as? [String: Any] {
            rawRows = object["rows"] as? [[String: Any]] ?? []
        } else {
            rawRows = []
        }

        return rawRows.map(Self.row).sorted {
            let leftWave = Self.waveOrder($0.wave)
            let rightWave = Self.waveOrder($1.wave)
            if leftWave != rightWave { return leftWave < rightWave }
            if $0.camp != $1.camp { return $0.camp.localizedStandardCompare($1.camp) == .orderedAscending }
            return $0.route.localizedStandardCompare($1.route) == .orderedAscending
        }
    }

    private static func row(_ object: [String: Any]) -> CleansingHistoryRow {
        let week = text(object["week"])
        let camp = text(object["camp"])
        let route = text(object["route"])
        let zip = text(object["zip"])
        return CleansingHistoryRow(
            id: [week, camp, route, zip, text(object["created_at"])].joined(separator: "|"),
            week: week,
            camp: camp,
            wave: text(object["wave"]),
            route: route,
            zip: zip,
            demand: text(object["demand"]),
            complete: text(object["complete"]),
            executionRate: text(object["execution_rate"]),
            executionRateGrade: text(object["execution_rate_grade"]),
            reason: text(object["reason"]),
            vendorName: text(object["vendor_name"]),
            businessNumber: text(object["business_number"]),
            price: text(object["price"]),
            status: text(object["cleansing_status"])
        )
    }

    private static func text(_ value: Any?) -> String {
        if value == nil || value is NSNull { return "" }
        if let string = value as? String { return string.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value ?? "")
    }

    private static func waveOrder(_ value: String) -> Int {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "2W", "W2", "WAVE2", "주간": return 0
        case "1W", "W1", "WAVE1", "야간": return 1
        default: return 2
        }
    }

    private static func weekSortKey(_ value: String) -> Int {
        let pattern = #"(20\d{2}).*?(\d{1,2})\s*W"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return 0 }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range), match.numberOfRanges >= 3,
              let yearRange = Range(match.range(at: 1), in: value),
              let weekRange = Range(match.range(at: 2), in: value),
              let year = Int(value[yearRange]), let week = Int(value[weekRange]) else { return 0 }
        return year * 100 + week
    }

    private static func validate(_ response: URLResponse, fallback: String) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "CleansingHistory", code: code, userInfo: [NSLocalizedDescriptionKey: "\(fallback) (\(code))"])
        }
    }
}