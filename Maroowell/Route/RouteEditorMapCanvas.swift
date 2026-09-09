import MapKit
import SwiftUI

struct RouteEditorMapCanvas: UIViewRepresentable {
    @Binding var draftPoints: [CLLocationCoordinate2D]
    let polygons: [[CLLocationCoordinate2D]]
    let drawingEnabled: Bool
    let fitContent: Bool

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsCompass = true
        map.showsScale = true
        let recognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        recognizer.cancelsTouchesInView = false
        map.addGestureRecognizer(recognizer)
        context.coordinator.map = map
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        for coordinates in polygons where coordinates.count >= 3 {
            let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
            polygon.title = "saved"
            map.addOverlay(polygon)
        }
        if draftPoints.count >= 2 {
            let line = MKPolyline(coordinates: draftPoints, count: draftPoints.count)
            line.title = "draft"
            map.addOverlay(line)
        }
        if draftPoints.count >= 3 {
            let draft = MKPolygon(coordinates: draftPoints, count: draftPoints.count)
            draft.title = "draft"
            map.addOverlay(draft)
        }

        for (index, coordinate) in draftPoints.enumerated() {
            let marker = MKPointAnnotation()
            marker.coordinate = coordinate
            marker.title = "\(index + 1)"
            map.addAnnotation(marker)
        }

        if fitContent {
            context.coordinator.fit(map)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteEditorMapCanvas
        weak var map: MKMapView?

        init(parent: RouteEditorMapCanvas) {
            self.parent = parent
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard parent.drawingEnabled, let map else { return }
            let point = recognizer.location(in: map)
            let coordinate = map.convert(point, toCoordinateFrom: map)
            parent.draftPoints.append(coordinate)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                if polygon.title == "draft" {
                    renderer.fillColor = UIColor.systemYellow.withAlphaComponent(0.18)
                    renderer.strokeColor = UIColor.systemOrange
                } else {
                    renderer.fillColor = UIColor.systemTeal.withAlphaComponent(0.12)
                    renderer.strokeColor = UIColor.systemTeal
                }
                renderer.lineWidth = 2
                return renderer
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemOrange
                renderer.lineWidth = 2
                renderer.lineDashPattern = [6, 5]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let id = "route-point"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.markerTintColor = .systemOrange
            view.glyphText = annotation.title ?? nil
            return view
        }

        func fit(_ map: MKMapView) {
            var rect = MKMapRect.null
            for overlay in map.overlays {
                rect = rect.union(overlay.boundingMapRect)
            }
            for annotation in map.annotations where !(annotation is MKUserLocation) {
                let point = MKMapPoint(annotation.coordinate)
                let tiny = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
                rect = rect.union(tiny)
            }
            guard !rect.isNull, !rect.isEmpty else { return }
            map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 56, left: 32, bottom: 56, right: 32), animated: false)
        }
    }
}
