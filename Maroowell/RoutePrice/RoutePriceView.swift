import Foundation
import SwiftUI

struct RoutePriceView: View {
    let session: AppSession
    @StateObject private var store = RoutePriceStore()
    @State private var search = ""
    @State private var editing: RoutePriceRow?
    @State private var adding = false

    private var canEdit: Bool { session.isSuperAdmin }
    private var filtered: [RoutePriceRow] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.rows }
        return store.rows.filter { [$0.camp, $0.route, $0.address, $0.wave].joined(separator: " ").lowercased().contains(q) }
    }

    var body: some View {
        Group {
            if session.canView("/maroowell_route") { content }
            else { denied }
        }
        .navigationTitle("마루웰 라우트 단가")
        .navigationBarTitleDisplayMode(.inline)
        .task { if store.rows.isEmpty { await store.load() } }
        .sheet(item: $editing) { row in RoutePriceEditor(store: store, row: row, isNew: false) }
        .sheet(isPresented: $adding) { RoutePriceEditor(store: store, row: .empty, isNew: true) }
        .alert("라우트 단가", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if store.loading { ProgressView().frame(maxWidth: .infinity).padding(.vertical, 6) }
            HStack(spacing: 8) {
                TextField("캠프 / 라우트 / 주소 검색", text: $search)
                    .textFieldStyle(.roundedBorder)
                if canEdit {
                    Button("+ 추가") { adding = true }.buttonStyle(.borderedProminent)
                }
            }.padding(12).background(Color.white)
            Text("\(filtered.count)개 라우트 · 원청단가는 DB 원본 기준")
                .font(.caption).foregroundStyle(MaroowellTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.bottom, 8).background(Color.white)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if filtered.isEmpty && !store.loading {
                        Text("조회 결과가 없습니다.").foregroundStyle(MaroowellTheme.muted).padding(.vertical, 42)
                    }
                    ForEach(filtered) { row in
                        Button { if canEdit { editing = row } } label: { card(row) }.buttonStyle(.plain).disabled(!canEdit)
                    }
                }.padding(12)
            }.background(MaroowellTheme.background)
        }
    }

    private func card(_ row: RoutePriceRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(row.displayCamp) - \(row.route)").font(.headline.weight(.black)).foregroundStyle(MaroowellTheme.ink)
            if ![row.wave, row.contractDate].filter({ !$0.isEmpty }).isEmpty {
                Text([row.wave, row.contractDate].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(MaroowellTheme.muted)
            }
            if !row.address.isEmpty { Text(row.address).font(.caption).foregroundStyle(MaroowellTheme.muted) }
            HStack(spacing: 7) { priceBox("고정", row.fixedPrice); priceBox("백업", row.backupPrice) }
            HStack(spacing: 7) { priceBox("26년 원청", row.origin26); priceBox("25년 원청", row.origin25) }
            if row.origin24 != nil { priceBox("24년 원청", row.origin24) }
            if !row.routeTip.isEmpty { Text("라우트 정보  \(row.routeTip)").font(.caption).foregroundStyle(MaroowellTheme.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(MaroowellTheme.border) }
    }

    private func priceBox(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(MaroowellTheme.muted)
            Text(RoutePriceFormat.won(value)).font(.subheadline.weight(.black)).foregroundStyle(MaroowellTheme.ink)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 10))
    }

    private var denied: some View {
        VStack(spacing: 10) { Image(systemName: "lock.fill").font(.largeTitle); Text("마루웰 관리자 권한이 필요합니다.").font(.headline.weight(.black)) }
            .foregroundStyle(MaroowellTheme.muted).frame(maxWidth: .infinity, maxHeight: .infinity).background(MaroowellTheme.background)
    }
}

@MainActor private final class RoutePriceStore: ObservableObject {
    @Published var rows: [RoutePriceRow] = []
    @Published var loading = false
    @Published var message: String?
    private let api = RoutePriceAPI()

