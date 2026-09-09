import Foundation
import MapKit
import SwiftUI

struct RouteEditorMapWorkspace: View {
    let session: AppSession
    @StateObject private var store = RouteMapWorkspaceStore()
    @State private var draftPoints: [CLLocationCoordinate2D] = []
    @State private var drawing = false
    @State private var creatingNew = false

    var body: some View {
        Group {
            if session.canView("/coupangRouteMap.html") { content }
            else { denied }
        }
        .navigationTitle("라우트 구역 편집")
        .navigationBarTitleDisplayMode(.inline)
        .alert("라우트 편집기", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    private var content: some View {
        VStack(spacing: 0) {
            RouteEditorMapCanvas(
                draftPoints: $draftPoints,
                polygons: store.rows.flatMap(\.polygons),
                drawingEnabled: drawing,
                fitContent: !drawing
            )
            .frame(minHeight: 300)
            .overlay(alignment: .topLeading) {
                Text(drawing ? "지도 탭 → 꼭짓점 추가" : "저장된 라우트 구역")
                    .font(.caption.weight(.black))
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule()).padding(9)
            }

            ScrollView {
                VStack(spacing: 11) {
                    HStack(spacing: 8) {
                        TextField("캠프", text: $store.camp).textFieldStyle(.roundedBorder)
                        TextField("라우트", text: $store.code).textFieldStyle(.roundedBorder)
                        Button("조회") { Task { await store.load(); resetDrawing() } }
                            .buttonStyle(.borderedProminent).disabled(store.loading)
                    }

                    if !store.rows.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(store.rows) { row in
                                    Button(row.code) {
                                        store.selectedID = row.id
                                        store.camp = row.camp
                                        store.code = row.code
                                        resetDrawing()
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(store.selectedID == row.id ? MaroowellTheme.deepYellow : nil)
                                }
                            }
                        }
                    }

                    HStack(spacing: 7) {
                        Button("새로 그리기") {
                            creatingNew = true; drawing = true; draftPoints = []
                        }.buttonStyle(.bordered)
                        Button("구역 추가") {
                            guard store.selected != nil else { store.message = "구역을 추가할 라우트를 먼저 선택하세요."; return }
                            creatingNew = false; drawing = true; draftPoints = []
                        }.buttonStyle(.bordered)
                        Button("되돌리기") { if !draftPoints.isEmpty { draftPoints.removeLast() } }
                            .buttonStyle(.bordered).disabled(draftPoints.isEmpty)
                        Button("취소") { resetDrawing() }.buttonStyle(.bordered).disabled(!drawing)
                    }

                    Button {
                        Task {
                            await store.save(draftPoints: draftPoints, creatingNew: creatingNew)
                            if store.lastSaveSucceeded { resetDrawing() }
                        }
                    } label: {
                        Label("라우트 구역 저장", systemImage: "square.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!drawing || draftPoints.count < 3 || store.loading)

                    HStack {
                        if store.loading { ProgressView().controlSize(.small) }
                        Text(drawing ? "꼭짓점 \(draftPoints.count)개" : "라우트 \(store.rows.count)개")
                            .font(.caption.weight(.semibold)).foregroundStyle(MaroowellTheme.muted)
                        Spacer()
                    }
                }
                .padding(12)
            }
            .background(MaroowellTheme.background)
        }
    }

    private func resetDrawing() { drawing = false; creatingNew = false; draftPoints = [] }

    private var denied: some View {
        VStack(spacing: 10) { Image(systemName: "lock.fill").font(.largeTitle); Text("라우트 편집기 권한이 필요합니다.").font(.headline.weight(.black)) }
            .foregroundStyle(MaroowellTheme.muted).frame(maxWidth: .infinity, maxHeight: .infinity).background(MaroowellTheme.background)
    }
}

private struct RouteMapWorkspaceRow: Identifiable {
    let id: String
    let idValue: AnyHashable?
    let camp: String
    let code: String
    let polygons: [[CLLocationCoordinate2D]]
}

@MainActor
private final class RouteMapWorkspaceStore: ObservableObject {
    @Published var camp = ""
    @Published var code = ""
    @Published var rows: [RouteMapWorkspaceRow] = []
    @Published var selectedID: String?
    @Published var loading = false
    @Published var message: String?
    var lastSaveSucceeded = false
    private let base = URL(string: "https://route.maroowell.com")!

    var selected: RouteMapWorkspaceRow? { rows.first { $0.id == selectedID } }

