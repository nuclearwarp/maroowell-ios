import MapKit
import SwiftUI

struct AddressMapItem: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let campType: String

    init(label: String, address: String, latitude: Double? = nil, longitude: Double? = nil, campType: String = "") {
        self.label = label; self.address = address; self.latitude = latitude; self.longitude = longitude; self.campType = campType
    }
}

struct AddressMapView: View {
    let title: String
    let items: [AddressMapItem]
    @State private var resolved: [AddressMapResolvedItem] = []
    @State private var camera: MapCameraPosition = .automatic
    @State private var loading = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $camera) {
                ForEach(resolved) { item in
                    Marker(item.label, coordinate: item.coordinate)
                        .tint(item.campType.caseInsensitiveCompare("SUB_HUB") == .orderedSame ? .orange : .blue)
                }
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 7) {
                    if loading { ProgressView().controlSize(.small) }
                    Text(loading ? "위치 확인 중…" : "위치 \(resolved.count)/\(items.count)")
                        .font(.caption.weight(.black))
                }
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule()).padding(9)
            }

            if !resolved.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(resolved) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.label).font(.caption.weight(.black)).lineLimit(1)
                                Text(item.address).font(.caption2).foregroundStyle(MaroowellTheme.muted).lineLimit(1)
                                Button("카카오맵 길찾기") { openKakao(item) }
                                    .buttonStyle(.bordered).controlSize(.small)
                            }
                            .frame(width: 190, alignment: .leading)
                            .padding(10)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }.padding(10)
                }
                .background(MaroowellTheme.background)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { if resolved.isEmpty { await resolveAll() } }
        .alert("지도", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("확인", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private func resolveAll() async {
        loading = true; defer { loading = false }
        var output: [AddressMapResolvedItem] = []
        for item in items {
            if let lat = item.latitude, let lon = item.longitude, lat.isFinite, lon.isFinite {
                output.append(.init(label: item.label.isEmpty ? item.address : item.label, address: item.address, coordinate: .init(latitude: lat, longitude: lon), campType: item.campType))
                continue
            }
            guard !item.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let request = MKLocalSearch.Request(); request.naturalLanguageQuery = item.address
            if let response = try? await MKLocalSearch(request: request).start(), let first = response.mapItems.first {
                output.append(.init(label: item.label.isEmpty ? item.address : item.label, address: item.address, coordinate: first.placemark.coordinate, campType: item.campType))
            }
        }
        resolved = output
        fit()
        if output.isEmpty { message = "지도에 표시할 위치를 찾지 못했습니다." }
        else if output.count < items.count { message = "일부 주소의 위치를 찾지 못했습니다. (\(output.count)/\(items.count))" }
    }

    private func fit() {
        guard !resolved.isEmpty else { return }
        let lats = resolved.map { $0.coordinate.latitude }, lons = resolved.map { $0.coordinate.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return }
        camera = .region(.init(
            center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: .init(latitudeDelta: max(maxLat - minLat, 0.015) * 1.25, longitudeDelta: max(maxLon - minLon, 0.015) * 1.25)
        ))
    }

    private func openKakao(_ item: AddressMapResolvedItem) {
        let label = item.label.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "쿠팡%20캠프"
        guard let url = URL(string: "https://map.kakao.com/link/to/\(label),\(item.coordinate.latitude),\(item.coordinate.longitude)") else { return }
        UIApplication.shared.open(url)
    }
}

private struct AddressMapResolvedItem: Identifiable {
    let id = UUID()
    let label: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let campType: String
}
