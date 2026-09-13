import UIKit

extension PDFService {
    static func generateSolarMaintenancePDF(record: MaintenanceRecord, settings: AppSettings) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            var y: CGFloat = 40
            func page() {
                context.beginPage()
                y = 40
            }
            func line(_ text: String, bold: Bool = false) {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: bold ? 12 : 10, weight: bold ? .bold : .regular),
                    .foregroundColor: UIColor.black
                ]
                // Paragraphs are split into lines so long notes can continue on another page.
                for paragraph in text.components(separatedBy: "\n") {
                    var remainder = paragraph[...]
                    repeat {
                        // Bound work per line, then binary-search the fitting prefix.
                        let candidates = Array(remainder.prefix(200))
                        var low = 0
                        var high = candidates.count
                        while low < high {
                            let middle = (low + high + 1) / 2
                            if (String(candidates.prefix(middle)) as NSString).size(withAttributes: attrs).width <= 515 {
                                low = middle
                            } else { high = middle - 1 }
                        }
                        var count = candidates.isEmpty ? 0 : max(1, low)
                        if count < candidates.count,
                           let boundary = candidates.prefix(count).lastIndex(where: { $0.isWhitespace }),
                           boundary > 0 {
                            count = boundary + 1
                        }
                        let end = remainder.index(remainder.startIndex, offsetBy: count)
                        if y + 20 > 800 { page() }
                        (String(remainder[..<end]) as NSString).draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
                        y += 17
                        remainder = remainder[end...]
                    } while !remainder.isEmpty
                }
                y += 4
            }
            page()
            if let data = settings.companyLogoData, let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 {
                let scale = min(120 / image.size.width, 60 / image.size.height)
                image.draw(in: CGRect(x: 40, y: y, width: image.size.width * scale, height: image.size.height * scale))
                y += 70
            }
            line(settings.companyName, bold: true)
            line(settings.letterheadDetails)
            line("SOLAR BAKIM TAKİP RAPORU", bold: true)
            line("Müşteri: \(record.customerName)\nKonum: \(record.locationAddress)")
            line("Kurulu güç: \(record.capacityLabel) • Panel adedi: \(record.solar?.panelCount ?? 0)")
            line("Panel: \(record.panelBrand) \(record.panelModel)\nİnverter: \(record.solar?.inverterInfo ?? "")")
            line("Bakım periyodu: \(record.checkPeriodMonths) ay • Sonraki bakım: \(record.nextCheckDate.formatted(date: .abbreviated, time: .omitted))")
            line("Açık Bulgular", bold: true)
            if record.openFindings.isEmpty { line("Kayıtlı açık bulgu yok.") }
            for item in record.openFindings { line("\(item.status.label): \(item.title) — \(item.notes)") }
            for visit in record.visits.sorted(by: { $0.date > $1.date }) {
                line("Ziyaret: \(visit.date.formatted(date: .abbreviated, time: .omitted)) • \(visit.isComplete ? "Tamamlandı" : "Taslak")", bold: true)
                line("Teknisyen: \(visit.technician)")
                for item in visit.items { line("[\(item.status.label)] \(item.title)\n\(item.notes)") }
                if let measurements = visit.solarMeasurements {
                    for row in measurements.rows { line("\(row.0): \(row.1)") }
                }
                if !visit.overallNotes.isEmpty { line("Notlar: \(visit.overallNotes)") }
                for photoID in visit.photoIDs {
                    if let image = PhotoStorageService.thumbnail(photoID: photoID, entityID: visit.id, size: CGSize(width: 480, height: 320)), image.size.width > 0, image.size.height > 0 {
                        if y + 200 > 800 { page() }
                        let scale = min(300 / image.size.width, 190 / image.size.height)
                        image.draw(in: CGRect(x: 40, y: y, width: image.size.width * scale, height: image.size.height * scale))
                        y += 200
                    }
                }
            }
        }
    }
}