    func load() async {
        loading = true; defer { loading = false }
        do { rows = try await api.load() } catch { message = error.localizedDescription }
    }
    func save(_ row: RoutePriceRow, isNew: Bool) async -> Bool {
        loading = true; defer { loading = false }
        do { try await api.save(row, isNew: isNew); await load(); return true }
        catch { message = error.localizedDescription; return false }
    }
    func delete(_ row: RoutePriceRow) async -> Bool {
        loading = true; defer { loading = false }
        do { try await api.delete(row.seq); await load(); return true }
        catch { message = error.localizedDescription; return false }
    }
}

private struct RoutePriceEditor: View {
    @ObservedObject var store: RoutePriceStore
    let row: RoutePriceRow
    let isNew: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RoutePriceDraft
    @State private var confirmDelete = false

    init(store: RoutePriceStore, row: RoutePriceRow, isNew: Bool) {
        self.store = store; self.row = row; self.isNew = isNew; _draft = State(initialValue: RoutePriceDraft(row))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("기본정보") {
                    TextField("캠프", text: $draft.camp); TextField("라우트", text: $draft.route); TextField("주/야", text: $draft.wave)
                    TextField("계약일자", text: $draft.contractDate); TextField("주소", text: $draft.address, axis: .vertical)
                }
                Section("단가") {
                    TextField("고정 단가", text: $draft.fixed).keyboardType(.decimalPad)
                    TextField("백업 단가", text: $draft.backup).keyboardType(.decimalPad)
                    TextField("26년 원청", text: $draft.o26).keyboardType(.decimalPad)
                    TextField("25년 원청", text: $draft.o25).keyboardType(.decimalPad)
                    TextField("24년 원청", text: $draft.o24).keyboardType(.decimalPad)
                    TextField("라우트 정보", text: $draft.tip, axis: .vertical)
                }
                if !isNew { Section { Button("삭제", role: .destructive) { confirmDelete = true } } }
            }
            .navigationTitle(isNew ? "라우트 단가 추가" : "라우트 단가 수정").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        guard !draft.camp.trimmingCharacters(in: .whitespaces).isEmpty, !draft.route.trimmingCharacters(in: .whitespaces).isEmpty else { store.message = "캠프와 라우트를 입력해주세요."; return }
                        Task { if await store.save(draft.row(seq: row.seq), isNew: isNew) { dismiss() } }
                    }.disabled(store.loading)
                }
            }
            .confirmationDialog("이 라우트 단가를 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { Task { if await store.delete(row) { dismiss() } } }
            }
        }
    }
}

private struct RoutePriceDraft {
    var camp: String; var route: String; var wave: String; var contractDate: String; var address: String
    var fixed: String; var backup: String; var o26: String; var o25: String; var o24: String; var tip: String
    init(_ row: RoutePriceRow) {
        camp=row.camp; route=row.route; wave=row.wave; contractDate=row.contractDate; address=row.address
        fixed=RoutePriceFormat.raw(row.fixedPrice); backup=RoutePriceFormat.raw(row.backupPrice); o26=RoutePriceFormat.raw(row.origin26); o25=RoutePriceFormat.raw(row.origin25); o24=RoutePriceFormat.raw(row.origin24); tip=row.routeTip
    }
    func row(seq: Int64) -> RoutePriceRow { .init(seq: seq, camp: camp, route: route, wave: wave, contractDate: contractDate, address: address, fixedPrice: RoutePriceFormat.number(fixed), backupPrice: RoutePriceFormat.number(backup), origin26: RoutePriceFormat.number(o26), origin25: RoutePriceFormat.number(o25), origin24: RoutePriceFormat.number(o24), routeTip: tip) }
}

private struct RoutePriceRow: Identifiable, Hashable {
    let seq: Int64; let camp, route, wave, contractDate, address: String
    let fixedPrice, backupPrice, origin26, origin25, origin24: Double?
    let routeTip: String
    var id: Int64 { seq }
    var displayCamp: String { camp.hasPrefix("M_") ? "M" + camp.dropFirst(2) : camp }
    static let empty = Self(seq: 0, camp: "", route: "", wave: "", contractDate: "", address: "", fixedPrice: nil, backupPrice: nil, origin26: nil, origin25: nil, origin24: nil, routeTip: "")
}

