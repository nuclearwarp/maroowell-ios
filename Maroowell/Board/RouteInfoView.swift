import Foundation
import SwiftUI

struct RouteInfoView: View {
    let session: AppSession
    @StateObject private var store = RouteInfoStore()
    @State private var selected: RouteInfoRow?

    var body: some View {
        Group {
            if session.canView("/maroowell_route_info") {
                content
            } else {
                denied
            }
        }
        .navigationTitle("마루웰 라우트정보")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard session.canView("/maroowell_route_info"), store.rows.isEmpty else { return }
            await store.load()
        }
        .sheet(item: $selected) { row in
            RouteInfoDetail(row: row)
        }
        .alert("라우트정보", isPresented: Binding(get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
            Button("확인", role: .cancel) { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(MaroowellTheme.muted)
                        TextField("캠프 / 라우트 / 서브 / 설명 필터", text: $store.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !store.query.isEmpty {
                            Button { store.query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(MaroowellTheme.muted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(MaroowellTheme.background, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    HStack {
                        Text(store.loading ? "데이터 불러오는 중..." : "\(store.filtered.count)건")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MaroowellTheme.muted)
                        Spacer()
                        Button {
                            Task { await store.load() }
                        } label: {
                            Label("새로고침", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.loading)
                    }
                }
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 20).stroke(MaroowellTheme.border) }

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
                        Button { selected = row } label: {
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
                            .padding(14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 18).stroke(MaroowellTheme.border) }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(MaroowellTheme.background)
    }

    private var denied: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill").font(.largeTitle)
            Text("마루웰 라우트정보 권한이 필요합니다.").font(.headline.weight(.black))
        }
        .foregroundStyle(MaroowellTheme.muted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MaroowellTheme.background)
    }
}

private struct RouteInfoDetail: View {
    let row: RouteInfoRow

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let point = row.mapPoint {
                        NavigationLink {
                            AddressMapView(
                                title: row.title.isEmpty ? "라우트 위치" : row.title,
                                items: [
                                    AddressMapItem(
                                        label: row.title.isEmpty ? row.fullRoute : row.title,
                                        address: "",
                                        latitude: point.latitude,
                                        longitude: point.longitude
                                    )
                                ]
                            )
                        } label: {
                            Label("지도에서 위치 보기", systemImage: "map.fill")
                                .font(.subheadline.weight(.black))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                        }
                        .buttonStyle(.borderedProminent)
                    }

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
        let displayCamp = camp.hasPrefix("M_") ? camp.replacingOccurrences(of: "M_", with: "M", options: [], range: camp.startIndex..<camp.index(camp.startIndex, offsetBy: min(2, camp.count))) : camp
        return [displayCamp, fullRoute].filter { !$0.isEmpty }.joined(separator: " - ")
    }

    var searchable: String {
        [camp, route, sub, subSub, fullRoute, description, memo].joined(separator: " ").lowercased()
    }

    var mapPoint: (latitude: Double, longitude: Double)? {
        let values = coordinate
            .components(separatedBy: CharacterSet(charactersIn: ", /|()[]"))
            .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard values.count >= 2 else { return nil }
        let first = values[0], second = values[1]
        if (-90...90).contains(first), (-180...180).contains(second) {
            return (first, second)
        }
        if (-90...90).contains(second), (-180...180).contains(first) {
            return (second, first)
        }
        return nil
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

    func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let auth = try await SupabaseService.shared.client.auth.session
            var c = URLComponents(url: AppConfig.supabaseURL.appendingPathComponent("rest/v1/maroowell_route_info"), resolvingAgainstBaseURL: false)!
            c.query = "select=camp,route,sub,sub_sub,sub_package,route_code,route_norm,description,memo,coordinate,sort_order,is_active&order=camp.asc,route.asc,sort_order.asc&limit=500"
            var request = URLRequest(url: c.url!)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(AppConfig.supabasePublishableKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "RouteInfo", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "라우트정보 조회 실패"])
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

    private static func row(_ object: [String: Any]) -> RouteInfoRow {
        let camp = text(object["camp"])
        let route = text(object["route"])
        let sub = text(object["sub"])
        let subSub = text(object["sub_sub"])
        let sort = Int(text(object["sort_order"])) ?? 0
        return RouteInfoRow(
            id: [camp, route, sub, subSub, String(sort)].joined(separator: "|"),
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
        if value == nil || value is NSNull { return "" }
        if let string = value as? String { return string.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let number = value as? NSNumber { return number.stringValue }
        return String(describing: value ?? "")
    }

    private static func compact(_ value: String) -> String {
        value.uppercased().filter { $0.isNumber || $0.isLetter || ("가"..."힣").contains(String($0)) }
    }
}
