import SwiftUI
import UIKit

struct MetaRealtimeShareView: View {
    @State private var shareImage: UIImage?
    @State private var isSharing = false

    var body: some View {
        MetaRealtimeView()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        captureAndShare()
                    } label: {
                        Label("현황 공유", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityHint("현재 보이는 실시간 배송 현황을 이미지로 공유합니다.")
                }
            }
            .sheet(isPresented: $isSharing, onDismiss: {
                shareImage = nil
            }) {
                if let shareImage {
                    MetaActivityShareSheet(items: [shareImage])
                        .presentationDetents([.medium, .large])
                }
            }
    }

    @MainActor
    private func captureAndShare() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })
        else { return }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = window.screen.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        let image = renderer.image { context in
            if !window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) {
                window.layer.render(in: context.cgContext)
            }
        }

        shareImage = image
        isSharing = true
    }
}

private struct MetaActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
