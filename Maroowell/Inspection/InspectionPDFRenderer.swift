import Foundation
import UIKit

struct InspectionPDFRenderer {
    static func create(
        month: Date,
        profile: InspectionProfile,
        records: [Int: InspectionDayRecord],
        signature: InspectionSignature
    ) throws -> URL {
        let monthKey = monthKey(for: month)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("운수종사자_일상점검표_\(monthKey).pdf")

        let page = CGRect(x: 0, y: 0, width: 842, height: 595)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { context in
            context.beginPage()
            let cg = context.cgContext
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(page)

            drawText("운수종사자 일상점검표", rect: CGRect(x: 40, y: 25, width: 762, height: 34), font: .boldSystemFont(ofSize: 22), alignment: .center)
            drawText("\(monthKey.replacingOccurrences(of: "-", with: "년 "))월", rect: CGRect(x: 40, y: 60, width: 762, height: 20), font: .systemFont(ofSize: 12), alignment: .center)

            drawLabelValue("운송사업자명", profile.carrierName, x: 40, y: 90, width: 250)
            drawLabelValue("차량번호", profile.vehicleNumber, x: 300, y: 90, width: 220)
            drawLabelValue("운수종사자명", profile.driverName, x: 530, y: 90, width: 272)

            let left: CGFloat = 40
            let top: CGFloat = 128
            let tableWidth: CGFloat = 762
            let itemWidth: CGFloat = 300
            let dayWidth: CGFloat = (tableWidth - itemWidth) / 31.0
            let rowHeight: CGFloat = 29

            cg.setStrokeColor(UIColor.black.cgColor)
            cg.setLineWidth(0.6)

            var x = left
            cg.stroke(CGRect(x: left, y: top, width: tableWidth, height: rowHeight))
            drawText("점검항목", rect: CGRect(x: left + 4, y: top + 6, width: itemWidth - 8, height: 18), font: .boldSystemFont(ofSize: 9), alignment: .center)
            x += itemWidth
            for day in 1...31 {
                cg.stroke(CGRect(x: x, y: top, width: dayWidth, height: rowHeight))
                drawText("\(day)", rect: CGRect(x: x, y: top + 7, width: dayWidth, height: 16), font: .boldSystemFont(ofSize: 7), alignment: .center)
                x += dayWidth
            }

            var y = top + rowHeight
            for (index, item) in InspectionSchema.items.enumerated() {
                cg.stroke(CGRect(x: left, y: y, width: itemWidth, height: rowHeight))
                drawText("\(index + 1). \(item)", rect: CGRect(x: left + 4, y: y + 3, width: itemWidth - 8, height: rowHeight - 6), font: .systemFont(ofSize: 7), alignment: .left)
                x = left + itemWidth
                for day in 1...31 {
                    cg.stroke(CGRect(x: x, y: y, width: dayWidth, height: rowHeight))
                    let mark = records[day]?.statuses[safe: index] ?? ""
                    drawText(mark, rect: CGRect(x: x, y: y + 7, width: dayWidth, height: 14), font: .boldSystemFont(ofSize: 7), alignment: .center)
                    x += dayWidth
                }
                y += rowHeight
            }

            let noteY = y + 8
            drawText("불량상태 조치 기록", rect: CGRect(x: left, y: noteY, width: 120, height: 18), font: .boldSystemFont(ofSize: 9), alignment: .left)
            let notes = records.sorted(by: { $0.key < $1.key })
                .compactMap { day, record in
                    let note = record.actionNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    return note.isEmpty ? nil : "\(day)일: \(note)"
                }
                .joined(separator: "   ")
            drawText(notes.isEmpty ? "-" : notes, rect: CGRect(x: left, y: noteY + 20, width: 540, height: 54), font: .systemFont(ofSize: 8), alignment: .left)

            drawText("점검자 서명", rect: CGRect(x: 610, y: noteY, width: 100, height: 18), font: .boldSystemFont(ofSize: 9), alignment: .center)
            drawSignature(signature, in: CGRect(x: 620, y: noteY + 18, width: 150, height: 58), context: cg)
        }

        try data.write(to: url, options: .atomic)
        return url
    }

    private static func monthKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let comps = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }

    private static func drawLabelValue(_ label: String, _ value: String, x: CGFloat, y: CGFloat, width: CGFloat) {
        drawText(label, rect: CGRect(x: x, y: y, width: width * 0.38, height: 24), font: .boldSystemFont(ofSize: 9), alignment: .left)
        drawText(value, rect: CGRect(x: x + width * 0.38, y: y, width: width * 0.62, height: 24), font: .systemFont(ofSize: 9), alignment: .left)
    }

    private static func drawText(_ text: String, rect: CGRect, font: UIFont, alignment: NSTextAlignment) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        text.draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: style
        ])
    }

    private static func drawSignature(_ signature: InspectionSignature, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.7)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for stroke in signature.strokes where stroke.count > 1 {
            guard let first = stroke.first else { continue }
            context.beginPath()
            context.move(to: CGPoint(
                x: rect.minX + CGFloat(first.x) * rect.width,
                y: rect.minY + CGFloat(first.y) * rect.height
            ))
            for point in stroke.dropFirst() {
                context.addLine(to: CGPoint(
                    x: rect.minX + CGFloat(point.x) * rect.width,
                    y: rect.minY + CGFloat(point.y) * rect.height
                ))
            }
            context.strokePath()
        }
        context.restoreGState()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
