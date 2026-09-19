import SwiftUI
import UIKit

struct MetaRealtimeShareView: View {
    @StateObject private var store = MetaRealtimeStore()
    @State private var shareImage: UIImage?
    @State private var isSharing = false
    @State private var isRendering = false

    var body: some View {
        MetaRealtimeView(store: store)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            renderAndShare(includeDrivers: false)
                        } label: {
                            Label("캠프 현황 이미지", systemImage: "photo")
                        }

                        Button {
                            renderAndShare(includeDrivers: true)
                        } label: {
                            Label("기사 포함 이미지", systemImage: "person.3.fill")
                        }
                    } label: {
                        if isRendering {
                            ProgressView()
                        } else {
                            Label("현황 공유", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isRendering || store.filteredRows.isEmpty)
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
    private func renderAndShare(includeDrivers: Bool) {
        guard !store.filteredRows.isEmpty else { return }
        isRendering = true
        defer { isRendering = false }

        let report = MetaRealtimeReportView(store: store, includeDrivers: includeDrivers)
        let renderer = ImageRenderer(content: report)
        renderer.scale = 2.0
        renderer.isOpaque = true

        guard let image = renderer.uiImage else { return }
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
