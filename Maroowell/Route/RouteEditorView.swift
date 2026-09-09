import Foundation
import SwiftUI

struct RouteEditorView: View {
    let session: AppSession
    @StateObject private var store = RouteEditorStore()
    @State private var deleteTarget: RouteEditorRow?

    var body: some View {
        Group {
            if session.canView("/coupangRouteMap.html") {
                content
            } else {
                denied
            }
        }
        .navigationTitle("라우트 편집기")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("라우트 삭제", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { row in
            Button("삭제", role: .destructive) {
                Task {
                    await store.delete(row)
                    deleteTarget = nil
                }
            }
            Button("취소", role: .cancel) { deleteTarget = nil }
        } message: { row in
            Text("\(row.camp) · \(row.code) 라우트를 삭제합니다.")
        }
        .alert("라우트 편집기", isPresented: Binding(
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
            VStack(spacing: 14) {
                searchCard

                if store.loading && store.rows.isEmpty {
                    ProgressView("라우트를 불러오는 중...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 42)
                } else if store.rows.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(store.rows) { row in
                            RouteEditorRowCard(
                                row: row,
                                selected: row.id == store.selected?.id,
                                onSelect: { Task { await store.select(row) } },
                                onShare: { Task { await store.makeShareLink(row) } },
                                onDelete: { deleteTarget = row }
                            )
                        }
                    }
                }

                if let selected = store.selected {
                    selectedCard(selected)
                }
            }
            .padding(16)
        }
        .background(MaroowellTheme.background)
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("캠프와 라우트 조회")
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
            Text("Android 라우트 편집기의 route.maroowell.com API를 그대로 사용합니다.")
                .font(.caption)
                .foregroundStyle(MaroowellTheme.muted)

            HStack(spacing: 8) {
                TextField("캠프 (예: 대구3)", text: $store.camp)
                    .textFieldStyle(.roundedBorder)
                TextField("라우트 (예: 405A01)", text: $store.code)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                Task { await store.load() }
            } label: {
                Label("불러오기", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.loading || store.camp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(MaroowellTheme.border) }
    }

    private func selectedCard(_ row: RouteEditorRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("선택한 라우트")
                    .font(.headline.weight(.black))
                Spacer()
                Text(row.code)
                    .font(.caption.weight(.black))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(MaroowellTheme.yellow.opacity(0.18), in: Capsule())
            }

            detail("캠프", row.camp)
            detail("2W 주간 벤더", row.vendorDay)
            detail("1W 야간 벤더", row.vendorNight)
            detail("입차지", row.deliveryName)
            detail("입차지 주소", row.deliveryAddress)

            if store.addressesLoading {
                ProgressView("라우트 주소 불러오는 중...")
                    .controlSize(.small)
            } else if !store.addresses.isEmpty {
                Divider()
                Text("라우트 주소")
                    .font(.caption.weight(.black))
                    .foregroundStyle(MaroowellTheme.muted)
                ForEach(Array(store.addresses.enumerated()), id: \.offset) { index, address in
                    Text("\(index + 1). \(address)")
                        .font(.caption)
                        .foregroundStyle(MaroowellTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(MaroowellTheme.border) }
    }

    @ViewBuilder
    private func detail(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MaroowellTheme.muted)
                    .frame(width: 92, alignment: .leading)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(MaroowellTheme.ink)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(MaroowellTheme.muted)
            Text("캠프를 입력하고 라우트를 불러오세요.")
                .font(.headline.weight(.black))
                .foregroundStyle(MaroowellTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private var denied: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill").font(.largeTitle)
            Text("라우트 편집기 권한이 필요합니다.").font(.headline.weight(.black))
        }
        .foregroundStyle(MaroowellTheme.muted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaroowellTheme.background)
    }
}

private struct RouteEditorRowCard: View {
    let row: RouteEditorRow
    let selected: Bool
    let onSelect: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.code)
                            .font(.headline.weight(.black))
                            .foregroundStyle(MaroowellTheme.ink)
                        Text(row.camp)
                            .font(.caption)
                            .foregroundStyle(MaroowellTheme.muted)
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                        .foregroundStyle(selected ? MaroowellTheme.deepYellow : MaroowellTheme.muted)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button("공유 링크", action: onShare)
                    .buttonStyle(.bordered)
                Button("삭제", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(selected ? MaroowellTheme.deepYellow.opacity(0.5) : MaroowellTheme.border, lineWidth: 1)
        }
    }
}

private struct RouteEditorRow: Identifiable, Hashable {
    let id: String
    let idValue: AnyHashable?
    let camp: String
    let code: String
    let vendorDay: String
    let vendorNight: String
    let deliveryName: String
    let deliveryAddress: String
}

@MainActor
private final class RouteEditorStore: ObservableObject {
    @Published var camp = ""
    @Published var code = ""
    @Published var rows: [RouteEditorRow] = []
    @Published var selected: RouteEditorRow?
    @Published var addresses: [String] = []
    @Published var loading = false
    @Published var addressesLoading = false
    @Published var message: String?

