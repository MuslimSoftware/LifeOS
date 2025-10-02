
import AppKit
import Foundation
import UniformTypeIdentifiers

class PDFExportService {
    
    func extractTitleFromContent(_ content: String, date: String) -> String {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedContent.isEmpty {
            return "Entry \(date)"
        }
        
        let words = trimmedContent
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { word in
                word.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"'()[]{}<>"))
                    .lowercased()
            }
            .filter { !$0.isEmpty }
        
        if words.count >= 4 {
            return "\(words[0])-\(words[1])-\(words[2])-\(words[3])"
        }
        
        if !words.isEmpty {
            return words.joined(separator: "-")
        }
        
        return "Entry \(date)"
    }
    
    func exportEntryAsPDF(entry: HumanEntry, content: String, selectedFont: String, fontSize: CGFloat, lineHeight: CGFloat) {
        let suggestedFilename = extractTitleFromContent(content, date: entry.date) + ".pdf"
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.pdf]
        savePanel.nameFieldStringValue = suggestedFilename
        savePanel.isExtensionHidden = false
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            if let pdfData = createPDFFromText(
                text: content,
                selectedFont: selectedFont,
                fontSize: fontSize,
                lineHeight: lineHeight
            ) {
                do {
                    try pdfData.write(to: url)
                    print("Successfully exported PDF to: \(url.path)")
                } catch {
                    print("Error writing PDF: \(error)")
                }
            }
        }
    }
    
    private func createPDFFromText(text: String, selectedFont: String, fontSize: CGFloat, lineHeight: CGFloat) -> Data? {
        let pageWidth: CGFloat = 612.0  // 8.5 x 72
        let pageHeight: CGFloat = 792.0 // 11 x 72
        let margin: CGFloat = 72.0      // 1-inch margins
        
        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pageWidth - (margin * 2),
            height: pageHeight - (margin * 2)
        )
        
        let pdfData = NSMutableData()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineHeight
        
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let attributedString = NSAttributedString(string: trimmedText, attributes: textAttributes)
        
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: nil, nil) else {
            print("Failed to create PDF context")
            return nil
        }
        
        var currentRange = CFRange(location: 0, length: 0)
        var pageIndex = 0
        
        let framePath = CGMutablePath()
        framePath.addRect(contentRect)
        
        while currentRange.location < attributedString.length {
            pdfContext.beginPage(mediaBox: nil)
            
            pdfContext.setFillColor(NSColor.white.cgColor)
            pdfContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
            
            let frame = CTFramesetterCreateFrame(
                framesetter,
                currentRange,
                framePath,
                nil
            )
            
            CTFrameDraw(frame, pdfContext)
            
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            
            currentRange.location += visibleRange.length
            
            pdfContext.endPage()
            pageIndex += 1
            
            if pageIndex > 1000 {
                print("Safety limit reached - stopping PDF generation")
                break
            }
        }
        
        pdfContext.closePDF()
        
        return pdfData as Data
    }
}
