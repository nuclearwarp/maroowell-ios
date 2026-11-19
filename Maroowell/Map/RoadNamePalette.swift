import Foundation

/// Exact road-name hash/palette from mw-zip-road-overlay.js colorForRoad().
/// Names, not array positions or object IDs, determine each building's color.
enum RoadNamePalette {
    struct Colors {
        let fill: String
        let stroke: String
    }

    private static let palette: [Colors] = [
        Colors(fill: "#90c1da", stroke: "#2c84af"),
        Colors(fill: "#6666db", stroke: "#19199a"),
        Colors(fill: "#db6666", stroke: "#9a1919"),
        Colors(fill: "#dbdb66", stroke: "#9a9a19"),
        Colors(fill: "#e387e3", stroke: "#bd1fbd"),
        Colors(fill: "#e3a687", stroke: "#bd531f"),
        Colors(fill: "#7dc57d", stroke: "#2e842e"),
        Colors(fill: "#9090da", stroke: "#2c2caf"),
        Colors(fill: "#a8ebd5", stroke: "#28a078"),
        Colors(fill: "#b466db", stroke: "#6f199a"),
        Colors(fill: "#deb5de", stroke: "#9e409e"),
        Colors(fill: "#c57dad", stroke: "#842e68"),
        Colors(fill: "#e4d2af", stroke: "#937028"),
        Colors(fill: "#87e387", stroke: "#288e28"),
        Colors(fill: "#c5897d", stroke: "#843d2e"),
        Colors(fill: "#66dbc8", stroke: "#198e84"),
        Colors(fill: "#b3a8eb", stroke: "#5c40aa"),
        Colors(fill: "#d0c071", stroke: "#8f7d24"),
        Colors(fill: "#db66c8", stroke: "#9a1984"),
        Colors(fill: "#d199b5", stroke: "#a2396e"),
        Colors(fill: "#ebeba8", stroke: "#8e8e24"),
        Colors(fill: "#7da1c5", stroke: "#2e5984"),
        Colors(fill: "#a2d199", stroke: "#4b8039"),
        Colors(fill: "#9171d0", stroke: "#47248f"),
        Colors(fill: "#a8d5eb", stroke: "#328ca5"),
        Colors(fill: "#debcb5", stroke: "#986045"),
        Colors(fill: "#b587e3", stroke: "#6e1fbd"),
        Colors(fill: "#7dc5ad", stroke: "#2e8468"),
        Colors(fill: "#b3eba8", stroke: "#489f2c"),
        Colors(fill: "#7181d0", stroke: "#24368f")
    ]
    private static let unknown = Colors(fill: "#d4dbe2", stroke: "#6b7c8b")

    static func canonicalRoad(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
    }

    /// Match normalized full road names, never a prefix such as 도림로 vs 도림로36길.
    static func isExactRoad(_ left: String, _ right: String) -> Bool {
        let target = canonicalRoad(right)
        return !target.isEmpty && canonicalRoad(left) == target
    }

    static func forRoad(_ roadName: String) -> Colors {
        let road = canonicalRoad(roadName)
        if road.isEmpty || road == "도로명미확인" { return unknown }

        // UInt32 wrapping multiplication == JavaScript Math.imul, UnicodeScalar == codePointAt.
        var hash: UInt32 = 2166136261 ^ 1218
        for scalar in road.unicodeScalars {
            hash = (hash ^ scalar.value) &* 16777619
        }
        hash = hash ^ (hash >> 16)
        hash = hash &* 0x85ebca6b
        hash = hash ^ (hash >> 13)
        hash = hash &* 0xc2b2ae35
        hash = hash ^ (hash >> 16)
        return palette[Int(hash % UInt32(palette.count))]
    }
}
