import Foundation
import MapKit
import SwiftUI

struct CampLookupView: View {
    @StateObject private var store = CampLookupStore()
    @State private var expandedTypes: Set<String> = []
    @State private var mapSelection: CampMapSelection?

    let session: AppSession

    var body: some View {
        Group {
            if session.isTeamLeader {
                content
            } else {
                permissionDenied
            }
        }
        .navigationTitle("쿠팡 캠프 조회")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if session.isTeamLeader {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        openCurrentMap()
                    } label: {
                        Label("지도", systemImage: "map.fill")
                    }
                    .disabled(store.mappableRows.isEmpty)
                }
            }
        }
        .task {
            guard session.isTeamLeader, store.rows.isEmpty else { return }
            await store.load()
        }
        .sheet(item: $mapSelection) { selection in
            CampMapSheet(selection: selection)
        }
        .alert("쿠팡 캠프 조회", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                searchCard

                if store.isLoading && store.rows.isEmpty {
                    ProgressView("캠프 데이터 불러오는 중...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if store.searchResults.isEmpty {
                    emptyState
                } else if store.normalizedQuery.isEmpty {
                    ForEach(store.typeGroups) { group in
                        typeGroupCard(group)
                    }
                } else {
                    ForEach(store.searchResults) { row in
                        CampLookupRowCard(row: row) {
                            openSingleMap(row)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .background(MaroowellTheme.background)
        .refreshable {
            await store.load()
        }
    }

    private var searchCard: some View {
        VStack(spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("유형별 요약 · 검색 · 지도")
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.muted)
                }
                Spacer()
                if store.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text("\(store.searchResults.count)개")
                        .font(.caption.weight(.black))
                        .foregroundStyle(MaroowellTheme.deepYellow)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(MaroowellTheme.yellow.opacity(0.18), in: Capsule())
                }
            }

            HStack(spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MaroowellTheme.muted)
                    TextField("캠프명 · 코드 · 주소 · 지역", text: $store.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                    if !store.query.isEmpty {
                        Button {
                            store.query = ""
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
                    Task { await store.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .black))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(store.isLoading)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MaroowellTheme.border, lineWidth: 1)
        }
    }

    private var statusText: String {
        if store.isLoading { return "캠프 데이터 불러오는 중..." }
        if store.normalizedQuery.isEmpty { return "전체 \(store.rows.count)개 캠프 · 유형을 눌러 펼쳐보세요." }
        return "검색 결과 \(store.searchResults.count)개"
    }

    private func typeGroupCard(_ group: CampTypeGroup) -> some View {
        let isExpanded = expandedTypes.contains(group.type)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if isExpanded {
                        expandedTypes.remove(group.type)
                    } else {
                        expandedTypes.insert(group.type)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(MaroowellTheme.yellow.opacity(0.18))
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(MaroowellTheme.deepYellow)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.type)
                            .font(.headline.weight(.black))
                            .foregroundStyle(MaroowellTheme.ink)
                        Text(group.regionSummary)
                            .font(.caption)
                            .foregroundStyle(MaroowellTheme.muted)
                            .lineLimit(1)
                    }

                    Spacer()
                    Text("\(group.rows.count)개")
                        .font(.caption.weight(.black))
                        .foregroundStyle(MaroowellTheme.deepYellow)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.black))
                        .foregroundStyle(MaroowellTheme.muted)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 14)
                LazyVStack(spacing: 9) {
                    ForEach(group.rows) { row in
                        CampLookupRowCard(row: row, compact: true) {
                            openSingleMap(row)
                        }
                    }
                }
                .padding(10)
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isExpanded ? MaroowellTheme.deepYellow.opacity(0.34) : MaroowellTheme.border, lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(MaroowellTheme.muted)
            Text("검색 결과가 없습니다.")
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
    }

    private var permissionDenied: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(MaroowellTheme.muted)
            Text("팀장 권한 이상만 이용할 수 있습니다.")
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
            Text("Android 앱과 동일한 권한 기준을 적용했습니다.")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaroowellTheme.background)
    }

    private func openSingleMap(_ row: CampLookupRow) {
        guard row.coordinate != nil || !row.address.isEmpty else {
            store.errorMessage = "이 캠프에는 지도에 표시할 주소나 좌표가 없습니다."
            return
        }
        mapSelection = CampMapSelection(title: row.displayName, rows: [row])
    }

    private func openCurrentMap() {
        let candidates = store.normalizedQuery.isEmpty ? store.rows : store.searchResults
        let mappable = candidates.filter { $0.coordinate != nil }
        guard !mappable.isEmpty else {
            store.errorMessage = "지도에 표시할 좌표가 없습니다."
            return
        }
        mapSelection = CampMapSelection(title: "쿠팡 캠프 지도", rows: mappable)
    }
}

