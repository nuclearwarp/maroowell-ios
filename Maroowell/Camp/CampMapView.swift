import Foundation
import MapKit
import SwiftUI

struct CampMapView: View {
    let session: AppSession
    let initialQuery: String
    @StateObject private var store = CampMapStore()
    @State private var camera: MapCameraPosition = .automatic

    init(session: AppSession, query: String = "") {
        self.session = session
        self.initialQuery = query
    }

    var body: some View {
        Group {
            if session.canView("/coupang_camp") { content }
            else { denied }
        }
        .navigationTitle("쿠팡 캠프 지도")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if store.rows.isEmpty {
                store.query = initialQuery
                await store.load()
                fit()
            }
        }
        .alert("쿠팡 캠프 지도", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("캠프 · 지역 · 코드 검색", text: $store.query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { Task { await store.load(); fit() } }
                Button("검색") { Task { await store.load(); fit() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.loading)
            }
            .padding(12)
            .background(Color.white)

            Map(position: $camera) {
                ForEach(store.rows) { row in
                    Marker(row.markerLabel, coordinate: row.coordinate)
                        .tint(row.isSubHub ? .orange : .blue)
                }
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 7) {
                    if store.loading { ProgressView().controlSize(.small) }
                    Text(store.loading ? "캠프 위치 불러오는 중…" : "\(store.rows.count)개 캠프")
                        .font(.caption.weight(.black))
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
            }

            if !store.rows.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.rows.prefix(30)) { row in
                            Button {
                                camera = .region(MKCoordinateRegion(center: row.coordinate, span: .init(latitudeDelta: 0.025, longitudeDelta: 0.025)))
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.markerLabel).font(.caption.weight(.black)).lineLimit(1)
                                    Text([row.region, row.address].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption2).foregroundStyle(MaroowellTheme.muted).lineLimit(1)
                                }
                                .frame(width: 190, alignment: .leading)
                                .padding(10)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }.padding(10)
                }
                .background(MaroowellTheme.background)
            }
        }
        .background(MaroowellTheme.background)
    }

    private func fit() {
        guard !store.rows.isEmpty else { return }
        let lats = store.rows.map { $0.coordinate.latitude }
        let lons = store.rows.map { $0.coordinate.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        camera = .region(MKCoordinateRegion(center: center, span: .init(latitudeDelta: max(maxLat - minLat, 0.04) * 1.25, longitudeDelta: max(maxLon - minLon, 0.04) * 1.25)))
    }

    private var denied: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill").font(.largeTitle)
            Text("마루웰 팀장 권한 이상만 이용할 수 있습니다.").font(.headline.weight(.black))
        }
        .foregroundStyle(MaroowellTheme.muted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaroowellTheme.background)
    }
}

private struct CampMapRow: Identifiable {
    let camp: String
    let code: String
    let address: String
    let region: String
    let type: String
    let mbCamp: String
    let parentCamp: String
    let receivingSH: String
    let detail: String
    let latitude: Double
    let longitude: Double

    var id: String { [camp, code, String(latitude), String(longitude)].joined(separator: "|") }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var isSubHub: Bool { type.caseInsensitiveCompare("SUB_HUB") == .orderedSame }
    var markerLabel: String {
        if isSubHub { return code.isEmpty ? (camp.isEmpty ? "SH" : camp) : code }
        if !camp.isEmpty, !mbCamp.isEmpty, camp.caseInsensitiveCompare(mbCamp) != .orderedSame { return "\(camp) · \(mbCamp)" }
        if !camp.isEmpty { return camp }
        if !mbCamp.isEmpty { return mbCamp }
        return code.isEmpty ? "쿠팡 캠프" : code
    }
}

@MainActor
private final class CampMapStore: ObservableObject {
    @Published var query = ""
    @Published var rows: [CampMapRow] = []
    @Published var loading = false
    @Published var message: String?

    func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let url = URL(string: "https://coupangcamp.brain-0f6.workers.dev/camps")!
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "CampMap", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "캠프 조회 실패"])
            }
            let root = try JSONSerialization.jsonObject(with: data)
            let source: [[String: Any]]
            if let array = root as? [[String: Any]] { source = array }
            else if let object = root as? [String: Any] { source = object["rows"] as? [[String: Any]] ?? [] }
            else { source = [] }
            let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            rows = source.compactMap(Self.row).filter { row in
                guard needle.isEmpty else {
                    return [row.camp,row.code,row.address,row.region,row.type,row.mbCamp,row.parentCamp,row.receivingSH,row.detail]
                        .contains { $0.lowercased().contains(needle) }
                }
                return true
            }
            if rows.isEmpty { message = "지도에 표시할 캠프 위치가 없습니다." }
        } catch {
            rows = []
            message = error.localizedDescription
        }
    }

    private static func row(_ object: [String: Any]) -> CampMapRow? {
        let lat = number(object["latitude"])
        let lon = number(object["longitude"])
        guard let lat, let lon, lat.isFinite, lon.isFinite else { return nil }
        return .init(
            camp: text(object["camp"]), code: text(object["code"]), address: text(object["address"]),
            region: text(object["region"]), type: text(object["camp_type"]), mbCamp: text(object["mb_camp"]),
            parentCamp: text(object["parent_camp"]).isEmpty ? text(object["parent_camp_name"]) : text(object["parent_camp"]),
            receivingSH: text(object["receiving_sh"]).isEmpty ? text(object["receiving_sh_name"]) : text(object["receiving_sh"]),
            detail: text(object["description"]), latitude: lat, longitude: lon
        )
    }
    private static func text(_ value: Any?) -> String {
        if let s = value as? String { return s.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let n = value as? NSNumber { return n.stringValue }
        return ""
    }
    private static func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }
}
