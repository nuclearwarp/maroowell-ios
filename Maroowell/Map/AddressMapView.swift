import CoreLocation
import SwiftUI

struct AddressMapItem: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let campType: String

    init(label: String, address: String, latitude: Double? = nil, longitude: Double? = nil, campType: String = "") {
        self.label = label
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.campType = campType
    }
}

struct AddressMapView: View {
    let title: String
    let items: [AddressMapItem]
    @State private var resolved: [KakaoResolvedAddress] = []
    @State private var focusedID: String?

    var body: some View {
        VStack(spacing: 0) {
            KakaoMapWebView(
                addresses: items.map { item in
                    KakaoMapAddress(
                        id: item.id.uuidString,
                        label: item.label.isEmpty ? item.address : item.label,
                        address: item.address,
                        latitude: item.latitude,
                        longitude: item.longitude,
                        kind: item.campType
                    )
                },                fitContent: focusedID == nil,
                focusMarkerID: focusedID,
                onResolvedAddresses: { values in
                    resolved = values
                }
            )
            .overlay(alignment: .topLeading) {
                Text("카카오맵 · 위치 \(resolved.count)/\(items.count)")
                    .font(.caption.weight(.black))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(9)
            }

            if !resolved.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(resolved) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                Button {
                                    focusedID = item.id
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.label)
                                            .font(.caption.weight(.black))
                                            .lineLimit(1)
                                        Text(item.address)
                                            .font(.caption2)
                                            .foregroundStyle(MaroowellTheme.muted)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)

                                Button("카카오맵 길찾기") {
                                    openKakao(item)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }                            .frame(width: 190, alignment: .leading)
                            .padding(10)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(10)
                }
                .background(MaroowellTheme.background)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openKakao(_ item: KakaoResolvedAddress) {
        let label = item.label.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "쿠팡%20캠프"
        guard let url = URL(
            string: "https://map.kakao.com/link/to/\(label),\(item.coordinate.latitude),\(item.coordinate.longitude)"
        ) else { return }
        UIApplication.shared.open(url)
    }
}
