import CoreLocation
import SwiftUI

struct RouteInfoView: View {
    let session: AppSession
    @StateObject private var store = RouteInfoStore()
    @State private var selectedRow: RouteInfoRow?
    @State private var selectionMode = false
    @State private var selectedIDs: Set<String> = []
    @State private var showMap = false

    var body: some View {
        Group {
            if session.canView("/maroowell_route_info") {
                content
            } else {
                ContentUnavailableView("마루웰 라우트정보 권한이 필요합니다.", systemImage: "lock.fill")
            }
        }
        .navigationTitle("마루웰 라우트정보")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard session.canView("/maroowell_route_info"), store.rows.isEmpty else { return }
            await store.load(camp: session.campCode)
        }
        .sheet(item: $selectedRow) { row in
            RouteInfoDetail(row: row)
        }
        .navigationDestination(isPresented: $showMap) {
            RoutePolygonMapView(rows: selectedRows)
        }
        .alert("라우트정보", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
    }

    private var selectedRows: [RouteInfoRow] {
        store.rows.filter { selectedIDs.contains($0.id) }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                controls

                if store.loading && store.rows.isEmpty {
                    ProgressView("라우트정보 불러오는 중...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else if store.filtered.isEmpty {
                    Text("조회된 라우트 정보가 없습니다.")
                        .foregroundStyle(MaroowellTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                } else {
                    ForEach(store.filtered) { row in
                        routeCard(row)
                    }
                }
            }
            .padding(16)
        }
        .background(MaroowellTheme.background)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MaroowellTheme.muted)
                TextField("캠프 / 라우트 / 서브 / 설명 필터", text: $store.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
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

            HStack(spacing: 8) {
                Button(selectionMode ? "선택 취소" : "여러개 선택") {
                    selectionMode.toggle()
                    if !selectionMode { selectedIDs.removeAll() }
                }
                .buttonStyle(.bordered)

                Button {
                    showMap = true
                } label: {
                    Text(selectedIDs.isEmpty ? "지도 보기" : "지도 보기 (\(selectedIDs.count))")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!selectionMode || selectedIDs.isEmpty)
            }

            HStack {
                if selectionMode {
                    Text(selectedIDs.isEmpty ? "지도에서 볼 라우트를 선택하세요." : "\(selectedIDs.count)개 선택됨")
                } else {
                    Text(store.loading ? "데이터 불러오는 중..." : "\(store.filtered.count)건")
                }
                Spacer()
                Button {
                    Task { await store.load() }
                } label: {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.loading)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(MaroowellTheme.muted)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(MaroowellTheme.border) }
    }

