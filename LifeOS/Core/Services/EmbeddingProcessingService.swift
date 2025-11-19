import Foundation
import Combine

/// Shared service for processing journal entries into embeddings
@MainActor
class EmbeddingProcessingService: ObservableObject {
    static let shared = EmbeddingProcessingService()

    @Published var totalEntries: Int = 0
    @Published var processedEntries: Int = 0
    @Published var isProcessing: Bool = false
    @Published var currentEntryIndex: Int = 0

    private var processingTask: Task<Void, Never>?

    private let fileService: FileManagerService
    private let openAI: OpenAIService
    private let chunkRepo: ChunkRepository
    private let dbService: DatabaseService

    private init(
        fileService: FileManagerService = FileManagerService(),
        openAI: OpenAIService = OpenAIService(),
        dbService: DatabaseService = .shared
    ) {
        self.fileService = fileService
        self.openAI = openAI
        self.dbService = dbService
        self.chunkRepo = ChunkRepository(dbService: dbService)
    }

    /// Load statistics about total and processed entries
    func loadStats() {
        totalEntries = fileService.loadExistingEntries().count

        do {
            try dbService.initialize()

            // Count unique entry IDs that have embeddings
            let allChunks = try chunkRepo.getAllChunks()
            let uniqueEntryIds = Set(allChunks.map { $0.entryId })
            processedEntries = uniqueEntryIds.count
        } catch {
            print("⚠️ Failed to load embeddings stats: \(error)")
            processedEntries = 0
        }
    }

    /// Process all unprocessed journal entries
    func processAllEntries() {
        processingTask = Task { @MainActor in
            isProcessing = true
            currentEntryIndex = 0
            defer {
                isProcessing = false
                currentEntryIndex = 0
            }

            do {
                try dbService.initialize()

                let allEntries = fileService.loadExistingEntries()
                totalEntries = allEntries.count

                // Filter out already-processed entries
                var entriesToProcess: [HumanEntry] = []
                for entry in allEntries {
                    if try !chunkRepo.hasChunksForEntry(entryId: entry.id) {
                        entriesToProcess.append(entry)
                    }
                }

                print("📊 Processing \(entriesToProcess.count) new entries (out of \(totalEntries) total)...")

                // Process each entry
                for (index, entry) in entriesToProcess.enumerated() {
                    // Check for cancellation
                    if Task.isCancelled {
                        print("⚠️ Processing cancelled by user")
                        break
                    }

                    currentEntryIndex = index + 1

                    // Load entry content
                    guard let content = fileService.loadEntry(entry) else {
                        print("⚠️ Failed to load content for entry: \(entry.id)")
                        continue
                    }

                    // Skip empty entries
                    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        continue
                    }

                    // Chunk the text
                    let chunks = chunkText(content, entryId: entry.id, entryDate: parseEntryDate(entry))

                    // Generate embeddings for each chunk
                    var chunksWithEmbeddings: [JournalChunk] = []
                    for chunk in chunks {
                        if Task.isCancelled { break }

                        let embedding = try await openAI.generateEmbedding(for: chunk.text)
                        let chunkWithEmbedding = JournalChunk(
                            id: chunk.id,
                            entryId: chunk.entryId,
                            text: chunk.text,
                            embedding: embedding,
                            startChar: chunk.startChar,
                            endChar: chunk.endChar,
                            date: chunk.date,
                            tokenCount: chunk.tokenCount
                        )
                        chunksWithEmbeddings.append(chunkWithEmbedding)
                    }

                    // Save chunks to database
                    if !chunksWithEmbeddings.isEmpty {
                        try chunkRepo.saveBatch(chunksWithEmbeddings)
                        print("✅ Processed entry \(index + 1)/\(entriesToProcess.count): \(chunksWithEmbeddings.count) chunks")
                    }

                    // Update processed count
                    processedEntries += 1
                }

                print("✅ Processing complete! Processed \(entriesToProcess.count) entries")
                loadStats() // Refresh final stats

            } catch {
                print("❌ Failed to process entries: \(error)")
            }
        }
    }

    /// Cancel the current processing task
    func cancelProcessing() {
        processingTask?.cancel()
        processingTask = nil
    }

    // MARK: - Private Helpers

    /// Chunk text into segments (simple paragraph-based splitting)
    private func chunkText(_ text: String, entryId: UUID, entryDate: Date) -> [JournalChunk] {
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var chunks: [JournalChunk] = []
        var currentChunk = ""
        var currentStartChar = 0

        for paragraph in paragraphs {
            let potentialChunk = currentChunk.isEmpty ? paragraph : currentChunk + "\n\n" + paragraph
            let tokenCount = estimateTokenCount(potentialChunk)

            // If adding this paragraph would exceed 1000 tokens, save current chunk and start new one
            if tokenCount > 1000 && !currentChunk.isEmpty {
                let chunk = JournalChunk(
                    entryId: entryId,
                    text: currentChunk,
                    embedding: nil,
                    startChar: currentStartChar,
                    endChar: currentStartChar + currentChunk.count,
                    date: entryDate,
                    tokenCount: estimateTokenCount(currentChunk)
                )
                chunks.append(chunk)

                currentStartChar += currentChunk.count + 2 // +2 for "\n\n"
                currentChunk = paragraph
            } else {
                currentChunk = potentialChunk
            }
        }

        // Add remaining chunk
        if !currentChunk.isEmpty {
            let chunk = JournalChunk(
                entryId: entryId,
                text: currentChunk,
                embedding: nil,
                startChar: currentStartChar,
                endChar: currentStartChar + currentChunk.count,
                date: entryDate,
                tokenCount: estimateTokenCount(currentChunk)
            )
            chunks.append(chunk)
        }

        return chunks
    }

    /// Estimate token count (rough approximation: ~4 chars per token)
    private func estimateTokenCount(_ text: String) -> Int {
        return text.count / 4
    }

    /// Parse entry date from HumanEntry
    private func parseEntryDate(_ entry: HumanEntry) -> Date {
        // Extract date from filename format: [UUID]-[yyyy-MM-dd-HH-mm-ss].md
        // We need to extract just the second bracketed section
        let filename = entry.filename

        // Find the second occurrence of brackets
        if let secondBracketStart = filename.range(of: "]-["),
           let closingBracket = filename.range(of: "].md") {
            let startIndex = filename.index(secondBracketStart.upperBound, offsetBy: 0)
            let endIndex = closingBracket.lowerBound
            let dateString = String(filename[startIndex..<endIndex])

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            formatter.timeZone = TimeZone.current
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        // Fallback to current date
        return Date()
    }
}
