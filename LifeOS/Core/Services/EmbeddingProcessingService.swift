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

    private let entryRepo: EntryRepository
    private let openAI: OpenAIService
    private let chunkRepo: ChunkRepository
    private let dbService: DatabaseService

    private init(
        entryRepo: EntryRepository = EntryRepository(),
        openAI: OpenAIService = OpenAIService(),
        dbService: DatabaseService = .shared
    ) {
        self.entryRepo = entryRepo
        self.openAI = openAI
        self.dbService = dbService
        self.chunkRepo = ChunkRepository(dbService: dbService)
    }

    /// Load statistics about total and processed entries
    func loadStats() {
        do {
            try dbService.initialize()

            let existingEntries = try entryRepo.getAllEntries()
            totalEntries = existingEntries.count

            let allChunks = try chunkRepo.getAllChunks()
            let uniqueEntryIds = Set(allChunks.map { $0.entryId })
            let existingEntryIds = Set(existingEntries.map { $0.id })

            processedEntries = uniqueEntryIds.intersection(existingEntryIds).count
        } catch {
            print("⚠️ Failed to load embeddings stats: \(error)")
            totalEntries = 0
            processedEntries = 0
        }
    }

    /// Process all unprocessed journal entries
    func processAllEntries() {
        processingTask = Task { @MainActor in
            print("🔄 Setting isProcessing = true")
            self.isProcessing = true
            self.currentEntryIndex = 0
            self.objectWillChange.send()
            defer {
                print("🔄 Setting isProcessing = false")
                self.isProcessing = false
                self.currentEntryIndex = 0
                self.objectWillChange.send()
            }

            do {
                try dbService.initialize()

                let allEntries = try entryRepo.getAllEntries()
                totalEntries = allEntries.count

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

                    self.currentEntryIndex = index + 1
                    print("📈 Progress: \(self.currentEntryIndex)/\(entriesToProcess.count)")
                    self.objectWillChange.send()

                    let content = entry.journalText

                    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        print("⚠️ Skipping entry with empty journal section: \(entry.id)")
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
                        processedEntries += 1
                        self.objectWillChange.send()
                    }
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

    /// Clean up orphaned entries (entries in database but not in repository)
    /// Also cleans up chunks for entries with empty journal sections
    func cleanupOrphanedEntries() {
        do {
            try dbService.initialize()

            let existingEntries = try entryRepo.getAllEntries()
            let existingIds = Set(existingEntries.map { $0.id })

            let allChunks = try chunkRepo.getAllChunks()
            let chunkEntryIds = Set(allChunks.map { $0.entryId })

            let orphanedIds = chunkEntryIds.subtracting(existingIds)

            if !orphanedIds.isEmpty {
                print("🔍 Found \(orphanedIds.count) orphaned chunks in database")

                for orphanedId in orphanedIds {
                    try? chunkRepo.deleteChunks(forEntryId: orphanedId)
                    print("🗑️ Removed embeddings for deleted entry: \(orphanedId)")
                }
            }

            print("🔍 Checking for chunks from entries with empty journal sections...")
            let emptyJournalCleanupCount = try chunkRepo.deleteChunksForEmptyJournalEntries(validEntryIds: existingIds)
            if emptyJournalCleanupCount > 0 {
                print("✅ Cleaned up \(emptyJournalCleanupCount) entries with empty journal sections")
            }

            loadStats()
        } catch {
            print("⚠️ Failed to cleanup orphaned entries: \(error)")
        }
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
        return entry.createdAt
    }
}