    private func routeCard(_ row: RouteInfoRow) -> some View {
        let selected = selectedIDs.contains(row.id)
        return Button {
            if selectionMode {
                if selected { selectedIDs.remove(row.id) }
                else { selectedIDs.insert(row.id) }
            } else {
                selectedRow = row
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                if selectionMode {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selected ? MaroowellTheme.deepYellow : MaroowellTheme.muted)
                        .padding(.top, 1)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text(row.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(MaroowellTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !row.description.isEmpty {
                        Text("설명  \(row.description)")
                            .font(.caption)
                            .foregroundStyle(MaroowellTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !row.memo.isEmpty {
                        Text("메모  \(row.memo)")
                            .font(.caption)
                            .foregroundStyle(MaroowellTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(14)
            .background(
                selected ? Color(red: 0.937, green: 0.965, blue: 1.0) : Color.white,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selected ? MaroowellTheme.deepYellow : MaroowellTheme.border, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RouteInfoDetail: View {
    let row: RouteInfoRow

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    detail("캠프", row.camp)
                    detail("라우트", row.fullRoute)
                    detail("서브", row.sub)
                    detail("서서브", row.subSub)
                    detail("서브패키지", row.subPackage)
                    detail("설명", row.description)
                    detail("메모", row.memo)
                    detail("좌표", row.coordinate)
                }
                .padding(16)
            }
            .background(MaroowellTheme.background)
            .navigationTitle(row.fullRoute.isEmpty ? "라우트 정보" : row.fullRoute)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func detail(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption.weight(.bold)).foregroundStyle(MaroowellTheme.muted)
                Text(value).font(.body).textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(MaroowellTheme.border) }
        }
    }
}

private struct RoutePolygonMapView: View {
    let rows: [RouteInfoRow]
    @StateObject private var store = RoutePolygonStore()

    var body: some View {
        ZStack {
            RoutePolygonMapCanvas(polygons: store.polygons)
                .ignoresSafeArea(edges: .bottom)

            if store.loading {
                ProgressView("폴리곤 불러오는 중...")
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            } else if store.polygons.isEmpty {
                ContentUnavailableView("등록된 폴리곤이 없습니다.", systemImage: "map")
            }
        }
        .navigationTitle(rows.count == 1 ? rows[0].fullRoute : "라우트 지도 \(rows.count)개")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.polygons.isEmpty { await store.load(rows: rows) }
        }
        .alert("라우트 지도", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }
}

private struct RoutePolygonItem: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let label: String

    var center: CLLocationCoordinate2D {
        guard !coordinates.isEmpty else { return .init() }
        let lat = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let lon = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        return .init(latitude: lat, longitude: lon)
    }
}

private struct RoutePolygonMapCanvas: View {
    let polygons: [RoutePolygonItem]

    var body: some View {
        KakaoMapWebView(
            polygons: polygons.map { item in
                KakaoMapPolygon(
                    id: item.id.uuidString,
                    coordinates: item.coordinates,
                    label: item.label
                )
            },
            fitContent: true
        )
    }
}

@MainActor
private final class RoutePolygonStore: ObservableObject {
    @Published var polygons: [RoutePolygonItem] = []
    @Published var loading = false
    @Published var message: String?

    func load(rows: [RouteInfoRow]) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }

        do {
            let auth = try await SupabaseService.shared.client.auth.session
            let multipleCamps = Set(rows.map(\.camp)).count > 1
            var output: [RoutePolygonItem] = []

            for row in rows {
                var c = URLComponents(
                    url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/maroowell_sub_sub_route"),
                    resolvingAgainstBaseURL: false
                )!
                c.queryItems = [
                    .init(name: "select", value: "id,route_code,route_norm,polygon_wgs84,subsubroute_id"),
                    .init(name: "camp", value: "eq.\(row.camp)"),
                    .init(name: "is_active", value: "eq.true"),
                    .init(name: "or", value: "(route_code.eq.\(row.fullRoute),route_norm.eq.\(row.fullRoute))"),
                    .init(name: "order", value: "created_at.asc")
                ]
                var request = URLRequest(url: c.url!)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
                let (data, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard (200..<300).contains(code) else {
                    throw NSError(domain: "RoutePolygon", code: code, userInfo: [NSLocalizedDescriptionKey: "폴리곤 조회 실패 (\(code))"])
                }

                let records = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                let label = multipleCamps ? "\(row.camp) · \(row.fullRoute)" : row.fullRoute
                for record in records {
                    for ring in Self.rings(from: record["polygon_wgs84"]) where ring.count >= 3 {
                        output.append(.init(coordinates: ring, label: label))
                    }
                }
            }
            polygons = output
        } catch {
            polygons = []
            message = error.localizedDescription
        }
    }

    private static func rings(from value: Any?) -> [[CLLocationCoordinate2D]] {
        let object: [String: Any]?
        if let dict = value as? [String: Any] {
            object = dict
        } else if let text = value as? String,
                  let data = text.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            object = dict
        } else {
            object = nil
        }
        guard let object,
              let type = object["type"] as? String,
              let coordinates = object["coordinates"] else { return [] }

        func ring(_ raw: Any) -> [CLLocationCoordinate2D] {
            (raw as? [[Any]] ?? []).compactMap { pair in
                guard pair.count >= 2,
                      let lon = number(pair[0]),
                      let lat = number(pair[1]),
                      lat.isFinite, lon.isFinite else { return nil }
                return .init(latitude: lat, longitude: lon)
            }
        }

        if type == "Polygon" {
            return (coordinates as? [Any] ?? []).map(ring)
        }
        if type == "MultiPolygon" {
            return (coordinates as? [Any] ?? []).flatMap { polygon in
                (polygon as? [Any] ?? []).map(ring)
            }
        }
        return []
    }

    private static func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }
}

private struct RouteInfoRow: Identifiable, Hashable {
    let id: String
    let camp: String
    let route: String
    let sub: String
    let subSub: String
    let subPackage: String
    let description: String
    let memo: String
    let coordinate: String
    let sortOrder: Int

    var fullRoute: String {
        var value = route.replacingOccurrences(of: " ", with: "").uppercased()
        let normalizedSub = sub.replacingOccurrences(of: " ", with: "").uppercased()
        let normalizedSubSub = subSub.replacingOccurrences(of: " ", with: "").uppercased()
        if !normalizedSub.isEmpty && !value.hasSuffix(normalizedSub) { value += normalizedSub }
        if !normalizedSubSub.isEmpty && !value.hasSuffix(normalizedSubSub) { value += normalizedSubSub }
        return value
    }

    var title: String {
        let displayCamp = camp.hasPrefix("M_") ? "M" + String(camp.dropFirst(2)) : camp
        return [displayCamp, fullRoute].filter { !$0.isEmpty }.joined(separator: " - ")
    }

    var searchable: String {
        [camp, route, sub, subSub, fullRoute, description, memo].joined(separator: " ").lowercased()
    }
}

@MainActor
private final class RouteInfoStore: ObservableObject {
    @Published var rows: [RouteInfoRow] = []
    @Published var query = ""
    @Published var loading = false
    @Published var message: String?

    var filtered: [RouteInfoRow] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let compact = Self.compact(q)
        guard !q.isEmpty else { return rows }
        return rows.filter {
            $0.searchable.contains(q) || (!compact.isEmpty && Self.compact($0.searchable).contains(compact))
        }
    }

    func load(camp: String) async {
        guard !loading else { return }
        let requestedCamp = Self.databaseCamp(camp)
        guard !requestedCamp.isEmpty else {
            rows = []
            message = "소속 캠프를 확인하지 못했습니다."
            return
        }
        loading = true
        defer { loading = false }
        do {
            let auth = try await SupabaseService.shared.client.auth.session
            var c = URLComponents(url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/maroowell_route_info"), resolvingAgainstBaseURL: false)!
            c.queryItems = [
                URLQueryItem(name: "select", value: "id,camp,route,sub,sub_sub,sub_package,route_code,route_norm,description,memo,coordinate,sort_order,is_active"),
                URLQueryItem(name: "camp", value: "eq.(requestedCamp)"),
                URLQueryItem(name: "order", value: "camp.asc,route.asc,sort_order.asc"),
                URLQueryItem(name: "limit", value: "500")
            ]
            var request = URLRequest(url: c.url!)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(code) else {
                throw NSError(domain: "RouteInfo", code: code, userInfo: [NSLocalizedDescriptionKey: "라우트정보 조회 실패 (\(code))"])
            }
            let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
            rows = raw.map(Self.row).sorted {
                let campCmp = $0.camp.localizedStandardCompare($1.camp)
                if campCmp != .orderedSame { return campCmp == .orderedAscending }
                return $0.fullRoute.localizedStandardCompare($1.fullRoute) == .orderedAscending
            }
        } catch {
            rows = []
            message = error.localizedDescription
        }
    }

    private static func databaseCamp(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.uppercased().hasPrefix("M_") { return value }
        if value.uppercased().hasPrefix("M"), value.count > 1 {
            return "M_" + String(value.dropFirst())
        }
        return value
    }

    private static func row(_ object: [String: Any]) -> RouteInfoRow {
        let camp = text(object["camp"])
        let route = text(object["route"])
        let sub = text(object["sub"])
        let subSub = text(object["sub_sub"])
        let sort = Int(text(object["sort_order"])) ?? 0
        return RouteInfoRow(
            id: text(object["id"]).isEmpty ? [camp, route, sub, subSub, String(sort)].joined(separator: "|") : text(object["id"]),
            camp: camp,
            route: route,
            sub: sub,
            subSub: subSub,
            subPackage: text(object["sub_package"]),
            description: text(object["description"]),
            memo: text(object["memo"]),
            coordinate: text(object["coordinate"]),
            sortOrder: sort
        )
    }

    private static func text(_ value: Any?) -> String {
        guard let value, !(value is NSNull) else { return "" }
        let text = (value as? String ?? String(describing: value)).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || ["null", "undefined", "nan"].contains(text.lowercased()) { return "" }
        return text
    }

    private static func compact(_ value: String) -> String {
        value.uppercased().filter { $0.isNumber || $0.isLetter }
    }
}
