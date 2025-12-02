import Foundation
import Observation

@Observable
class DataManagementViewModel {
    var isResetting = false
    var isImporting = false
    var lastImportResult: BackupImportResult?
    var errorMessage: String?

    private let dbService: DatabaseService
    private let backupImportService: BackupImportService

    init(
        dbService: DatabaseService = .shared,
        backupImportService: BackupImportService = BackupImportService()
    ) {
        self.dbService = dbService
        self.backupImportService = backupImportService
    }

    func resetDatabase() {
        errorMessage = nil
        lastImportResult = nil
        isResetting = true

        Task { @MainActor in
            do {
                try dbService.resetDatabase()
                try dbService.initialize()
                NotificationCenter.default.post(name: .databaseDidReset, object: nil)
            } catch {
                errorMessage = error.localizedDescription
            }

            isResetting = false
        }
    }

    func importBackup(from url: URL) {
        errorMessage = nil
        lastImportResult = nil
        isImporting = true

        Task {
            do {
                let result = try await backupImportService.importBackup(from: url, resetBeforeImport: true)
                await MainActor.run {
                    self.lastImportResult = result
                    self.isImporting = false
                    NotificationCenter.default.post(name: .databaseDidReset, object: nil)
                    NotificationCenter.default.post(name: .dataImportCompleted, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isImporting = false
                    if case LifeOSDatabaseError.resetFailed = error {
                        // Reset didn't happen, so skip broadcasting the notification
                    } else {
                        NotificationCenter.default.post(name: .databaseDidReset, object: nil)
                    }
                }
            }
        }
    }
}
