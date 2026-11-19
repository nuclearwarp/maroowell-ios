import Foundation
import SwiftUI
import CoreLocation

/// In-app Kakao Maps API canvas, using the existing Supabase app session. No website login.
struct DriverRouteMapView: View {
    let camp: String
    let routes: [String]
    let dragon: Bool
    @StateObject private var store = DriverRouteMapStore()
    @State private var showSatellite = false
    @State private var showRoadview = false
    @State private var showAreas = true
    @State private var showBuildings = false
    @State private var showLegend = false
    @State private var selectedRoad: String? = nil

    private static func roadFill(_ road: String) -> Color {
        let hex = RoadNamePalette.forRoad(road).fill
        let numeric = UInt32(hex.dropFirst(), radix: 16) ?? 0xD4DBE2
        return Color(.sRGB, red: Double((numeric >> 16) & 255) / 255,
                     green: Double((numeric >> 8) & 255) / 255,
                     blue: Double(numeric & 255) / 255, opacity: 1)
    }

    private static func roadColor(_ road: String) -> Color {
        let hex = RoadNamePalette.forRoad(road).stroke
        let numeric = UInt32(hex.dropFirst(), radix: 16) ?? 0x334155
        return Color(
            .sRGB,
            red: Double((numeric >> 16) & 255) / 255,
            green: Double((numeric >> 8) & 255) / 255,
            blue: Double(numeric & 255) / 255,
            opacity: 1
        )
    }

    private var roadGroups: [(name: String, count: Int)] {
        Dictionary(grouping: store.buildings, by: { RoadNamePalette.canonicalRoad($0.road) })
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name.compare($1.name, options: [], range: nil, locale: Locale(identifier: "ko_KR")) == .orderedAscending }
    }

    private var polygons: [DriverRoutePolygon] {
        var result: [DriverRoutePolygon] = []
        if showAreas {
            for (index, area) in store.areas.enumerated() {
                for (ringIndex, ring) in area.rings.enumerated() {
                    result.append(.init(id: "area-\(index)-\(ringIndex)", label: area.code,
                                        coordinates: ring, colorIndex: index, building: false))
                }
            }
        }
        if showBuildings {
            for (index, group) in roadGroups.enumerated() where selectedRoad == nil || selectedRoad == group.name {
                for (buildingIndex, building) in store.buildings.enumerated()
                    where RoadNamePalette.canonicalRoad(building.road) == group.name {
                    for (ringIndex, ring) in building.rings.enumerated() {
                        result.append(.init(id: "building-\(buildingIndex)-\(ringIndex)",
                                            label: group.name, coordinates: ring,
                                            colorIndex: index, building: true,
                                            fillColor: RoadNamePalette.forRoad(group.name).fill,
                                            strokeColor: RoadNamePalette.forRoad(group.name).stroke))
                    }
                }
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Same header as "지도 조회"; controls align to the right.
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("지도 조회")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.10, green: 0.20, blue: 0.30))
                    Text(camp + " · " + routes.joined(separator: ", "))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color(red: 0.39, green: 0.50, blue: 0.61))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(showAreas ? "폴리곤 숨기기" : "폴리곤 표시") {
                    showAreas.toggle()
                }
                .frame(width: 98, height: 36)
                .mapHeaderButton()
                Button(showBuildings ? "도로명 숨기기" : "도로명 확인") {
                    if showBuildings {
                        showBuildings = false
                        showLegend = false
                    } else {
                        showBuildings = true
                        showLegend = true
                        if store.buildings.isEmpty { Task { await store.loadBuildings() } }
                    }
                }
                .frame(width: 85, height: 36)
                .mapHeaderButton()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white)

            ZStack(alignment: .topTrailing) {
                KakaoMapWebView(
                    polygons: polygons.map { item in
                        KakaoMapPolygon(
                            id: item.id, coordinates: item.coordinates,
                            label: item.building ? "" : item.label,
                            fillColor: item.fillColor, strokeColor: item.strokeColor
                        )
                    },
                    satelliteEnabled: showSatellite,
                    roadviewEnabled: showRoadview,
                    fitContent: !showBuildings
                )
                .ignoresSafeArea(edges: .bottom)

                HStack(spacing: 6) {
                    Button(showSatellite ? "일반" : "위성") { showSatellite.toggle() }
                        .frame(width: 70, height: 40)
                        .mapFloatingButton()
                    Button(showRoadview ? "로드뷰 종료" : "로드뷰") { showRoadview.toggle() }
                        .frame(width: 92, height: 40)
                        .mapFloatingButton()
                }
                .padding(.top, 10)
                .padding(.trailing, 10)

                if showBuildings && showLegend {
                    VStack(spacing: 5) {
                        HStack {
                            Text("도로명별 건물").font(.caption.weight(.bold))
                            Spacer(minLength: 4)
                            Button("선택 해제") { selectedRoad = nil }.font(.caption2)
                            Button("숨기기") { showLegend = false }.font(.caption2)
                        }
                        Divider()
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(roadGroups, id: \.name) { group in
                                    Button {
                                        selectedRoad = selectedRoad == group.name ? nil : group.name
                                    } label: {
                                        HStack(spacing: 6) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Self.roadFill(group.name))
                                                .frame(width: 11, height: 11)
                                            Text(group.name)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Text("\(group.count)")
                                                .monospacedDigit()
                                                .frame(minWidth: 20, alignment: .trailing)
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(selectedRoad == group.name
                                            ? Color.blue
                                            : Self.roadColor(group.name))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 5)
                                        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: 225, maxHeight: 265)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 8).padding(.bottom, 12)
                }
            }
            HStack(spacing: 6) {
                if store.loading { ProgressView().controlSize(.mini) }
                Text(store.status).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
        }
        .navigationTitle("")
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if store.areas.isEmpty { Task { await search() } }
        }
    }

    private func search() async {
        showBuildings = false
        showLegend = false
        selectedRoad = nil
        await store.load(camp: camp, prefixes: routes, dragon: dragon)
    }
}