    private let base = URL(string: "https://route.maroowell.com")!

    func load() async {
        guard !loading else { return }
        let campQuery = camp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !campQuery.isEmpty else {
            message = "캠프를 입력하세요."
            return
        }
        loading = true
        defer { loading = false }
        do {
            var components = URLComponents(url: base.appendingPathComponent("route"), resolvingAgainstBaseURL: false)!
            var items = [
                URLQueryItem(name: "camp", value: campQuery),
                URLQueryItem(name: "mode", value: "prefix")
            ]
            let codeQuery = code.trimmingCharacters(in: .whitespacesAndNewlines)
            if !codeQuery.isEmpty { items.append(URLQueryItem(name: "code", value: codeQuery)) }
            components.queryItems = items
            let object = try await request(url: components.url!, method: "GET")
            let raw = object["rows"] as? [[String: Any]] ?? []
            rows = raw.map(Self.row).sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
            selected = nil
            addresses = []
            if rows.isEmpty { message = "조회된 라우트가 없습니다." }
        } catch {
            rows = []
            selected = nil
            addresses = []
            message = error.localizedDescription
        }
    }

    func select(_ row: RouteEditorRow) async {
        selected = row
        camp = row.camp
        code = row.code
        await loadAddresses(row)
    }

    func delete(_ row: RouteEditorRow) async {
        guard let id = row.idValue else {
            message = "삭제할 라우트 ID가 없습니다."
            return
        }
        loading = true
        defer { loading = false }
        do {
            _ = try await request(url: base.appendingPathComponent("route"), method: "DELETE", body: ["id": id])
            message = "삭제 완료"
            selected = nil
            addresses = []
            await load()
        } catch {
            message = error.localizedDescription
        }
    }

    func makeShareLink(_ row: RouteEditorRow) async {
        do {
            var components = URLComponents(url: base.appendingPathComponent("share-link"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "camp", value: row.camp),
                URLQueryItem(name: "code", value: row.code)
            ]
            let object = try await request(url: components.url!, method: "GET")
            let link = Self.text(object["url"])
            message = link.isEmpty ? "공유 링크를 받지 못했습니다." : link
        } catch {
            message = error.localizedDescription
        }
    }

    private func loadAddresses(_ row: RouteEditorRow) async {
        addressesLoading = true
        defer { addressesLoading = false }
        do {
            var components = URLComponents(url: base.appendingPathComponent("addresses"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "camp", value: row.camp),
                URLQueryItem(name: "code", value: row.code)
            ]
            let object = try await request(url: components.url!, method: "GET")
            let raw = object["rows"] as? [[String: Any]] ?? []
            addresses = Array(Set(raw.compactMap { item in
                let candidates = ["road_address", "address", "address_name", "jibun_address"]
                return candidates.map { Self.text(item[$0]) }.first { !$0.isEmpty }
            })).sorted()
        } catch {
            addresses = []
            message = error.localizedDescription
        }
    }

    private func request(url: URL, method: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body.mapValues { value in
                if let hashable = value as? AnyHashable { return hashable.base }
                return value
            })
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "RouteEditor", code: code, userInfo: [NSLocalizedDescriptionKey: "라우트 요청 실패 (\(code))"])
        }
        if data.isEmpty { return [:] }
        let root = try JSONSerialization.jsonObject(with: data)
        if let object = root as? [String: Any] { return object }
        if let array = root as? [[String: Any]] { return ["rows": array] }
        return [:]
    }

    private static func row(_ object: [String: Any]) -> RouteEditorRow {
        let idValue: AnyHashable? = {
            if let value = object["id"] as? AnyHashable { return value }
            return nil
        }()
        let camp = text(object["camp"])
        let code = text(object["code"]).isEmpty ? text(object["route"]) : text(object["code"])
        return RouteEditorRow(
            id: idValue.map { String(describing: $0) } ?? "\(camp)|\(code)",
            idValue: idValue,
            camp: camp,
            code: code,
            vendorDay: firstText(object, keys: ["vendor_name_2w", "vendor_day", "vendor_2w", "vendor_business_number_2w"]),
            vendorNight: firstText(object, keys: ["vendor_name_1w", "vendor_night", "vendor_1w", "vendor_business_number_1w"]),
            deliveryName: firstText(object, keys: ["delivery_location_name", "delivery_name", "mb_camp"]),
            deliveryAddress: firstText(object, keys: ["delivery_location_address", "delivery_address", "address"])
        )
    }

    private static func firstText(_ object: [String: Any], keys: [String]) -> String {
        for key in keys {
            let value = text(object[key])
            if !value.isEmpty { return value }
        }
        return ""
    }

    private static func text(_ value: Any?) -> String {
        if value == nil || value is NSNull { return "" }
        if let string = value as? String { return string.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value ?? "")
    }
}