    func load() async {
        let campValue = camp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !campValue.isEmpty else { message = "캠프를 입력하세요."; return }
        loading = true; defer { loading = false }
        do {
            var c = URLComponents(url: base.appendingPathComponent("route"), resolvingAgainstBaseURL: false)!
            var q = [URLQueryItem(name: "camp", value: campValue), URLQueryItem(name: "mode", value: "prefix")]
            let routeValue = code.trimmingCharacters(in: .whitespacesAndNewlines)
            if !routeValue.isEmpty { q.append(.init(name: "code", value: routeValue)) }
            c.queryItems = q
            let root = try await request(url: c.url!, method: "GET")
            let source = root["rows"] as? [[String: Any]] ?? []
            rows = source.map(Self.row).sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
            if let selectedID, !rows.contains(where: { $0.id == selectedID }) { self.selectedID = nil }
            if rows.isEmpty { message = "조회된 라우트가 없습니다." }
        } catch { rows = []; selectedID = nil; message = error.localizedDescription }
    }

    func save(draftPoints: [CLLocationCoordinate2D], creatingNew: Bool) async {
        lastSaveSucceeded = false
        guard draftPoints.count >= 3 else { message = "꼭짓점을 3개 이상 지정하세요."; return }
        let campValue = camp.trimmingCharacters(in: .whitespacesAndNewlines)
        let codeValue = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !campValue.isEmpty, !codeValue.isEmpty else { message = "캠프와 라우트를 입력하세요."; return }
        if !creatingNew, selected == nil { message = "구역을 추가할 라우트를 선택하세요."; return }
        loading = true; defer { loading = false }
        do {
            var polygons = creatingNew ? [] : (selected?.polygons ?? [])
            polygons.append(draftPoints)
            var body: [String: Any] = [
                "camp": campValue,
                "code": codeValue,
                "polygon_wgs84": polygons.map { ring in ring.map { [$0.longitude, $0.latitude] } }
            ]
            if let id = selected?.idValue { body["id"] = id.base }
            _ = try await request(url: base.appendingPathComponent("route"), method: "POST", body: body)
            lastSaveSucceeded = true
            message = "라우트 저장 완료"
            await load()
        } catch { message = error.localizedDescription }
    }

    private func request(url: URL, method: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        var r = URLRequest(url: url); r.httpMethod = method; r.timeoutInterval = 35
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let h = response as? HTTPURLResponse, (200..<300).contains(h.statusCode) else {
            throw NSError(domain: "RouteEditorMap", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "라우트 요청 실패"])
        }
        if data.isEmpty { return [:] }
        let root = try JSONSerialization.jsonObject(with: data)
        if let o = root as? [String: Any] { return o }
        if let a = root as? [[String: Any]] { return ["rows": a] }
        return [:]
    }

    private static func row(_ o: [String: Any]) -> RouteMapWorkspaceRow {
        let camp = text(o["camp"])
        let code = ["full_code", "code", "route_code"].map { text(o[$0]) }.first { !$0.isEmpty } ?? ""
        let idValue = o["id"] as? AnyHashable
        return .init(id: idValue.map(String.init(describing:)) ?? "\(camp)|\(code)", idValue: idValue, camp: camp, code: code, polygons: polygons(o["polygon_wgs84"]))
    }

    private static func polygons(_ value: Any?) -> [[CLLocationCoordinate2D]] {
        let raw: Any?
        if let s = value as? String, let d = s.data(using: .utf8) { raw = try? JSONSerialization.jsonObject(with: d) }
        else { raw = value }
        guard let a = raw as? [Any], !a.isEmpty else { return [] }
        func point(_ v: Any) -> CLLocationCoordinate2D? {
            guard let p = v as? [Any], p.count >= 2, let lon = number(p[0]), let lat = number(p[1]) else { return nil }
            return .init(latitude: lat, longitude: lon)
        }
        func ring(_ v: Any) -> [CLLocationCoordinate2D]? {
            guard let p = v as? [Any] else { return nil }; let pts = p.compactMap(point); return pts.count >= 3 ? pts : nil
        }
        if let r = ring(a) { return [r] }
        return a.compactMap(ring)
    }

    private static func text(_ v: Any?) -> String { if let s = v as? String { return s.trimmingCharacters(in: .whitespacesAndNewlines) }; if let n = v as? NSNumber { return n.stringValue }; return "" }
    private static func number(_ v: Any?) -> Double? { if let n = v as? NSNumber { return n.doubleValue }; if let s = v as? String { return Double(s) }; return nil }
}
