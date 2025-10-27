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
    private let chatCompletionsURL = "https://api.openai.com/v1/chat/completions"
    private let embeddingsURL = "https://api.openai.com/v1/embeddings"

    // URLSession with longer timeout for embeddings and completions
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120 // 2 minutes
        config.timeoutIntervalForResource = 300 // 5 minutes
        return URLSession(configuration: config)
    }()

    init(apiKeyStorage: APIKeyStorageProtocol = KeychainService.shared) {
        self.apiKeyStorage = apiKeyStorage
    }

    private func getAPIKey() throws -> String {
        // Use AuthenticationManager's cached key to avoid multiple keychain accesses
        if let cachedKey = AuthenticationManager.shared.getCachedAPIKey() {
            return cachedKey
        }

        // Fallback to direct keychain access (shouldn't happen if auth flow is correct)
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

        guard let url = URL(string: chatCompletionsURL) else {
            throw OpenAIError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await urlSession.data(for: request)

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

    // MARK: - Embeddings

    /// Generate embedding vector for text using OpenAI embeddings API
    /// - Parameter text: The text to embed
    /// - Returns: Float array representing the embedding vector (3072 dimensions for text-embedding-3-large)
    func generateEmbedding(for text: String, retryCount: Int = 3) async throws -> [Float] {
        var lastError: Error?

        for attempt in 0..<retryCount {
            do {
                let apiKey = try getAPIKey()

                let payload: [String: Any] = [
                    "model": "text-embedding-3-large",
                    "input": text,
                    "encoding_format": "float"
                ]

                guard let url = URL(string: embeddingsURL) else {
                    throw OpenAIError.networkError("Invalid URL")
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                let (data, response) = try await urlSession.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    // Handle rate limiting with exponential backoff
                    if httpResponse.statusCode == 429 {
                        let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        let delay = Double(retryAfter ?? "5") ?? 5.0
                        print("⏳ Rate limited, waiting \(delay)s before retry...")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }

                    guard httpResponse.statusCode == 200 else {
                        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                        throw OpenAIError.networkError("Status \(httpResponse.statusCode): \(errorMessage)")
                    }
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataArray = json["data"] as? [[String: Any]],
                      let firstItem = dataArray.first,
                      let embedding = firstItem["embedding"] as? [Double] else {
                    throw OpenAIError.invalidResponse
                }

                // Convert Double to Float for storage efficiency
                return embedding.map { Float($0) }

            } catch {
                lastError = error

                // Check if it's a cancellation error - don't retry those
                if (error as NSError).code == NSURLErrorCancelled {
                    throw error
                }

                // Only retry on transient errors
                if attempt < retryCount - 1 {
                    let delay = pow(2.0, Double(attempt)) // Exponential backoff: 1s, 2s, 4s
                    print("⚠️ Embedding request failed (attempt \(attempt + 1)/\(retryCount)), retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    print("❌ Embedding request failed after \(retryCount) attempts")
                }
            }
        }

        throw lastError ?? OpenAIError.noResponse
    }

    /// Generate embeddings for multiple texts in batch
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Array of embedding vectors
    func generateEmbeddings(for texts: [String], retryCount: Int = 3) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }

        var lastError: Error?

        for attempt in 0..<retryCount {
            do {
                let apiKey = try getAPIKey()

                let payload: [String: Any] = [
                    "model": "text-embedding-3-large",
                    "input": texts,
                    "encoding_format": "float"
                ]

                guard let url = URL(string: embeddingsURL) else {
                    throw OpenAIError.networkError("Invalid URL")
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                let (data, response) = try await urlSession.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    // Handle rate limiting with exponential backoff
                    if httpResponse.statusCode == 429 {
                        let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        let delay = Double(retryAfter ?? "5") ?? 5.0
                        print("⏳ Rate limited on batch, waiting \(delay)s before retry...")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }

                    guard httpResponse.statusCode == 200 else {
                        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                        throw OpenAIError.networkError("Status \(httpResponse.statusCode): \(errorMessage)")
                    }
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataArray = json["data"] as? [[String: Any]] else {
                    throw OpenAIError.invalidResponse
                }

                return try dataArray.map { item in
                    guard let embedding = item["embedding"] as? [Double] else {
                        throw OpenAIError.invalidResponse
                    }
                    return embedding.map { Float($0) }
                }

            } catch {
                lastError = error

                // Check if it's a cancellation error - don't retry those
                if (error as NSError).code == NSURLErrorCancelled {
                    throw error
                }

                // Only retry on transient errors
                if attempt < retryCount - 1 {
                    let delay = pow(2.0, Double(attempt)) // Exponential backoff: 1s, 2s, 4s
                    print("⚠️ Batch embedding request failed (attempt \(attempt + 1)/\(retryCount)), retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    print("❌ Batch embedding request failed after \(retryCount) attempts")
                }
            }
        }

        throw lastError ?? OpenAIError.noResponse
    }

    // MARK: - Structured Outputs (Chat Completions)

    /// Send a chat completion request with structured output
    /// - Parameters:
    ///   - messages: Array of chat messages
    ///   - schema: JSON schema for structured output
    ///   - model: OpenAI model to use (default: gpt-4o-mini)
    /// - Returns: Decoded response matching the schema type
    func chatCompletion<T: Decodable>(
        messages: [[String: Any]],
        schema: [String: Any],
        model: String = "gpt-4o-mini"
    ) async throws -> T {
        let apiKey = try getAPIKey()

        let payload: [String: Any] = [
            "model": model,
            "messages": messages,
            "response_format": [
                "type": "json_schema",
                "json_schema": schema
            ]
        ]

        guard let url = URL(string: chatCompletionsURL) else {
            throw OpenAIError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await urlSession.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                Self.logAPIError(
                    context: "Chat Completion (Structured Output)",
                    statusCode: httpResponse.statusCode,
                    errorBody: errorMessage,
                    model: model
                )
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

        guard let contentData = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponse
        }

        return try JSONDecoder().decode(T.self, from: contentData)
    }

    /// Send a chat completion request with tool/function calling
    /// - Parameters:
    ///   - messages: Array of chat messages
    ///   - tools: Array of tool definitions
    ///   - model: OpenAI model to use
    /// - Returns: Chat response with potential tool calls
    func chatCompletionWithTools(
        messages: [[String: Any]],
        tools: [[String: Any]],
        model: String = "gpt-4o"
    ) async throws -> ChatResponse {
        let apiKey = try getAPIKey()

        let payload: [String: Any] = [
            "model": model,
            "messages": messages,
            "tools": tools
        ]

        guard let url = URL(string: chatCompletionsURL) else {
            throw OpenAIError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await urlSession.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw OpenAIError.networkError("Status \(httpResponse.statusCode): \(errorMessage)")
            }
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw OpenAIError.noResponse
        }

        // Parse tool calls if present
        var toolCalls: [ToolCall] = []
        if let toolCallsArray = message["tool_calls"] as? [[String: Any]] {
            for toolCallDict in toolCallsArray {
                if let id = toolCallDict["id"] as? String,
                   let function = toolCallDict["function"] as? [String: Any],
                   let name = function["name"] as? String,
                   let argumentsString = function["arguments"] as? String,
                   let argumentsData = argumentsString.data(using: .utf8),
                   let arguments = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] {
                    toolCalls.append(ToolCall(id: id, name: name, arguments: arguments))
                }
            }
        }

        let content = message["content"] as? String
        let finishReason = firstChoice["finish_reason"] as? String

        return ChatResponse(
            content: content,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            finishReason: finishReason
        )
    }

    // MARK: - Error Logging

    /// Log OpenAI API errors in a copy-pasteable format
    static func logAPIError(
        context: String,
        statusCode: Int,
        errorBody: String,
        model: String
    ) {
        print("\n❌ ═══════════════════════════════════════════════════════════")
        print("❌ OpenAI API Error")
        print("❌ ═══════════════════════════════════════════════════════════")
        print("❌ Context: \(context)")
        print("❌ Model: \(model)")
        print("❌ Status Code: \(statusCode)")
        print("❌ ───────────────────────────────────────────────────────────")
        print("❌ Error Response (copy-pasteable):")
        print("❌")
        print(errorBody)
        print("❌ ═══════════════════════════════════════════════════════════\n")
    }
}

// MARK: - Supporting Types

/// Represents a chat response from OpenAI
struct ChatResponse {
    let content: String?
    let toolCalls: [ToolCall]?
    let finishReason: String?

    var hasToolCalls: Bool {
        toolCalls != nil && !toolCalls!.isEmpty
    }
}

/// Represents a tool/function call from the model
struct ToolCall: Codable {
    let id: String
    let name: String
    let arguments: [String: Any]

    enum CodingKeys: String, CodingKey {
        case id, name, arguments
    }

    init(id: String, name: String, arguments: [String: Any]) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if let data = try? container.decode(Data.self, forKey: .arguments),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            arguments = dict
        } else {
            arguments = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        let data = try JSONSerialization.data(withJSONObject: arguments)
        try container.encode(data, forKey: .arguments)
    }
}
