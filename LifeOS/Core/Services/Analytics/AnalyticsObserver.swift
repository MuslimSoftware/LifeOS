//
//  AnalyticsObserver.swift
//  LifeOS
//
//  Created by Claude on 10/23/25.
//

import Foundation

/// Observes entry save events and triggers automatic analytics processing
/// Uses debouncing to avoid rate limiting when multiple entries are saved quickly
@Observable
class AnalyticsObserver {

    // MARK: - Singleton

    static let shared = AnalyticsObserver()

    // MARK: - Properties

    private var observation: NSObjectProtocol?
    private var debounceTimer: Timer?
    private var pendingEntries: Set<String> = []

    /// Whether automatic processing is enabled (user preference)
    var isAutoProcessingEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "analytics_auto_processing_enabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "analytics_auto_processing_enabled")
            print("🔄 Auto-processing \(newValue ? "enabled" : "disabled")")
        }
    }

    /// Debounce delay in seconds (wait time after last save before processing)
    private let debounceDelay: TimeInterval = 5.0

    // MARK: - Initialization

    private init() {
        // Default to enabled for new users
        if !UserDefaults.standard.bool(forKey: "analytics_auto_processing_initialized") {
            UserDefaults.standard.set(true, forKey: "analytics_auto_processing_enabled")
            UserDefaults.standard.set(true, forKey: "analytics_auto_processing_initialized")
        }
    }

    // MARK: - Lifecycle

    /// Start observing entry save notifications
    func startObserving() {
        guard observation == nil else {
            print("⚠️ AnalyticsObserver already observing")
            return
        }

        observation = NotificationCenter.default.addObserver(
            forName: .entryDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleEntrySaved(notification)
        }

        print("👁️  AnalyticsObserver started observing entry saves")
    }

    /// Stop observing entry save notifications
    func stopObserving() {
        if let observation = observation {
            NotificationCenter.default.removeObserver(observation)
            self.observation = nil
            print("🛑 AnalyticsObserver stopped observing")
        }

        debounceTimer?.invalidate()
        debounceTimer = nil
        pendingEntries.removeAll()
    }

    // MARK: - Event Handling

    private func handleEntrySaved(_ notification: Notification) {
        guard isAutoProcessingEnabled else {
            print("⏭️  Auto-processing disabled, skipping entry processing")
            return
        }

        guard let entry = notification.userInfo?["entry"] as? HumanEntry else {
            print("⚠️ Entry save notification missing entry data")
            return
        }

        print("📝 Entry saved: \(entry.filename)")

        // Add to pending entries
        pendingEntries.insert(entry.id.uuidString)

        // Cancel existing timer and start new one
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: debounceDelay,
            repeats: false
        ) { [weak self] _ in
            self?.processPendingEntries()
        }

        print("⏳ Debouncing... will process in \(Int(debounceDelay))s")
    }

    private func processPendingEntries() {
        guard !pendingEntries.isEmpty else { return }

        let count = pendingEntries.count
        print("🚀 Processing \(count) pending entr\(count == 1 ? "y" : "ies")...")

        // Clear pending entries
        let entriesToProcess = pendingEntries
        pendingEntries.removeAll()

        // Process in background
        Task {
            await self.processEntries(entryIds: entriesToProcess)
        }
    }

    private func processEntries(entryIds: Set<String>) async {
        do {
            // Initialize services
            let fileService = FileManagerService()
            let dbService = DatabaseService.shared
            try dbService.initialize()

            let chunkRepo = ChunkRepository(dbService: dbService)
            let analyticsRepo = EntryAnalyticsRepository(dbService: dbService)
            let monthSummaryRepo = MonthSummaryRepository(dbService: dbService)
            let yearSummaryRepo = YearSummaryRepository(dbService: dbService)

            let pipeline = AnalyticsPipelineService(
                fileManagerService: fileService,
                chunkRepository: chunkRepo,
                analyticsRepository: analyticsRepo,
                monthSummaryRepository: monthSummaryRepo,
                yearSummaryRepository: yearSummaryRepo
            )

            // Load and process each entry
            let allEntries = fileService.loadExistingEntries()
            let entriesToProcess = allEntries.filter { entryIds.contains($0.id.uuidString) }

            print("📊 Processing \(entriesToProcess.count) entries automatically...")

            for entry in entriesToProcess {
                do {
                    try await pipeline.processNewEntry(entry)
                    print("✅ Processed: \(entry.filename)")
                } catch {
                    print("⚠️ Failed to process \(entry.filename): \(error)")
                }

                // Small delay between entries
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }

            print("✅ Automatic processing complete!")

            // Post notification that processing is complete
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .analyticsDidUpdate,
                    object: nil,
                    userInfo: ["entriesProcessed": entriesToProcess.count]
                )
            }

        } catch {
            print("❌ Automatic processing failed: \(error)")
        }
    }

    // MARK: - Manual Processing

    /// Manually process a specific entry (bypasses debouncing)
    /// - Parameter entry: The entry to process
    func processImmediately(_ entry: HumanEntry) async {
        print("⚡️ Processing entry immediately: \(entry.filename)")
        await processEntries(entryIds: [entry.id.uuidString])
    }

    /// Force process all pending entries now (bypasses debounce timer)
    func flushPendingEntries() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        processPendingEntries()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when an entry is saved
    /// UserInfo contains "entry" key with HumanEntry object
    static let entryDidSave = Notification.Name("entryDidSave")

    /// Posted when analytics processing completes
    /// UserInfo contains "entriesProcessed" key with Int count
    static let analyticsDidUpdate = Notification.Name("analyticsDidUpdate")
}