private struct MapHeaderButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.61))
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color(red: 0.93, green: 0.97, blue: 1.0))
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .stroke(Color(red: 0.70, green: 0.85, blue: 0.95), lineWidth: 1))
            )
            .buttonStyle(.plain)
    }
}

private struct MapFloatingButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color(red: 0.14, green: 0.25, blue: 0.36))
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .stroke(Color(red: 0.82, green: 0.88, blue: 0.93), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
            .buttonStyle(.plain)
    }
}

private extension View {
    func mapHeaderButton() -> some View { modifier(MapHeaderButton()) }
    func mapFloatingButton() -> some View { modifier(MapFloatingButton()) }
}

private struct DriverRoutePolygon: Identifiable {
    let id: String
    let label: String
    let coordinates: [CLLocationCoordinate2D]
    let colorIndex: Int
    let building: Bool
    var fillColor: String? = nil
    var strokeColor: String? = nil
}
private struct DriverRouteArea {
    let code: String
    let camp: String
    let geometry: [String: Any]
    let rings: [[CLLocationCoordinate2D]]
}
private struct DriverRouteBuilding {
    let id: String
    let road: String
    let rings: [[CLLocationCoordinate2D]]
}

@MainActor
private final class DriverRouteMapStore: ObservableObject {
    @Published var areas: [DriverRouteArea] = []
    @Published var buildings: [DriverRouteBuilding] = []
    @Published var loading = false
    @Published var status = "캠프와 라우트를 입력해 조회하세요."
    private var queryID = 0

    func load(camp: String, prefixes: [String], dragon: Bool) async {
        let normalized = prefixes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }.filter { !$0.isEmpty }
        guard !camp.isEmpty && !normalized.isEmpty else { status = "캠프와 라우트를 입력해주세요."; return }
        queryID += 1
        let id = queryID
        loading = true
        status = "라우트 조회 중…"
        defer { loading = false }
        do {
            let session = try await SupabaseService.shared.client.auth.session
            let rawCamp = camp.replacingOccurrences(of: #"^용차\s*[·:]\s*"#, with: "", options: .regularExpression)
            var rows: [[String: Any]] = []
            if dragon {
                for prefix in normalized {
                    var c = URLComponents(string: "https://purple-river-0717.brain-0f6.workers.dev/route")!
                    c.queryItems = [
                        .init(name: "camp", value: rawCamp),
                        .init(name: "mode", value: "prefix"),
                        .init(name: "code", value: prefix)
                    ]
                    let obj = try await request(url: c.url!, token: nil)
                    rows += (obj as? [String: Any])?["rows"] as? [[String: Any]] ?? []
                }
            } else {
                var names = [rawCamp]
                if rawCamp.hasPrefix("M_") { names.append("M" + rawCamp.dropFirst(2)) }
                else if rawCamp.hasPrefix("M") { names.append("M_" + rawCamp.dropFirst(1)) }
                for name in names {
                    var c = URLComponents(url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/maroowell_sub_sub_route"),
                                          resolvingAgainstBaseURL: false)!
                    c.queryItems = [
                        .init(name:"select",value:"id,camp,route_code,route_norm,polygon_wgs84"),
                        .init(name:"camp",value:"eq.\(name)"),
                        .init(name:"is_active",value:"eq.true"),
                        .init(name:"limit",value:"1000")
                    ]
                    let response = try await request(url: c.url!, token: session.accessToken, supabase: true)
                    let matched = (response as? [[String: Any]] ?? []).filter { row in
                        let code = (row["route_code"] as? String ?? row["route_norm"] as? String ?? "").uppercased()
                        return normalized.contains { code.hasPrefix($0) }
                    }
                    rows += matched
                    if !matched.isEmpty { break }
                }
            }
            var parsed: [DriverRouteArea] = []
            var seen = Set<String>()
            for row in rows {
                let code = (row["full_code"] as? String ?? row["route_code"] as? String ?? row["code"] as? String ?? "").uppercased()
                guard normalized.contains(where: { code.hasPrefix($0) }) else { continue }
                guard let geometry = Self.geometry(row["polygon_wgs84"]) else { continue }
                let rings = Self.rings(geometry)
                guard !rings.isEmpty else { continue }
                let id = (row["id"] as? String ?? "") + code
                guard seen.insert(id).inserted else { continue }
                parsed.append(DriverRouteArea(code: code, camp: (row["camp"] as? String ?? rawCamp),
                                              geometry: geometry, rings: rings))
            }
            if id == queryID {
                areas = parsed.sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
                buildings = []
                status = areas.isEmpty ? "조회된 라우트가 없습니다." : "\(areas.count)개 서서브라우트 표시"
            }
        } catch {
            if id == queryID { status = "조회 실패: " + error.localizedDescription; areas = [] }
        }
    }

