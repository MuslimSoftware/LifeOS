import Foundation

/// Service to recover deleted entries from database embeddings
class EntryRecoveryService {
    private let fileService: FileManagerService
    private let chunkRepo: ChunkRepository
    private let dbService: DatabaseService
    
    init(
        fileService: FileManagerService = FileManagerService(),
        chunkRepo: ChunkRepository = ChunkRepository(),
        dbService: DatabaseService = .shared
    ) {
        self.fileService = fileService
        self.chunkRepo = chunkRepo
        self.dbService = dbService
    }
    
    /// Recover a deleted entry from database embeddings
    func recoverEntry(entryId: UUID) -> Bool {
        do {
            try dbService.initialize()
            
            // Get all chunks for this entry
            let allChunks = try chunkRepo.getAllChunks()
            let entryChunks = allChunks.filter { $0.entryId == entryId }
            
            guard !entryChunks.isEmpty else {
                print("❌ No chunks found for entry: \(entryId)")
                return false
            }
            
            // Sort by start position to reconstruct original text
            let sortedChunks = entryChunks.sorted { $0.startChar < $1.startChar }
            let journalContent = sortedChunks.map { $0.text }.joined(separator: "\n\n")
            
            // Get date from first chunk
            let date = sortedChunks[0].date
            
            // Use current timezone for display date
            let calendar = Calendar.current
            let year = calendar.component(.year, from: date)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            dateFormatter.timeZone = TimeZone.current
            let displayDate = dateFormatter.string(from: date)
            
            // Create timestamp for filename using current timezone
            let timestampFormatter = DateFormatter()
            timestampFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            timestampFormatter.timeZone = TimeZone.current
            let timestamp = timestampFormatter.string(from: date)
            
            // Build file content
            let content = """
            ---
            date: \(displayDate)
            year: \(year)
            ---
            
            ## Notes
            
            
            ## TODOs
            
            
            ## Journal
            \(journalContent)
            """
            
            // Create HumanEntry
            let filename = "[\(entryId.uuidString)]-[\(timestamp)].md"
            let entry = HumanEntry(
                id: entryId,
                date: displayDate,
                filename: filename,
                previewText: "",
                year: year
            )
            
            // Save the entry
            fileService.saveEntry(entry, content: content)
            
            print("✅ Recovered entry: \(filename)")
            return true
            
        } catch {
            print("❌ Failed to recover entry: \(error)")
            return false
        }
    }
}
