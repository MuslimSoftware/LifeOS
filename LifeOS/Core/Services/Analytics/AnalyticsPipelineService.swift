import Foundation

/// Orchestrates the complete analytics pipeline
/// Coordinates chunking, embedding, analysis, and summarization
class AnalyticsPipelineService {

    // MARK: - Dependencies

    private let fileManagerService: FileManagerService
    private let ingestionService: IngestionService
    private let openAIService: OpenAIService
    private let chunkRepository: ChunkRepository
    private let analyticsRepository: EntryAnalyticsRepository
    private let entryAnalyzer: EntryAnalyzer
    private let summarizationService: SummarizationService

    init(
        fileManagerService: FileManagerService,
        ingestionService: IngestionService = IngestionService(),
        openAIService: OpenAIService = OpenAIService(),
        chunkRepository: ChunkRepository,
        analyticsRepository: EntryAnalyticsRepository,
        monthSummaryRepository: MonthSummaryRepository,
        yearSummaryRepository: YearSummaryRepository
    ) {
        self.fileManagerService = fileManagerService
        self.ingestionService = ingestionService
        self.openAIService = openAIService
        self.chunkRepository = chunkRepository
        self.analyticsRepository = analyticsRepository

        // Initialize analyzer with repositories
        self.entryAnalyzer = EntryAnalyzer(
            openAIService: openAIService,
            analyticsRepository: analyticsRepository
        )

        // Initialize summarization service
        self.summarizationService = SummarizationService(
            openAIService: openAIService,
            analyticsRepository: analyticsRepository,
            monthSummaryRepository: monthSummaryRepository,
            yearSummaryRepository: yearSummaryRepository
        )
    }

    // MARK: - Single Entry Processing

    /// Process a single journal entry through the complete pipeline
    /// - Parameter entry: The entry to process
    /// - Throws: Pipeline errors
    func processEntry(_ entry: HumanEntry) async throws {
        print("📊 Processing entry: \(entry.filename)")

        // 1. Load entry content
        guard let content = fileManagerService.loadEntry(entry) else {
            throw PipelineError.failedToLoadEntry(entry.filename)
        }

        // 2. Chunk text
        let chunks = try ingestionService.chunkEntry(entry: entry, content: content)
        print("  ✂️  Created \(chunks.count) chunks")

        // 3. Generate embeddings (batch)
        let chunkTexts = chunks.map { $0.text }
        let embeddings = try await openAIService.generateEmbeddings(for: chunkTexts)
        print("  🧠 Generated \(embeddings.count) embeddings")

        // 4. Attach embeddings to chunks
        var chunksWithEmbeddings: [JournalChunk] = []
        for (index, chunk) in chunks.enumerated() {
            let embedding = embeddings[index]
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

        // 5. Save chunks to database
        try chunkRepository.saveAll(chunksWithEmbeddings)
        print("  💾 Saved chunks to database")

        // 6. Analyze entry
        let analytics = try await entryAnalyzer.analyzeEntry(entry: entry, chunks: chunksWithEmbeddings)
        print("  📈 Analyzed entry - Happiness: \(String(format: "%.1f", analytics.happinessScore))")

        print("✅ Entry processed successfully")
    }

    // MARK: - Bulk Processing

    /// Process all journal entries
    /// - Parameter progressCallback: Called with (current, total) after each entry
    /// - Throws: Pipeline errors
    func processAllEntries(progressCallback: ((Int, Int) -> Void)? = nil) async throws {
        print("🚀 Starting bulk processing of all entries...")

        // Load all entries
        let allEntries = fileManagerService.loadExistingEntries()
        let total = allEntries.count

        print("📚 Found \(total) entries to process")

        // Process each entry
        for (index, entry) in allEntries.enumerated() {
            let current = index + 1

            do {
                try await processEntry(entry)
                progressCallback?(current, total)

                // Add small delay to avoid rate limiting
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            } catch {
                print("⚠️ Failed to process entry \(entry.filename): \(error)")
                // Continue with next entry rather than failing completely
            }
        }

        print("✅ Bulk processing complete!")
    }

    // MARK: - Summarization

    /// Update all monthly and yearly summaries
    /// Should be called after processing entries to regenerate summaries
    /// - Throws: Summarization errors
    func updateSummaries() async throws {
        print("📝 Updating summaries...")

        // Get all analytics to determine which months/years to summarize
        let allAnalytics = try analyticsRepository.getAllAnalytics()

        guard !allAnalytics.isEmpty else {
            print("⚠️ No analytics data found")
            return
        }

        // Group by year and month
        var yearMonths: Set<YearMonth> = []
        for analytics in allAnalytics {
            let calendar = Calendar.current
            let year = calendar.component(.year, from: analytics.date)
            let month = calendar.component(.month, from: analytics.date)
            yearMonths.insert(YearMonth(year: year, month: month))
        }

        // Sort chronologically
        let sortedYearMonths = yearMonths.sorted { lhs, rhs in
            if lhs.year != rhs.year {
                return lhs.year < rhs.year
            }
            return lhs.month < rhs.month
        }

        print("  📅 Found \(sortedYearMonths.count) months to summarize")

        // Summarize each month
        for yearMonth in sortedYearMonths {
            do {
                _ = try await summarizationService.summarizeMonth(
                    year: yearMonth.year,
                    month: yearMonth.month
                )
                print("  ✅ Summarized \(yearMonth.year)-\(String(format: "%02d", yearMonth.month))")

                // Add small delay
                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                print("  ⚠️ Failed to summarize \(yearMonth.year)-\(yearMonth.month): \(error)")
            }
        }

        // Summarize each year
        let years = Set(sortedYearMonths.map { $0.year }).sorted()
        print("  📆 Found \(years.count) years to summarize")

        for year in years {
            do {
                _ = try await summarizationService.summarizeYear(year: year)
                print("  ✅ Summarized year \(year)")

                try await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                print("  ⚠️ Failed to summarize year \(year): \(error)")
            }
        }

        print("✅ Summaries updated!")
    }

    // MARK: - Incremental Processing

    /// Process a newly created entry (called after user saves)
    /// Optimized for single entry with no delay
    /// - Parameter entry: The newly created entry
    func processNewEntry(_ entry: HumanEntry) async throws {
        // Process without delay
        try await processEntry(entry)

        // Optionally regenerate summaries for the month
        let calendar = Calendar.current
        let year = entry.year
        // Parse month from filename or use current month
        let month = calendar.component(.month, from: Date())

        do {
            _ = try await summarizationService.summarizeMonth(year: year, month: month)
            print("  ✅ Updated month summary")
        } catch {
            print("  ⚠️ Failed to update month summary: \(error)")
        }
    }
}

// MARK: - Helper Types

private struct YearMonth: Hashable {
    let year: Int
    let month: Int
}

// MARK: - Errors

enum PipelineError: Error, LocalizedError {
    case failedToLoadEntry(String)

    var errorDescription: String? {
        switch self {
        case .failedToLoadEntry(let filename):
            return "Failed to load entry: \(filename)"
        }
    }
}
