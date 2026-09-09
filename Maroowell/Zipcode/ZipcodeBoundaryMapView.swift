import Foundation
import MapKit
import SwiftUI

struct ZipcodeBoundaryMapView: View {
    let session: AppSession
    @StateObject private var store = ZipcodeBoundaryMapStore()
    @State private var input = ""
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if session.canView("/zipcode_search") { content }
            else { denied }
        }
        .navigationTitle("우편번호 경계 지도")
        .navigationBarTitleDisplayMode(.inline)
        .alert("우편번호 검색", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Map(position: $camera) {
                ForEach(store.rings) { ring in
                    MapPolygon(coordinates: ring.coordinates)
                        .foregroundStyle(.yellow.opacity(0.16))
                        .stroke(.orange, lineWidth: 2)
                }
            }
            .frame(minHeight: 310)
            .overlay(alignment: .topLeading) {
                Text(store.rings.isEmpty ? "우편번호를 입력하세요" : "경계 \(store.rings.count)개")
                    .font(.caption.weight(.black)).padding(.horizontal, 9).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule()).padding(9)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("EPSG:5179 우편번호 경계를 WGS84로 변환해 지도에 표시합니다.")
                        .font(.caption).foregroundStyle(MaroowellTheme.muted)
                    TextField("예: 07420, 07421 07422", text: $input, axis: .vertical)
                        .lineLimit(2...4).textFieldStyle(.roundedBorder).keyboardType(.numberPad)
                    HStack(spacing: 8) {
                        Button("지도표시") {
                            let zips = ZipcodeBoundaryInput.parse(input)
                            Task { await store.load(zips); fit() }
                        }
                        .buttonStyle(.borderedProminent).disabled(store.loading)
                        Button("초기화") { input = ""; store.clear(); camera = .automatic }
                            .buttonStyle(.bordered)
                    }
                    HStack {
                        if store.loading { ProgressView().controlSize(.small) }
                        Text(store.status).font(.caption.weight(.semibold)).foregroundStyle(MaroowellTheme.muted)
                    }
                    ForEach(store.loadedZips, id: \.self) { zip in
                        Text(zip).font(.caption.weight(.black))
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(MaroowellTheme.yellow.opacity(0.18), in: Capsule())
                    }
                }.padding(14)
            }.background(MaroowellTheme.background)
        }
    }

    private func fit() {
        let coordinates = store.rings.flatMap(\.coordinates)
        guard !coordinates.isEmpty else { return }
        let lats = coordinates.map(\.latitude), lons = coordinates.map(\.longitude)
        guard let a = lats.min(), let b = lats.max(), let c = lons.min(), let d = lons.max() else { return }
        camera = .region(MKCoordinateRegion(
            center: .init(latitude: (a + b) / 2, longitude: (c + d) / 2),
            span: .init(latitudeDelta: max(b - a, 0.01) * 1.25, longitudeDelta: max(d - c, 0.01) * 1.25)
        ))
    }

    private var denied: some View {
        VStack(spacing: 10) { Image(systemName: "lock.fill").font(.largeTitle); Text("마루웰 팀장 권한 이상만 이용할 수 있습니다.").font(.headline.weight(.black)) }
            .foregroundStyle(MaroowellTheme.muted).frame(maxWidth: .infinity, maxHeight: .infinity).background(MaroowellTheme.background)
    }
}

private struct ZipcodeMapRing: Identifiable {
    let id = UUID()
    let zip: String
    let coordinates: [CLLocationCoordinate2D]
}

@MainActor
private final class ZipcodeBoundaryMapStore: ObservableObject {
    @Published var rings: [ZipcodeMapRing] = []
    @Published var loadedZips: [String] = []
    @Published var loading = false
    @Published var status = "지도표시를 누르면 실제 경계를 표시합니다."
    @Published var message: String?

    func clear() { rings = []; loadedZips = []; status = "지도표시를 누르면 실제 경계를 표시합니다." }

    func load(_ zips: [String]) async {
        guard !zips.isEmpty else { message = "5자리 우편번호를 입력하세요."; return }
        loading = true; status = "우편번호 경계 조회 중…"; defer { loading = false }
        var next: [ZipcodeMapRing] = []
        var ok: [String] = []
        var failed = 0
        for zip in zips {
            do {
                let fetched = try await fetch(zip)
                next.append(contentsOf: fetched.map { .init(zip: zip, coordinates: $0) })
                ok.append(zip)
            } catch { failed += 1 }
        }
        rings = next
        loadedZips = ok
        status = failed == 0 ? "\(ok.count)개 우편번호 · 경계 \(next.count)개 표시" : "\(ok.count)개 표시 · \(failed)개 실패"
        if failed > 0 { message = "일부 우편번호 경계를 불러오지 못했습니다." }
    }

    private func fetch(_ zip: String) async throws -> [[CLLocationCoordinate2D]] {
        var c = URLComponents(string: "https://zip.maroowell.com/")!
        c.queryItems = [URLQueryItem(name: "zipcode", value: zip)]
        let (data, response) = try await URLSession.shared.data(from: c.url!)
        guard let h = response as? HTTPURLResponse, (200..<300).contains(h.statusCode) else { throw NSError(domain: "ZipcodeBoundaryMap", code: 1) }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw NSError(domain: "ZipcodeBoundaryMap", code: 2) }
        let raw = root["polygon5179"] ?? root["polygon_5179"] ?? root["polygon"]
        let rings = Self.parseRings(raw).compactMap { points -> [CLLocationCoordinate2D]? in
            let converted = points.compactMap { point in
                if abs(point.0) > 180 || abs(point.1) > 90 { return KoreaTM5179.inverse(x: point.0, y: point.1) }
                return CLLocationCoordinate2D(latitude: point.1, longitude: point.0)
            }
            return converted.count >= 3 ? converted : nil
        }
        guard !rings.isEmpty else { throw NSError(domain: "ZipcodeBoundaryMap", code: 3) }
        return rings
    }

    private static func parseRings(_ value: Any?) -> [[(Double, Double)]] {
        guard let root = value as? [Any], !root.isEmpty else { return [] }
        func number(_ v: Any) -> Double? { if let n = v as? NSNumber { return n.doubleValue }; if let s = v as? String { return Double(s) }; return nil }
        func point(_ v: Any) -> (Double, Double)? { guard let p = v as? [Any], p.count >= 2, let x = number(p[0]), let y = number(p[1]) else { return nil }; return (x, y) }
        func ring(_ v: Any) -> [(Double, Double)]? { guard let a = v as? [Any] else { return nil }; let points = a.compactMap(point); return points.count >= 3 ? points : nil }
        if let one = ring(root) { return [one] }
        var output: [[(Double, Double)]] = []
        for item in root {
            if let direct = ring(item) { output.append(direct); continue }
            if let nested = item as? [Any] { output.append(contentsOf: nested.compactMap(ring)) }
        }
        return output
    }
}

private enum ZipcodeBoundaryInput {
    static func parse(_ value: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: "\\d{5}")
        let range = NSRange(value.startIndex..., in: value)
        var result: [String] = []
        regex?.enumerateMatches(in: value, range: range) { match, _, _ in
            guard let match, let r = Range(match.range, in: value) else { return }
            let zip = String(value[r]); if !result.contains(zip) { result.append(zip) }
        }
        return result
    }
}
