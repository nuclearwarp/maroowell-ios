import Foundation

/// Only considers a labeled 10...18 digit waybill or a standalone numeric value.
/// Keep the original clipboard content in the form; this only determines eligibility.
enum NumberingClipboardPolicy {
    private static let labeled = try! NSRegularExpression(
        pattern: #"(?:운송장|송장)\s*번호\s*[:：]?\s*([0-9]{10,18})(?![0-9])"#
    )
    private static let standalone = try! NSRegularExpression(pattern: #"^[0-9]{10,18}$"#)

    static func extract(_ raw: String) -> String {
        guard !raw.isEmpty, raw.count <= 3000 else { return "" }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = labeled.firstMatch(in: text, range: range),
           let number = Range(match.range(at: 1), in: text) {
            return String(text[number])
        }
        return standalone.firstMatch(in: text, range: range) == nil ? "" : text
    }
}