    func loadBuildings() async {
        guard !areas.isEmpty else { status = "먼저 라우트를 조회하세요."; return }
        loading = true
        status = "공공 건물 폴리곤 조회 중…"
        defer { loading = false }
        do {
            let session = try await SupabaseService.shared.client.auth.session
            var result: [String: DriverRouteBuilding] = [:]
            for area in areas {
                var offset = 0
                for _ in 0..<80 {
                    let requestBody: [String: Any] = ["polygon":area.geometry,"offset":offset,"limit":200]
                    let request = try await requestBuilding(body: requestBody, token: session.accessToken)
                    if (request["status"] as? String) == "warming" {
                        try await Task.sleep(nanoseconds: 2_500_000_000)
                        continue
                    }
                    guard (request["status"] as? String) == "ready" else { throw NSError(domain:"Building", code:1) }
                    let features = request["features"] as? [[String: Any]] ?? []
                    for feature in features {
                        let props = feature["properties"] as? [String: Any] ?? [:]
                        let id = String(describing: props["objectid"] ?? feature["id"] ?? props["building_id"] ?? "")
                        guard !id.isEmpty, let geometry = Self.geometry(feature["geometry"]) else { continue }
                        let rings = Self.rings(geometry)
                        guard !rings.isEmpty else { continue }
                        let street = (props["street_name"] as? String ?? props["streetName"] as? String ?? "도로명 미확인")
                        let road = RoadNamePalette.canonicalRoad(street.replacingOccurrences(
                            of: #"(?<=[길로])\s*\d+(?:-\d+)?$"#, with: "", options: .regularExpression))

                        result[id] = DriverRouteBuilding(id: id, road: road, rings: rings)
                    }
                    if request["hasMore"] as? Bool != true || features.isEmpty { break }
                    offset += features.count
                }
            }
            buildings = Array(result.values)
            status = "도로명 건물 \(buildings.count)개"
        } catch { status = "건물 조회 실패: " + error.localizedDescription }
    }

    private func request(url: URL, token: String?, supabase: Bool = false) async throws -> Any {
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if supabase { req.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey") }
        if let token { req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {
            throw NSError(domain: "RouteMap", code: status,
                          userInfo: [NSLocalizedDescriptionKey: "지도 데이터 HTTP \(status)"])
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func requestBuilding(body: [String:Any], token: String) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string:"https://purple-river-0717.brain-0f6.workers.dev/building-footprints/geometry")!)
        req.httpMethod = "POST"
        req.setValue("application/json",forHTTPHeaderField:"Content-Type")
        req.setValue("Bearer " + token,forHTTPHeaderField:"Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject:body)
        let (data,response) = try await URLSession.shared.data(for:req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status) else {throw NSError(domain:"Building",code:status)}
        return try JSONSerialization.jsonObject(with:data) as? [String:Any] ?? [:]
    }

    private static func geometry(_ value: Any?) -> [String:Any]? {
        if let object = value as? [String:Any] {
            if (object["type"] as? String) == "Feature" { return geometry(object["geometry"]) }
            return object
        }
        if let text = value as? String, let data = text.data(using:.utf8),
           let raw = try? JSONSerialization.jsonObject(with:data) {return geometry(raw)}
        if let raw = value as? [Any] {
            let coordinates: [Any] = ((raw.first as? [Any])?.first as? NSNumber) != nil ? [raw] : raw
            return ["type":"Polygon","coordinates":coordinates]
        }
        return nil
    }

    private static func rings(_ value: [String:Any]) -> [[CLLocationCoordinate2D]] {
        let type = value["type"] as? String ?? ""
        let input = value["coordinates"] as? [Any] ?? []
        func one(_ value: Any) -> [CLLocationCoordinate2D] {
            (value as? [[Any]] ?? []).compactMap { pair in
                guard pair.count >= 2, let lon = pair[0] as? NSNumber, let lat = pair[1] as? NSNumber else { return nil }
                guard abs(lon.doubleValue) <= 180 && abs(lat.doubleValue) <= 90 else { return nil }
                return CLLocationCoordinate2D(latitude:lat.doubleValue,longitude:lon.doubleValue)
            }
        }
        if type == "Polygon" {return input.map(one).filter { $0.count >= 3 }}
        if type == "MultiPolygon" {
            return input.flatMap { (polygon:Any) -> [[CLLocationCoordinate2D]] in
                (polygon as? [Any] ?? []).map(one).filter { $0.count >= 3 }
            }
        }
        return []
    }
}