private struct CampLookupRowCard: View {
    let row: CampLookupRow
    var compact = false
    let onMap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.displayName)
                        .font((compact ? Font.subheadline : Font.headline).weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                    if !row.subtitle.isEmpty {
                        Text(row.subtitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(MaroowellTheme.muted)
                    }
                }
                Spacer()
                if !row.type.isEmpty {
                    Text(row.type)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(MaroowellTheme.deepYellow)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(MaroowellTheme.yellow.opacity(0.16), in: Capsule())
                }
            }

            if !row.address.isEmpty {
                Label(row.address, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(MaroowellTheme.ink.opacity(0.78))
                    .lineLimit(2)
            }

            if !row.address.isEmpty || row.coordinate != nil {
                Button(action: onMap) {
                    Label("지도에서 위치 보기", systemImage: "map.fill")
                        .font(.caption.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(compact ? 12 : 14)
        .background(compact ? MaroowellTheme.background : Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MaroowellTheme.border.opacity(0.9), lineWidth: 1)
        }
    }
}

private struct CampMapSelection: Identifiable {
    let id = UUID()
    let title: String
    let rows: [CampLookupRow]
}

private struct CampMapSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var geocodedPoint: CampMapPoint?
    @State private var isResolving = false

    let selection: CampMapSelection

    private var directPoints: [CampMapPoint] {
        selection.rows.compactMap { row in
            guard let coordinate = row.coordinate else { return nil }
            return CampMapPoint(id: row.id, title: row.displayName, latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    private var points: [CampMapPoint] {
        if directPoints.isEmpty, let geocodedPoint { return [geocodedPoint] }
        return directPoints
    }

    var body: some View {
        NavigationStack {
            Group {
                if points.isEmpty {
                    VStack(spacing: 12) {
                        if isResolving {
                            ProgressView("주소 위치 확인 중...")
                        } else {
                            Image(systemName: "map")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(MaroowellTheme.muted)
                            Text("지도 좌표를 확인하지 못했습니다.")
                                .font(.headline.weight(.black))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MaroowellTheme.background)
                } else {
                    VStack(spacing: 0) {
                        Map(initialPosition: .automatic) {
                            ForEach(points) { point in
                                Marker(point.title, coordinate: point.coordinate)
                            }
                        }
                        if selection.rows.count > directPoints.count && selection.rows.count > 1 {
                            Text("좌표가 없는 \(selection.rows.count - directPoints.count)개 캠프는 지도에서 제외했습니다.")
                                .font(.caption2)
                                .foregroundStyle(MaroowellTheme.muted)
                                .padding(.horizontal, 12)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(Color.white)
                        }
                    }
                }
            }
            .navigationTitle(selection.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .task {
            await resolveSingleAddressIfNeeded()
        }
    }

    private func resolveSingleAddressIfNeeded() async {
        guard directPoints.isEmpty,
              selection.rows.count == 1,
              let row = selection.rows.first,
              !row.address.isEmpty else { return }

        isResolving = true
        defer { isResolving = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = row.address
        do {
            let response = try await MKLocalSearch(request: request).start()
            if let coordinate = response.mapItems.first?.placemark.coordinate {
                geocodedPoint = CampMapPoint(
                    id: row.id,
                    title: row.displayName,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
        } catch {
            geocodedPoint = nil
        }
    }
}

private struct CampMapPoint: Identifiable {
    let id: String
    let title: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@MainActor
private final class CampLookupStore: ObservableObject {
    @Published var rows: [CampLookupRow] = []
    @Published var query = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = CampLookupAPI()

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale(identifier: "ko_KR"))
    }

    var searchResults: [CampLookupRow] {
        guard !normalizedQuery.isEmpty else { return rows }
        return rows.filter { $0.searchText.lowercased(with: Locale(identifier: "ko_KR")).contains(normalizedQuery) }
    }

    var mappableRows: [CampLookupRow] {
        let candidates = normalizedQuery.isEmpty ? rows : searchResults
        return candidates.filter { $0.coordinate != nil }
    }

    var typeGroups: [CampTypeGroup] {
        let grouped = Dictionary(grouping: rows) { $0.normalizedType }
        return grouped.map { type, rows in
            CampTypeGroup(type: type, rows: rows)
        }.sorted { lhs, rhs in
            let li = CampLookupRow.typeOrderIndex(lhs.type)
            let ri = CampLookupRow.typeOrderIndex(rhs.type)
            if li != ri { return li < ri }
            return lhs.type.localizedStandardCompare(rhs.type) == .orderedAscending
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            rows = try await api.loadRows().sorted(by: CampLookupRow.sortBefore)
        } catch {
            errorMessage = "캠프 데이터를 불러오지 못했습니다. \(error.localizedDescription)"
        }
    }
}

private struct CampTypeGroup: Identifiable {
    let type: String
    let rows: [CampLookupRow]

    var id: String { type }

    var regionSummary: String {
        let counts = Dictionary(grouping: rows) { row in
            row.region.isEmpty ? "미분류" : row.region.uppercased()
        }.mapValues(\.count)

        return counts.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key.localizedStandardCompare($1.key) == .orderedAscending
        }
        .prefix(3)
        .map { "\($0.key) \($0.value)" }
        .joined(separator: " · ")
    }
}

private struct CampLookupAPI {
    private let endpoint = URL(string: "https://coupangcamp.brain-0f6.workers.dev/camps")!

    func loadRows() async throws -> [CampLookupRow] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CampLookupError.invalidResponse
        }

        let decoder = JSONDecoder()
        if let rows = try? decoder.decode([CampLookupRow].self, from: data) {
            return rows
        }
        if let wrapper = try? decoder.decode(CampLookupResponse.self, from: data) {
            return wrapper.rows
        }
        throw CampLookupError.decode
    }

    private struct CampLookupResponse: Decodable {
        let rows: [CampLookupRow]
    }

    private enum CampLookupError: LocalizedError {
        case invalidResponse
        case decode

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "캠프 조회 서버 응답을 확인해주세요."
            case .decode: "캠프 조회 응답 형식이 올바르지 않습니다."
            }
        }
    }
}

private struct CampLookupRow: Decodable, Identifiable {
    let backendID: Int64?
    let camp: String
    let code: String
    let address: String
    let region: String
    let type: String
    let mbCamp: String
    let parentCamp: String
    let receivingSH: String
    let description: String
    let latitude: Double?
    let longitude: Double?

    var id: String {
        backendID.map(String.init) ?? [camp, code, address].joined(separator: "|")
    }

    var displayName: String {
        camp.nilIfBlank ?? code.nilIfBlank ?? "캠프명 없음"
    }

    var normalizedType: String {
        type.nilIfBlank ?? "미분류"
    }

    var subtitle: String {
        [type, region, code].compactMap(\.nilIfBlank).joined(separator: " · ")
    }

    var searchText: String {
        [camp, code, address, region, type, mbCamp, parentCamp, receivingSH, description].joined(separator: " ")
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude,
              latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func typeOrderIndex(_ type: String) -> Int {
        let order = ["로켓", "V캠프", "SUB_HUB", "M캠프"]
        return order.firstIndex { $0.caseInsensitiveCompare(type) == .orderedSame } ?? 99
    }

    static func sortBefore(_ lhs: CampLookupRow, _ rhs: CampLookupRow) -> Bool {
        let li = typeOrderIndex(lhs.normalizedType)
        let ri = typeOrderIndex(rhs.normalizedType)
        if li != ri { return li < ri }
        let campOrder = lhs.camp.localizedStandardCompare(rhs.camp)
        if campOrder != .orderedSame { return campOrder == .orderedAscending }
        return lhs.code.localizedStandardCompare(rhs.code) == .orderedAscending
    }

    private enum CodingKeys: String, CodingKey {
        case backendID = "id"
        case camp, code, address, region
        case type = "camp_type"
        case mbCamp = "mb_camp"
        case parentCamp = "parent_camp"
        case parentCampName = "parent_camp_name"
        case receivingSH = "receiving_sh"
        case receivingSHName = "receiving_sh_name"
        case description, latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        backendID = try c.decodeIfPresent(Int64.self, forKey: .backendID)
        camp = try c.decodeIfPresent(String.self, forKey: .camp) ?? ""
        code = try c.decodeIfPresent(String.self, forKey: .code) ?? ""
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        region = try c.decodeIfPresent(String.self, forKey: .region) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        mbCamp = try c.decodeIfPresent(String.self, forKey: .mbCamp) ?? ""
        let parentCampValue = try c.decodeIfPresent(String.self, forKey: .parentCamp)
        let parentCampNameValue = try c.decodeIfPresent(String.self, forKey: .parentCampName)
        parentCamp = parentCampValue ?? parentCampNameValue ?? ""
        let receivingSHValue = try c.decodeIfPresent(String.self, forKey: .receivingSH)
        let receivingSHNameValue = try c.decodeIfPresent(String.self, forKey: .receivingSHName)
        receivingSH = receivingSHValue ?? receivingSHNameValue ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
