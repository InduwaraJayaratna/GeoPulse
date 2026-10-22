import Foundation
import SwiftUI
import UIKit

/// Renders an `Inspection` to a one-page PDF using SwiftUI's `ImageRenderer`.
///
/// Produces a letter-size document written to the temporary directory, suitable
/// for passing to `ShareLink`. No network call, no external SDK — just native
/// drawing + Core Graphics PDF context.
@MainActor
enum PDFReportBuilder {

    static func build(for inspection: Inspection, user: UserProfile) -> URL? {
        let page = PDFReportPage(inspection: inspection, user: user)
            .frame(width: 612, height: 792) // US Letter at 72dpi
        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(width: 612, height: 792)

        let filename = "GeoPulse-Inspection-\(inspection.id.uuidString.prefix(8)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        var success = false
        renderer.render { size, drawInRect in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            drawInRect(context)
            context.endPDFPage()
            context.closePDF()
            success = true
        }
        return success ? url : nil
    }
}

/// Printable summary of a completed inspection. Deliberately mono-weighted and
/// high-contrast so it reads as an archival/compliance document rather than an
/// extension of the app chrome.
private struct PDFReportPage: View {
    let inspection: Inspection
    let user: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            sectionDivider
            metadataGrid
            sectionDivider
            summarySection
            if let hazard = inspection.hazardTag {
                hazardSection(label: hazard, confidence: inspection.hazardConfidence ?? 0)
            }
            if let note = inspection.voiceNote, !note.isEmpty {
                voiceSection(note: note)
            }
            Spacer()
            footer
        }
        .padding(40)
        .frame(width: 612, height: 792, alignment: .topLeading)
        .background(.white)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GeoPulse")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Color(red: 0.11, green: 0.21, blue: 0.47))
                Text("Field Inspection Report")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Report ID")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(inspection.id.uuidString.prefix(8).uppercased())
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
        }
    }

    private var sectionDivider: some View {
        Rectangle().fill(Color(white: 0.85)).frame(height: 1)
    }

    private var metadataGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            kv("Site", inspection.siteName)
            kv("Inspector", inspection.inspectorName)
            kv("Completed", shortDate(inspection.completedAt))
            kv("Duration", "\(inspection.durationMinutes) min")
            kv("Status", inspection.statusTag)
        }
    }

    private func kv(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RESULT SUMMARY")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text("\(inspection.passedCount) of \(inspection.totalCount) checkpoints passed. \(inspection.resultSummary)")
                .font(.system(size: 12))
                .foregroundStyle(.black)
        }
    }

    private func hazardSection(label: String, confidence: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HAZARD CLASSIFICATION — ON-DEVICE VISION")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.orange)
                Spacer()
                Text("\(Int(confidence * 100))% confidence")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.orange.opacity(0.08))
        }
    }

    private func voiceSection(note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VOICE TRANSCRIPT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text("\u{201C}\(note)\u{201D}")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.black)
                .padding(10)
                .background(Color(white: 0.95))
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionDivider
            HStack {
                Text("Generated by GeoPulse · Authorised: \(user.displayName)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(shortDate(Date()))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
