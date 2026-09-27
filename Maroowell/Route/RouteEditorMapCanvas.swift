import CoreLocation
import SwiftUI

struct RouteEditorMapCanvas: View {
    @Binding var draftPoints: [CLLocationCoordinate2D]
    let polygons: [[CLLocationCoordinate2D]]
    let drawingEnabled: Bool
    let fitContent: Bool

    var body: some View {
        KakaoMapWebView(
            polygons: renderedPolygons,
            drawingEnabled: drawingEnabled,
            fitContent: fitContent,
            onMapTap: { coordinate in
                guard drawingEnabled else { return }
                draftPoints.append(coordinate)
            }
        )
    }

    private var renderedPolygons: [KakaoMapPolygon] {
        var output = polygons.enumerated().map { index, coordinates in
            KakaoMapPolygon(
                id: "saved-\(index)",
                coordinates: coordinates,
                selected: false,
                draft: false
            )
        }

        if draftPoints.count >= 2 {
            output.append(
                KakaoMapPolygon(
                    id: "draft",
                    coordinates: draftPoints,
                    selected: true,
                    draft: true
                )
            )
        }
        return output
    }
}
