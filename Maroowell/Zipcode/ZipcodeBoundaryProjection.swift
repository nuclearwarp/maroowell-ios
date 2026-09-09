import Foundation
import MapKit

struct ZipcodeBoundaryGeometry {
    let polygons: [[CLLocationCoordinate2D]]

    var mapRect: MKMapRect {
        polygons.reduce(MKMapRect.null) { partial, polygon in
            polygon.reduce(partial) { rect, coordinate in
                let point = MKMapPoint(coordinate)
                return rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
            }
        }
    }
}

enum ZipcodeBoundaryProjection {
    static func decodeGeoJSON(_ data: Data) throws -> ZipcodeBoundaryGeometry {
        let root = try JSONSerialization.jsonObject(with: data)
        let object = root as? [String: Any] ?? [:]
        let geometry: [String: Any]
        if let featureGeometry = object["geometry"] as? [String: Any] {
            geometry = featureGeometry
        } else if let features = object["features"] as? [[String: Any]],
                  let first = features.first,
                  let firstGeometry = first["geometry"] as? [String: Any] {
            geometry = firstGeometry
        } else {
            geometry = object
        }

        let type = (geometry["type"] as? String ?? "").lowercased()
        let raw = geometry["coordinates"]
        let projected = isProjectedCRS(object) || isProjectedCRS(geometry)

        let polygons: [[CLLocationCoordinate2D]]
        switch type {
        case "polygon":
            polygons = parsePolygon(raw, projected: projected)
        case "multipolygon":
            polygons = parseMultiPolygon(raw, projected: projected)
        default:
            polygons = []
        }

        guard !polygons.isEmpty else {
            throw NSError(domain: "ZipcodeBoundary", code: 1, userInfo: [NSLocalizedDescriptionKey: "우편번호 경계 좌표를 해석하지 못했습니다."])
        }
        return ZipcodeBoundaryGeometry(polygons: polygons)
    }

    private static func parsePolygon(_ raw: Any?, projected: Bool) -> [[CLLocationCoordinate2D]] {
        guard let rings = raw as? [[[Double]]] else { return [] }
        return rings.compactMap { ring in
            let points = ring.compactMap { coordinate($0, projected: projected) }
            return points.count >= 3 ? points : nil
        }
    }

    private static func parseMultiPolygon(_ raw: Any?, projected: Bool) -> [[CLLocationCoordinate2D]] {
        guard let polygons = raw as? [[[[Double]]]] else { return [] }
        return polygons.flatMap { polygon in
            polygon.compactMap { ring in
                let points = ring.compactMap { coordinate($0, projected: projected) }
                return points.count >= 3 ? points : nil
            }
        }
    }

    private static func coordinate(_ pair: [Double], projected: Bool) -> CLLocationCoordinate2D? {
        guard pair.count >= 2 else { return nil }
        if projected || abs(pair[0]) > 180 || abs(pair[1]) > 90 {
            return KoreaTM5179.inverse(x: pair[0], y: pair[1])
        }
        return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
    }

    private static func isProjectedCRS(_ object: [String: Any]) -> Bool {
        let text = String(describing: object["crs"] ?? "").lowercased()
        return text.contains("5179") || text.contains("korea 2000") || text.contains("unified cs")
    }
}

enum KoreaTM5179 {
    // EPSG:5179 Korea 2000 / Unified CS (GRS80), inverse Transverse Mercator.
    private static let a = 6_378_137.0
    private static let f = 1.0 / 298.257222101
    private static let k0 = 0.9996
    private static let lon0 = 127.5 * .pi / 180.0
    private static let lat0 = 38.0 * .pi / 180.0
    private static let falseEasting = 1_000_000.0
    private static let falseNorthing = 2_000_000.0

    static func inverse(x: Double, y: Double) -> CLLocationCoordinate2D? {
        let e2 = f * (2 - f)
        let ep2 = e2 / (1 - e2)
        let m0 = meridionalArc(lat0, e2: e2)
        let m = m0 + (y - falseNorthing) / k0
        let mu = m / (a * (1 - e2 / 4 - 3 * pow(e2, 2) / 64 - 5 * pow(e2, 3) / 256))
        let e1 = (1 - sqrt(1 - e2)) / (1 + sqrt(1 - e2))
        let j1 = 3 * e1 / 2 - 27 * pow(e1, 3) / 32
        let j2 = 21 * pow(e1, 2) / 16 - 55 * pow(e1, 4) / 32
        let j3 = 151 * pow(e1, 3) / 96
        let j4 = 1097 * pow(e1, 4) / 512
        let fp = mu + j1 * sin(2 * mu) + j2 * sin(4 * mu) + j3 * sin(6 * mu) + j4 * sin(8 * mu)

        let sinFP = sin(fp)
        let cosFP = cos(fp)
        guard abs(cosFP) > 1e-12 else { return nil }
        let tanFP = tan(fp)
        let c1 = ep2 * pow(cosFP, 2)
        let t1 = pow(tanFP, 2)
        let n1 = a / sqrt(1 - e2 * pow(sinFP, 2))
        let r1 = a * (1 - e2) / pow(1 - e2 * pow(sinFP, 2), 1.5)
        let d = (x - falseEasting) / (n1 * k0)

        let lat = fp - (n1 * tanFP / r1) * (
            pow(d, 2) / 2
            - (5 + 3 * t1 + 10 * c1 - 4 * pow(c1, 2) - 9 * ep2) * pow(d, 4) / 24
            + (61 + 90 * t1 + 298 * c1 + 45 * pow(t1, 2) - 252 * ep2 - 3 * pow(c1, 2)) * pow(d, 6) / 720
        )
        let lon = lon0 + (
            d
            - (1 + 2 * t1 + c1) * pow(d, 3) / 6
            + (5 - 2 * c1 + 28 * t1 - 3 * pow(c1, 2) + 8 * ep2 + 24 * pow(t1, 2)) * pow(d, 5) / 120
        ) / cosFP

        let latitude = lat * 180 / .pi
        let longitude = lon * 180 / .pi
        guard latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func meridionalArc(_ latitude: Double, e2: Double) -> Double {
        a * (
            (1 - e2 / 4 - 3 * pow(e2, 2) / 64 - 5 * pow(e2, 3) / 256) * latitude
            - (3 * e2 / 8 + 3 * pow(e2, 2) / 32 + 45 * pow(e2, 3) / 1024) * sin(2 * latitude)
            + (15 * pow(e2, 2) / 256 + 45 * pow(e2, 3) / 1024) * sin(4 * latitude)
            - (35 * pow(e2, 3) / 3072) * sin(6 * latitude)
        )
    }
}
