import SwiftUI

struct SignaturePad: View {
    @Binding var signature: InspectionSignature
    @State private var currentStroke: [SignaturePoint] = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)

                Canvas { context, size in
                    for stroke in signature.strokes + (currentStroke.isEmpty ? [] : [currentStroke]) {
                        guard stroke.count > 1 else { continue }
                        var path = Path()
                        if let first = stroke.first {
                            path.move(to: CGPoint(
                                x: CGFloat(first.x) * size.width,
                                y: CGFloat(first.y) * size.height
                            ))
                        }
                        for point in stroke.dropFirst() {
                            path.addLine(to: CGPoint(
                                x: CGFloat(point.x) * size.width,
                                y: CGFloat(point.y) * size.height
                            ))
                        }
                        context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    }
                }
                .padding(8)

                if signature.isEmpty && currentStroke.isEmpty {
                    Text("손가락으로 서명하세요")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard proxy.size.width > 0, proxy.size.height > 0 else { return }
                        let x = Double(min(max(value.location.x / proxy.size.width, 0), 1))
                        let y = Double(min(max(value.location.y / proxy.size.height, 0), 1))
                        currentStroke.append(SignaturePoint(x: x, y: y))
                    }
                    .onEnded { _ in
                        if currentStroke.count > 1 {
                            signature.strokes.append(currentStroke)
                        }
                        currentStroke.removeAll()
                    }
            )
        }
        .frame(height: 220)
    }
}

struct SignaturePreview: View {
    let signature: InspectionSignature

    var body: some View {
        Canvas { context, size in
            for stroke in signature.strokes {
                guard stroke.count > 1 else { continue }
                var path = Path()
                if let first = stroke.first {
                    path.move(to: CGPoint(
                        x: CGFloat(first.x) * size.width,
                        y: CGFloat(first.y) * size.height
                    ))
                }
                for point in stroke.dropFirst() {
                    path.addLine(to: CGPoint(
                        x: CGFloat(point.x) * size.width,
                        y: CGFloat(point.y) * size.height
                    ))
                }
                context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
