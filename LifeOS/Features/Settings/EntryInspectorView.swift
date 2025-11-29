import SwiftUI

struct EntryFileInfo: Identifiable {
    let id: UUID
    let filename: String
    let fileDate: Date
    let fileSize: Int64
    let lastModified: Date
    var decryptedContent: String?
    var journalSection: String?
    var hasEmbeddings: Bool
    var errorMessage: String?
}

struct EntryInspectorView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [EntryFileInfo] = []
    @State private var isLoading: Bool = true
    @State private var selectedEntry: EntryFileInfo?
    @State private var showDeleteConfirmation: Bool = false
    @State private var entryToDelete: EntryFileInfo?
    @State private var filterText: String = ""

    private let fileService = FileManagerService()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Entry Inspector")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Divider()
                .background(theme.dividerColor)

            // Filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.secondaryText)
                TextField("Filter by date (e.g., 2025-11-18)...", text: $filterText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(theme.surfaceColor)
            .cornerRadius(6)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            // Content
            HSplitView {
                // Left: Entry list
                entryListView
                    .frame(minWidth: 300, idealWidth: 400)

                // Right: Entry details
                if let selected = selectedEntry {
                    entryDetailView(for: selected)
                        .frame(minWidth: 400)
                } else {
                    placeholderView
                        .frame(minWidth: 400)
                }
            }
        }
        .frame(width: 1200, height: 800)
        .background(theme.backgroundColor)
        .onAppear {
            loadEntries()
        }
        .alert("Delete Entry File?", isPresented: $showDeleteConfirmation, presenting: entryToDelete) { entry in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEntry(entry)
            }
        } message: { entry in
            Text("This will permanently delete the file '\(entry.filename)'. This action cannot be undone.")
        }
    }

    private var entryListView: some View {
        VStack(spacing: 0) {
            // List header
            HStack {
                Text("\(filteredEntries.count) entries")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                Spacer()

                Button(action: { loadEntries() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(theme.accentColor)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.surfaceColor)

            Divider()
                .background(theme.dividerColor)

            // Entry list
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading entries...")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if filteredEntries.isEmpty {
                VStack {
                    Spacer()
                    Text(filterText.isEmpty ? "No entries found" : "No matching entries")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredEntries) { entry in
                            entryRow(for: entry)
                        }
                    }
                }
            }
        }
        .background(theme.backgroundColor)
    }

    private func entryRow(for entry: EntryFileInfo) -> some View {
        Button(action: {
            selectedEntry = entry
            loadEntryContent(entry)
        }) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(entry.hasEmbeddings ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDate(entry.fileDate))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.primaryText)

                    HStack(spacing: 8) {
                        Text("\(formatFileSize(entry.fileSize))")
                            .font(.system(size: 11))
                            .foregroundColor(theme.tertiaryText)

                        if !entry.hasEmbeddings {
                            Text("No embeddings")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selectedEntry?.id == entry.id ? theme.selectedBackground : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private func entryDetailView(for entry: EntryFileInfo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with actions
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(entry.fileDate))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        Text("ID: \(entry.id.uuidString)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(theme.tertiaryText)
                    }

                    Spacer()

                    Button(action: {
                        entryToDelete = entry
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(theme.destructive)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .padding(8)
                    .background(theme.hoveredBackground)
                    .cornerRadius(6)
                }

                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Text("Metadata")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    metadataRow(label: "Filename", value: entry.filename)
                    metadataRow(label: "File Size", value: formatFileSize(entry.fileSize))
                    metadataRow(label: "Last Modified", value: formatDateTime(entry.lastModified))
                    metadataRow(label: "Has Embeddings", value: entry.hasEmbeddings ? "Yes" : "No")
                }
                .padding(12)
                .background(theme.surfaceColor)
                .cornerRadius(8)

                // Decrypted content
                if let content = entry.decryptedContent {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Decrypted Content (\(content.count) chars)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(content)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(theme.primaryText)
                                .textSelection(.enabled)
                                .padding(12)
                        }
                        .frame(maxHeight: 200)
                        .background(theme.surfaceColor)
                        .cornerRadius(8)
                    }
                } else if let error = entry.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Decryption Error")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.destructive)

                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(theme.destructive)
                            .padding(12)
                            .background(theme.destructive.opacity(0.1))
                            .cornerRadius(8)
                    }
                } else {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Decrypting...")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                    }
                }

                // Journal section
                if let journalContent = entry.journalSection {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted Journal Section (\(journalContent.count) chars)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        if journalContent.isEmpty {
                            Text("Empty journal section")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            ScrollView(.horizontal, showsIndicators: true) {
                                Text(journalContent)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(theme.primaryText)
                                    .textSelection(.enabled)
                                    .padding(12)
                            }
                            .frame(maxHeight: 200)
                            .background(theme.surfaceColor)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(theme.backgroundColor)
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(theme.tertiaryText)

            Text("Select an entry to inspect")
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundColor)
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.primaryText)
                .textSelection(.enabled)
        }
    }

    private var filteredEntries: [EntryFileInfo] {
        if filterText.isEmpty {
            return entries
        }
        return entries.filter { entry in
            entry.filename.localizedCaseInsensitiveContains(filterText) ||
            formatDate(entry.fileDate).localizedCaseInsensitiveContains(filterText)
        }
    }

    // MARK: - Data Loading

    private func loadEntries() {
        isLoading = true
        entries = []

        Task { @MainActor in
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let lifeOSPath = documentsPath.appendingPathComponent("LifeOS")

            guard let files = try? FileManager.default.contentsOfDirectory(
                at: lifeOSPath,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                isLoading = false
                return
            }

            // Filter for .md files
            let mdFiles = files.filter { $0.pathExtension == "md" }

            // Parse files and check embeddings
            let dbService = DatabaseService.shared
            try? dbService.initialize()
            let chunkRepo = ChunkRepository(dbService: dbService)

            var fileInfos: [EntryFileInfo] = []

            for file in mdFiles {
                // Parse filename: [UUID]-[yyyy-MM-dd-HH-mm-ss].md
                let filename = file.lastPathComponent
                let components = filename.replacingOccurrences(of: ".md", with: "")
                    .components(separatedBy: "]-[")

                guard components.count == 2,
                      let uuidString = components.first?.replacingOccurrences(of: "[", with: ""),
                      let uuid = UUID(uuidString: uuidString),
                      let dateString = components.last?.replacingOccurrences(of: "]", with: "") else {
                    continue
                }

                // Parse date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
                guard let fileDate = dateFormatter.date(from: dateString) else {
                    continue
                }

                // Get file attributes
                let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
                let fileSize = (attributes?[.size] as? Int64) ?? 0
                let lastModified = (attributes?[.modificationDate] as? Date) ?? Date()

                // Check if has embeddings
                let hasEmbeddings = (try? chunkRepo.hasChunksForEntry(entryId: uuid)) ?? false

                let info = EntryFileInfo(
                    id: uuid,
                    filename: filename,
                    fileDate: fileDate,
                    fileSize: fileSize,
                    lastModified: lastModified,
                    hasEmbeddings: hasEmbeddings
                )

                fileInfos.append(info)
            }

            // Sort by file date descending
            entries = fileInfos.sorted { $0.fileDate > $1.fileDate }
            isLoading = false
        }
    }

    private func loadEntryContent(_ entry: EntryFileInfo) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }

        Task { @MainActor in
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("LifeOS/\(entry.filename)")

            // Decrypt content
            guard let content = fileService.loadRawContent(from: fileURL) else {
                entries[index].errorMessage = "Failed to decrypt file"
                if let selectedIndex = entries.firstIndex(where: { $0.id == selectedEntry?.id }) {
                    selectedEntry = entries[selectedIndex]
                }
                return
            }

            entries[index].decryptedContent = content

            // Extract journal section
            let journalSection = fileService.extractJournalSection(from: content)
            entries[index].journalSection = journalSection

            // Update selected entry
            if let selectedIndex = entries.firstIndex(where: { $0.id == selectedEntry?.id }) {
                selectedEntry = entries[selectedIndex]
            }
        }
    }

    private func deleteEntry(_ entry: EntryFileInfo) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("LifeOS/\(entry.filename)")

        do {
            try FileManager.default.removeItem(at: fileURL)

            // Remove from database if exists
            let dbService = DatabaseService.shared
            try? dbService.initialize()
            let chunkRepo = ChunkRepository(dbService: dbService)
            try? chunkRepo.deleteChunks(forEntryId: entry.id)

            // Reload entries
            if selectedEntry?.id == entry.id {
                selectedEntry = nil
            }
            loadEntries()

            print("✅ Deleted entry: \(entry.filename)")
        } catch {
            print("⚠️ Failed to delete entry: \(error)")
        }
    }

    // MARK: - Formatting Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.2f MB", Double(bytes) / (1024.0 * 1024.0))
        }
    }
}

