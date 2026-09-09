import Foundation
import SwiftUI
import UIKit

struct FreshbagStatusView: View {
    let session: AppSession
    @StateObject private var store = FreshbagStatusStore()
    @State private var filtersCollapsed = false
    @State private var shareImage: UIImage?
    @State private var sharing = false

    var body: some View {
        Group {
            if session.canView("/coupang_freshbag") { content }
            else { denied }
        }
        .navigationTitle("프백 현황")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if session.canView("/coupang_freshbag") {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        makeImage()
                    } label: { Label("이미지 복사", systemImage: "doc.on.clipboard") }
                    .disabled(store.rows.isEmpty)
                }
            }
        }
        .sheet(isPresented: $sharing, onDismiss: { shareImage = nil }) {
            if let shareImage { FreshbagStatusShareSheet(items: [shareImage]) }
        }
        .alert("프백 현황", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) { Button("확인", role: .cancel) { store.message = nil } } message: {
            Text(store.message ?? "")
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text("조회 조건").font(.headline.weight(.black))
                        Spacer()
                        Button(filtersCollapsed ? "펼치기" : "접기") { filtersCollapsed.toggle() }
                            .buttonStyle(.bordered)
                    }
                    if !filtersCollapsed {
                        HStack(spacing: 8) {
                            field("연도") {
                                Picker("연도", selection: $store.year) {
                                    ForEach(store.years, id: \.self) { Text("\($0)년").tag($0) }
                                }.pickerStyle(.menu)
                            }
                            field("주간/야간") {
                                Picker("주간/야간", selection: $store.wave) {
                                    Text("주간").tag("W2")
                                    Text("야간").tag("W1")
                                }.pickerStyle(.menu)
                            }
                        }
                        HStack(spacing: 8) {
                            textField("Camp", hint: "예: 일산2 / M익산1", text: $store.camp)
                            textField("Route", hint: "예: 126A, 126B", text: $store.routeText)
                        }
                        HStack(spacing: 8) {
                            Button { Task { await store.load(); if !store.rows.isEmpty { filtersCollapsed = true } } } label: {
                                HStack { if store.loading { ProgressView().tint(.white) }; Text(store.loading ? "조회 중…" : "조회") }
                                    .frame(maxWidth: .infinity).frame(height: 42)
                            }.buttonStyle(.borderedProminent).disabled(store.loading)
                            Button { store.clear() } label: { Text("초기화").frame(maxWidth: .infinity).frame(height: 42) }
                                .buttonStyle(.bordered).disabled(store.loading)
                        }
                        HStack {
                            Text("표시 월").font(.caption.weight(.bold)).foregroundStyle(MaroowellTheme.muted)
                            Spacer()
                            Button("전체 보기") { store.hiddenMonths.removeAll(); store.saveHiddenMonths() }
                                .font(.caption.weight(.bold))
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                            ForEach(1...12, id: \.self) { month in
                                Button("\(month)월") { store.toggleMonth(month) }
                                    .font(.caption2.weight(.black))
                                    .buttonStyle(.bordered)
                                    .tint(store.hiddenMonths.contains(month) ? .gray : .blue)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(MaroowellTheme.border) }

                HStack(spacing: 8) {
                    if store.loading { ProgressView().controlSize(.small) }
                    Text(store.status).font(.caption.weight(.semibold)).foregroundStyle(MaroowellTheme.muted)
                    Spacer()
                }.padding(.horizontal, 4)

                if store.rows.isEmpty && !store.loading {
                    empty("Camp와 주간/야간을 선택한 뒤 조회하세요. Route는 비우면 Camp 전체를 조회합니다.")
                } else {
                    Text("\(store.year) · \(store.displayCamp) · \(FreshbagStatusFormat.waveLabel(store.wave)) · \(store.visibleMonths.count)개월 표시")
                        .font(.caption.weight(.bold)).foregroundStyle(MaroowellTheme.muted)
                    ForEach(store.rows) { row in routeCard(row) }
                }
            }
            .padding(15)
        }.background(MaroowellTheme.background)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(MaroowellTheme.muted)
            content().frame(maxWidth: .infinity, alignment: .leading).frame(height: 42)
                .padding(.horizontal, 7).background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 10))
        }.frame(maxWidth: .infinity)
    }

    private func textField(_ label: String, hint: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(MaroowellTheme.muted)
            TextField(hint, text: text).textInputAutocapitalization(.characters).autocorrectionDisabled()
                .font(.caption.weight(.semibold)).padding(.horizontal, 9).frame(height: 42)
                .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 10))
        }.frame(maxWidth: .infinity)
    }

    private func routeCard(_ row: FreshbagStatusRoute) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row.route).font(.headline.weight(.black)).foregroundStyle(.blue)
                Spacer()
                Text("\(row.camp) · \(FreshbagStatusFormat.waveLabel(row.wave))")
                    .font(.caption2).foregroundStyle(MaroowellTheme.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(store.visibleMonths, id: \.self) { month in
                        let value = row.months[month] ?? .empty
                        VStack(spacing: 4) {
                            Text("\(month)월").font(.caption.weight(.black))
                            pill("가중1", value.g1)
                            pill("가중2", value.g2)
                        }.padding(6).frame(width: 78)
                            .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(13).background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(MaroowellTheme.border) }
    }

    private func pill(_ label: String, _ value: String) -> some View {
        Text("\(label) \(value.isEmpty ? "-" : value)")
            .font(.system(size: 9, weight: .black)).frame(maxWidth: .infinity).frame(height: 24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(MaroowellTheme.muted)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 30)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private var denied: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.system(size: 38)).foregroundStyle(MaroowellTheme.muted)
            Text("마루웰 팀장 권한 이상만 이용할 수 있습니다.").font(.headline.weight(.black))
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(MaroowellTheme.background)
    }

    @MainActor private func makeImage() {
        let report = FreshbagStatusReport(year: store.year, camp: store.displayCamp, wave: store.wave, months: store.visibleMonths, rows: store.rows)
            .frame(width: 900).fixedSize(horizontal: false, vertical: true)
        let renderer = ImageRenderer(content: report); renderer.scale = 1
        guard let image = renderer.uiImage else { store.message = "프백 현황 이미지를 만들지 못했습니다."; return }
        UIPasteboard.general.image = image
        shareImage = image; sharing = true
    }
}

