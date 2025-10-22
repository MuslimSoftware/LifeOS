import Foundation
import AppKit

protocol OCRServiceProtocol {
    func extractText(from image: NSImage) async throws -> ExtractedContent
}
