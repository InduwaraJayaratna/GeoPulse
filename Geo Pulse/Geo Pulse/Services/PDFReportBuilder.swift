import Foundation
import UIKit
import CoreText

/// Paginated text report. Core Text reports how much fits on each page, so long
/// observations continue onto following pages instead of being silently clipped.
@MainActor
enum PDFReportBuilder {
    static func build(for inspection: Inspection, user: UserProfile) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeoPulse-Inspection-\(inspection.id.uuidString).pdf")
        var lines = ["GeoPulse — Field Inspection Report", "Report ID: \(inspection.id)",
            "Site: \(inspection.siteName)", "Inspector: \(inspection.inspectorName)",
            "Completed: \(inspection.completedAt.formatted())", "Duration: \(inspection.durationMinutes) minutes",
            "Status: \(inspection.statusTag)",
            "\(inspection.passedCount) of \(inspection.totalCount) checkpoints passed or remediated.",
            "", "RESULT SUMMARY", inspection.resultSummary]
        if let hazard = inspection.hazardTag {
            lines += ["", "PHOTO ANALYSIS SUGGESTION", hazard]
            if let confidence = inspection.hazardConfidence {
                lines.append("Image label confidence: \(Int(confidence * 100))%. Requires inspector review.")
            }
        }
        if let note = inspection.voiceNote { lines += ["", "INSPECTION NOTES", note] }
        lines += ["", "Storage: \(inspection.syncState.displayText)", "Exported by: \(user.displayName)"]
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        let text = NSAttributedString(string: lines.joined(separator: "\n"), attributes: [
            .font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ])
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        do {
            try renderer.writePDF(to: url) { rendererContext in
                var offset = 0
                while offset < text.length {
                    rendererContext.beginPage()
                    let context = rendererContext.cgContext
                    context.saveGState()
                    context.textMatrix = .identity
                    context.translateBy(x: 0, y: bounds.height)
                    context.scaleBy(x: 1, y: -1)
                    let path = CGPath(rect: bounds.insetBy(dx: 40, dy: 40), transform: nil)
                    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
                    CTFrameDraw(frame, context)
                    let range = CTFrameGetVisibleStringRange(frame)
                    context.restoreGState()
                    guard range.length > 0 else { break }
                    offset += range.length
                }
                if let name = inspection.photoName, let photoURL = PhotoStore().url(for: name),
                   let image = UIImage(contentsOfFile: photoURL.path), image.size.width > 0, image.size.height > 0 {
                    rendererContext.beginPage()
                    let available = bounds.insetBy(dx: 40, dy: 40)
                    let scale = min(available.width / image.size.width, available.height / image.size.height)
                    image.draw(in: CGRect(x: available.minX, y: available.minY,
                        width: image.size.width * scale, height: image.size.height * scale))
                }
            }
            return url
        } catch { return nil }
    }
}