@MainActor private final class FreshbagStatusStore: ObservableObject {
    @Published var year: Int
    @Published var wave = "W2"
    @Published var camp = ""
    @Published var routeText = ""
    @Published var rows: [FreshbagStatusRoute] = []
    @Published var loading = false
    @Published var status = "Camp와 주간/야간을 선택한 뒤 조회하세요."
    @Published var hiddenMonths: Set<Int>
    @Published var message: String?
    private let api = FreshbagStatusAPI()
    private static let hiddenKey = "freshbag_status_hidden_months"

    init() {
        let current = Calendar.current.component(.year, from: Date())
        year = current
        hiddenMonths = Set(UserDefaults.standard.array(forKey: Self.hiddenKey) as? [Int] ?? [])
    }
    var years: [Int] { let c = Calendar.current.component(.year, from: Date()); return Array(stride(from: c + 1, through: c - 6, by: -1)) }
    var visibleMonths: [Int] { (1...12).filter { !hiddenMonths.contains($0) } }
    var displayCamp: String { FreshbagStatusFormat.displayCamp(camp) }

    func load() async {
        let display = displayCamp
        guard !display.isEmpty else { message = "Camp를 입력하세요."; return }
        loading = true; rows = []; status = "프백 현황 조회 중…"; defer { loading = false }
        do {
            rows = try await api.query(year: year, displayCamp: display, wave: wave, routes: FreshbagStatusFormat.routes(routeText))
            status = "조회 완료 · \(rows.count)개 라우트"
        } catch { status = "조회 실패"; message = error.localizedDescription }
    }
    func clear() { camp = ""; routeText = ""; rows = []; status = "조회 조건을 초기화했습니다." }
    func toggleMonth(_ month: Int) { if hiddenMonths.contains(month) { hiddenMonths.remove(month) } else { hiddenMonths.insert(month) }; saveHiddenMonths() }
    func saveHiddenMonths() { UserDefaults.standard.set(Array(hiddenMonths).sorted(), forKey: Self.hiddenKey) }
}

private struct FreshbagStatusRoute: Identifiable, Hashable {
    let route: String; let camp: String; let wave: String; var months: [Int: FreshbagStatusMonth]
    var id: String { "\(wave)|\(camp)|\(route)" }
}
private struct FreshbagStatusMonth: Hashable { let g1: String; let g2: String; static let empty = Self(g1: "", g2: "") }