private struct RoutePriceAPI {
    private let client = SupabaseService.shared.client
    private var base: URL { AppConfig.supabaseURL.appendingPathComponent("rest/v1/maroowell_route") }
    func load() async throws -> [RoutePriceRow] {
        var c = URLComponents(url: base, resolvingAgainstBaseURL: false)!; c.query = "select=seq,camp,route,wave,contract_date,address,fixed_price,backup_price,26y_orgin_price,25y_orgin_price,24y_orgin_price,route_tip&order=camp.asc,route.asc,seq.asc"
        let data = try await request(c.url!, method: "GET")
        return try parse(data)
    }
    func save(_ row: RoutePriceRow, isNew: Bool) async throws {
        var url = base
        if !isNew { var c = URLComponents(url: base, resolvingAgainstBaseURL: false)!; c.query = "seq=eq.\(row.seq)"; url = c.url! }
        let body: [String: Any] = ["camp": nullable(row.camp), "route": nullable(row.route), "wave": nullable(row.wave), "contract_date": nullable(row.contractDate), "address": nullable(row.address), "fixed_price": row.fixedPrice ?? NSNull(), "backup_price": row.backupPrice ?? NSNull(), "26y_orgin_price": row.origin26 ?? NSNull(), "25y_orgin_price": row.origin25 ?? NSNull(), "24y_orgin_price": row.origin24 ?? NSNull(), "route_tip": nullable(row.routeTip)]
        _ = try await request(url, method: isNew ? "POST" : "PATCH", body: body, prefer: "return=minimal")
    }
    func delete(_ seq: Int64) async throws {
        var c = URLComponents(url: base, resolvingAgainstBaseURL: false)!; c.query = "seq=eq.\(seq)"; _ = try await request(c.url!, method: "DELETE")
    }
    private func request(_ url: URL, method: String, body: [String: Any]? = nil, prefer: String? = nil) async throws -> Data {
        let auth = try await client.auth.session
        var r = URLRequest(url: url); r.httpMethod = method; r.timeoutInterval = 30
        r.setValue("application/json", forHTTPHeaderField: "Accept"); r.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey"); r.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        if let prefer { r.setValue(prefer, forHTTPHeaderField: "Prefer") }; if let body { r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: r); guard let h = response as? HTTPURLResponse, (200..<300).contains(h.statusCode) else { throw NSError(domain: "RoutePrice", code: 1, userInfo: [NSLocalizedDescriptionKey: "라우트 단가 요청에 실패했습니다."]) }; return data
    }
    private func parse(_ data: Data) throws -> [RoutePriceRow] {
        let a = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return a.map { o in .init(seq: int(o["seq"]), camp: text(o["camp"]), route: text(o["route"]), wave: text(o["wave"]), contractDate: text(o["contract_date"]), address: text(o["address"]), fixedPrice: num(o["fixed_price"]), backupPrice: num(o["backup_price"]), origin26: num(o["26y_orgin_price"]), origin25: num(o["25y_orgin_price"]), origin24: num(o["24y_orgin_price"]), routeTip: text(o["route_tip"])) }
    }
    private func text(_ v: Any?) -> String { if let s=v as? String{return s}; if let n=v as? NSNumber{return n.stringValue}; return "" }
    private func num(_ v: Any?) -> Double? { if let n=v as? NSNumber{return n.doubleValue}; if let s=v as? String{return Double(s)}; return nil }
    private func int(_ v: Any?) -> Int64 { if let n=v as? NSNumber{return n.int64Value}; return Int64(text(v)) ?? 0 }
    private func nullable(_ v: String) -> Any { v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSNull() : v.trimmingCharacters(in: .whitespacesAndNewlines) }
}

private enum RoutePriceFormat {
    static func won(_ value: Double?) -> String { guard let value else { return "-" }; return NumberFormatter.krw.string(from: NSNumber(value: Int64(value))) ?? "\(Int64(value))원" }
    static func raw(_ value: Double?) -> String { value.map { String(Int64($0)) } ?? "" }
    static func number(_ value: String) -> Double? { Double(value.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "원", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) }
}
private extension NumberFormatter {
    static let krw: NumberFormatter = { let f=NumberFormatter(); f.numberStyle = .decimal; f.positiveSuffix = "원"; return f }()
}
