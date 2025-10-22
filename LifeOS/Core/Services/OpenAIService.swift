import Foundation
import AppKit

struct ExtractedContent: Codable {
    let text: String
    let date: String?
}

enum OpenAIError: Error, LocalizedError {
    case noAPIKey
    case imageConversionFailed
    case noResponse
    case invalidResponse
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key found. Please add your OpenAI API key in Settings."
        case .imageConversionFailed:
            return "Failed to convert image for processing."
        case .noResponse:
            return "No response from OpenAI API."
        case .invalidResponse:
            return "Invalid response format from API."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

class OpenAIService: OCRServiceProtocol {
    private let apiKeyStorage: APIKeyStorageProtocol
    private let apiURL = "https://api.openai.com/v1/chat/completions"

    init(apiKeyStorage: APIKeyStorageProtocol = KeychainService.shared) {
        self.apiKeyStorage = apiKeyStorage
    }

    private func getAPIKey() throws -> String {
        // KeychainService now handles caching internally
        guard let key = apiKeyStorage.getAPIKey() else {
            throw OpenAIError.noAPIKey
        }

        return key
    }
    
    func extractText(from image: NSImage) async throws -> ExtractedContent {
        let apiKey = try getAPIKey()

        guard let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw OpenAIError.imageConversionFailed
        }

        let base64Image = pngData.base64EncodedString()

        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are an OCR assistant extracting text from journal entries. 
                    Extract ALL text exactly as it appears, preserving formatting and line breaks.
                    Also detect any dates mentioned in the text.
                    
                    Respond ONLY with valid JSON in this exact format:
                    {"text": "extracted text here", "date": "YYYY-MM-DD or null"}
                    """
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Extract all text from this image and detect any dates. Return as JSON with 'text' and 'date' fields."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 4096,
            "response_format": ["type": "json_object"]
        ]

        guard let url = URL(string: apiURL) else {
            throw OpenAIError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw OpenAIError.networkError("Status \(httpResponse.statusCode): \(errorMessage)")
            }
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.noResponse
        }

        print("📄 Response content preview: \(String(content.prefix(200)))...")
        
        guard let contentData = content.data(using: .utf8),
              let extracted = try? JSONDecoder().decode(ExtractedContent.self, from: contentData) else {
            print("❌ Failed to parse JSON response")
            throw OpenAIError.invalidResponse
        }
        
        print("✅ Successfully extracted \(extracted.text.count) characters")
        return extracted
    }
}