private struct FreshbagStatusAPI {
    private let client = SupabaseService.shared.client
    private static let endpoint = URL(string: "https://freshbag.brain-0f6.workers.dev/freshbag/query")!
    func query(year: Int, displayCamp: String, wave: String, routes: [String]) async throws -> [FreshbagStatusRoute] {
        let auth = try await client.auth.session
        let campDB = FreshbagStatusFormat.dbCamp(displayCamp)
        let criteria: [[String: Any]] = routes.isEmpty
            ? [["wave": wave, "camp": campDB, "displayCamp": displayCamp, "route": "", "allRoutes": true]]
            : routes.map { ["wave": wave, "camp": campDB, "displayCamp": displayCamp, "route": $0, "allRoutes": false] }
        var request = URLRequest(url: Self.endpoint); request.httpMethod = "POST"; request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["year": year, "criteria": criteria])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw NSError(domain: "FreshbagStatus", code: 1, userInfo: [NSLocalizedDescriptionKey: "프백 현황 조회에 실패했습니다."]) }
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let source = root?["rows"] as? [[String: Any]] ?? []
        var map: [String: FreshbagStatusRoute] = [:]
        for item in source {
            let rawRoute = FreshbagStatusFormat.text(item["route_norm"]).isEmpty ? FreshbagStatusFormat.text(item["route"]) : FreshbagStatusFormat.text(item["route_norm"])
            let route = FreshbagStatusFormat.route(rawRoute); if route.isEmpty { continue }
            var target = map[route] ?? FreshbagStatusRoute(route: route, camp: FreshbagStatusFormat.displayCamp(FreshbagStatusFormat.text(item["camp"]).isEmpty ? campDB : FreshbagStatusFormat.text(item["camp"])), wave: FreshbagStatusFormat.text(item["wave"]).isEmpty ? wave : FreshbagStatusFormat.text(item["wave"]), months: [:])
            let month = Int(FreshbagStatusFormat.text(item["month_no"])) ?? 0
            if (1...12).contains(month) { target.months[month] = .init(g1: FreshbagStatusFormat.value(item["gajoong1"]), g2: FreshbagStatusFormat.value(item["gajoong2"])) }
            map[route] = target
        }
        return map.values.sorted { FreshbagStatusFormat.leading($0.route) == FreshbagStatusFormat.leading($1.route) ? $0.route < $1.route : FreshbagStatusFormat.leading($0.route) < FreshbagStatusFormat.leading($1.route) }
    }
}

private enum FreshbagStatusFormat {
    static func text(_ value: Any?) -> String { if let s = value as? String { return s.trimmingCharacters(in: .whitespacesAndNewlines) }; if let n = value as? NSNumber { return n.stringValue }; return "" }
    static func displayCamp(_ value: String) -> String { let v = value.trimmingCharacters(in: .whitespacesAndNewlines); return v.uppercased().hasPrefix("M_") ? "M" + v.dropFirst(2) : v.replacingOccurrences(of: " ", with: "") }
    static func dbCamp(_ value: String) -> String { let v = displayCamp(value); return v.hasPrefix("M") && !v.hasPrefix("M_") ? "M_" + v.dropFirst() : v }
    static func route(_ value: String) -> String { value.uppercased().replacingOccurrences(of: "[^0-9A-Z가-힣]", with: "", options: .regularExpression) }
    static func routes(_ value: String) -> [String] { Array(Set(value.components(separatedBy: CharacterSet(charactersIn: ",/ \t\n")).map(route).filter { !$0.isEmpty })).sorted() }
    static func waveLabel(_ value: String) -> String { value.uppercased() == "W1" ? "야간" : "주간" }
    static func value(_ value: Any?) -> String { let t = text(value); guard !t.isEmpty else { return "" }; if t.contains("%") { return t }; if let d = Double(t) { return String(format: "%.2f%%", d) }; return t }
    static func leading(_ value: String) -> Int { Int(value.prefix { $0.isNumber }) ?? Int.max }
}

private struct FreshbagStatusReport: View {
    let year: Int; let camp: String; let wave: String; let months: [Int]; let rows: [FreshbagStatusRoute]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("프레시백 현황 조회").font(.system(size: 28, weight: .black))
            Text("\(year) / \(camp) / \(FreshbagStatusFormat.waveLabel(wave))").font(.headline).foregroundStyle(.secondary)
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(row.camp) · \(row.route) · \(FreshbagStatusFormat.waveLabel(row.wave))").font(.headline.weight(.black))
                    HStack(spacing: 4) {
                        ForEach(months, id: \.self) { m in
                            let v = row.months[m] ?? .empty
                            VStack(spacing: 3) { Text("\(m)월").font(.caption.weight(.black)); Text("1 \(v.g1.isEmpty ? "-" : v.g1)").font(.caption2); Text("2 \(v.g2.isEmpty ? "-" : v.g2)").font(.caption2) }
                                .frame(maxWidth: .infinity).padding(6).background(Color.white, in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }.padding(10).background(Color(red: 0.96, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 10))
            }
        }.padding(16).background(Color.white)
    }
}

private struct FreshbagStatusShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
