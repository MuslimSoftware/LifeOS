import SwiftUI

enum SettingsSection: String, CaseIterable {
    case appearance = "Appearance"
    case openai = "OpenAI API"
    case backup = "Data Backup"
    case embeddings = "Embeddings"
}

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var apiKey: String = ""
    @State private var isKeyStored: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String?
    @State private var exportMessage: String?
    @State private var importKeyText: String = ""
    @State private var showImportField: Bool = false
    @State private var selectedSection: SettingsSection = .appearance
    @State private var hoveredSection: SettingsSection?
    // @State private var showProcessingSheet: Bool = false  // REMOVED: analytics
    @State private var isProcessing: Bool = false
    @State private var totalEntries: Int = 0
    @State private var entriesWithEmbeddings: Int = 0
    @State private var dbSize: String = "0"
    @State private var lastProcessedDate: Date?
    @State private var showClearConfirmation: Bool = false
    // @State private var autoProcessingEnabled: Bool = false  // REMOVED: analytics
    @State private var maxTokensPerRequest: Int = {
        let stored = UserDefaults.standard.integer(forKey: TokenBudgetManager.maxTokensKey)
        return stored > 0 ? stored : TokenBudgetManager.defaultMaxTokens
    }()

    private let fileService = FileManagerService()
    private let authManager = AuthenticationManager.shared

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()
                .background(theme.dividerColor)

            mainContent
        }
        .frame(width: 750, height: 650)
        .background(theme.backgroundColor)
        .onAppear {
            // Use cached auth state instead of triggering another keychain access
            isKeyStored = authManager.isAuthenticated
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
                .frame(height: 24)

            ForEach(SettingsSection.allCases, id: \.self) { section in
                Button(action: {
                    selectedSection = section
                }) {
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: selectedSection == section ? .semibold : .regular))
                        .foregroundColor(textColorFor(section))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(backgroundColorFor(section))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .onHover { hovering in
                    hoveredSection = hovering ? section : nil
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(width: 160)
        .background(theme.surfaceColor)
    }

    private func backgroundColorFor(_ section: SettingsSection) -> Color {
        if selectedSection == section {
            return theme.selectedBackground
        } else if hoveredSection == section {
            return theme.hoveredBackground
        }
        return Color.clear
    }

    private func textColorFor(_ section: SettingsSection) -> Color {
        if selectedSection == section || hoveredSection == section {
            return theme.buttonTextHover
        }
        return theme.buttonText
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Settings")
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
                .padding(.top, 24)
                .padding(.bottom, 20)

                Divider()
                    .background(theme.dividerColor)
                    .padding(.horizontal, 24)

                switch selectedSection {
                case .appearance:
                    appearanceSection
                case .openai:
                    openAISection
                case .backup:
                    backupSection
                case .embeddings:
                    embeddingsSection
                }
            }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text("Choose the appearance for LifeOS.")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.primaryText)

                HStack(spacing: 16) {
                    // Light theme button
                    VStack(spacing: 8) {
                        Text("Light")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primaryText)
                        
                        Button(action: {
                            settings.setTheme(.light)
                        }) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .frame(width: 120, height: 80)
                                .overlay {
                                    if settings.colorScheme == .light {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(theme.accentColor, lineWidth: 3)
                                    }
                                }
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                    
                    // Dark theme button
                    VStack(spacing: 8) {
                        Text("Dark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primaryText)
                        
                        Button(action: {
                            settings.setTheme(.dark)
                        }) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                                .frame(width: 120, height: 80)
                                .overlay {
                                    if settings.colorScheme == .dark {
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(theme.accentColor, lineWidth: 3)
                                    }
                                }
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                    
                    // System theme button
                    VStack(spacing: 8) {
                        Text("System")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primaryText)
                        
                        Button(action: {
                            settings.setTheme(nil)
                        }) {
                            HStack(spacing: 0) {
                                // Left half - Light
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 80)
                                
                                // Right half - Dark
                                Rectangle()
                                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                                    .frame(width: 60, height: 80)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                if settings.colorScheme == nil {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(theme.accentColor, lineWidth: 3)
                                }
                            }
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                }
            }
            .padding(12)
            .background(theme.hoveredBackground)
            .cornerRadius(8)

            Spacer()
        }
        .padding(24)
    }

    private var openAISection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("OpenAI API Key")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text("Your API key is stored securely in the macOS Keychain and never leaves your device except to make API requests to OpenAI.")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                if isKeyStored {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text("API Key is configured")
                            .foregroundColor(theme.secondaryText)
                        
                        Spacer()
                        
                        Button("Remove") {
                            removeAPIKey()
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .foregroundColor(theme.destructive)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.hoveredBackground)
                        .cornerRadius(4)
                    }
                    .padding(12)
                    .background(theme.accentColor.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("sk-...", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                        
                        Button("Save API Key") {
                            saveAPIKey()
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(apiKey.isEmpty ? theme.dividerColor : theme.accentColor)
                        .cornerRadius(6)
                        .disabled(apiKey.isEmpty)
                    }
                }
            }
            
            if showSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("API key saved successfully")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
            
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.destructive)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(theme.destructive)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Get your API key")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.primaryText)

                Text("1. Visit platform.openai.com/api-keys")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)

                Text("2. Create a new secret key")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)

                Text("3. Copy and paste it above")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)

                Button("Open OpenAI Platform →") {
                    NSWorkspace.shared.open(URL(string: "https://platform.openai.com/api-keys")!)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(theme.accentColor)
                .padding(.top, 4)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Privacy & Cost")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                Text("• Images are sent to OpenAI's servers for processing")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                Text("• Estimated cost: ~$0.01-0.02 per image")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                Text("• OpenAI states API data is not used for training")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(12)
            .background(theme.hoveredBackground)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 12) {
                Text("AI Analysis Settings")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.primaryText)

                Text("Maximum tokens per request. Lower this if you encounter rate limit errors. Default is 30,000 (suitable for most OpenAI orgs).")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    TextField("30000", value: $maxTokensPerRequest, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onChange(of: maxTokensPerRequest) { _, newValue in
                            // Clamp to reasonable range
                            let clamped = max(5000, min(200000, newValue))
                            if clamped != newValue {
                                maxTokensPerRequest = clamped
                            }
                            UserDefaults.standard.set(clamped, forKey: TokenBudgetManager.maxTokensKey)
                        }

                    Text("tokens")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)

                    Spacer()

                    Button("Reset to Default") {
                        maxTokensPerRequest = TokenBudgetManager.defaultMaxTokens
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .font(.system(size: 11))
                    .foregroundColor(theme.accentColor)
                }
            }
            .padding(12)
            .background(theme.hoveredBackground)
            .cornerRadius(8)
        }
        .padding(24)
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Data Backup & Recovery")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text("Export your encryption key and journal entries for backup or migration to a new device.")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button("Export Encryption Key") {
                        exportEncryptionKey()
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.accentColor)
                    .cornerRadius(6)

                    Button("Export All Entries (Plaintext)") {
                        exportAllEntries()
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.accentColor)
                    .cornerRadius(6)
                }

                Button("Import Encryption Key") {
                    showImportField = true
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.hoveredBackground)
                .cornerRadius(6)

                if showImportField {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import Encryption Key")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.primaryText)

                        TextField("Paste encryption key here...", text: $importKeyText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))

                        HStack(spacing: 8) {
                            Button("Import Key") {
                                importEncryptionKey()
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(importKeyText.isEmpty ? theme.dividerColor : theme.accentColor)
                            .cornerRadius(4)
                            .disabled(importKeyText.isEmpty)

                            Button("Cancel") {
                                showImportField = false
                                importKeyText = ""
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .foregroundColor(theme.secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(12)
                    .background(theme.hoveredBackground)
                    .cornerRadius(8)
                }
            }

            if let message = exportMessage {
                HStack {
                    Image(systemName: message.contains("Success") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(message.contains("Success") ? .green : theme.destructive)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(message.contains("Success") ? .green : theme.destructive)
                }
            }
        }
        .padding(24)
    }
    
    private func saveAPIKey() {
        errorMessage = nil
        showSuccess = false

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            errorMessage = "Please enter an API key"
            return
        }

        guard trimmedKey.hasPrefix("sk-") else {
            errorMessage = "Invalid API key format. OpenAI keys start with 'sk-'"
            return
        }

        guard trimmedKey.count > 20 else {
            errorMessage = "API key appears too short. Please check and try again."
            return
        }

        // Use AuthenticationManager to save and cache the key
        if authManager.saveAPIKey(trimmedKey) {
            isKeyStored = true
            showSuccess = true
            apiKey = ""

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSuccess = false
            }
        } else {
            errorMessage = authManager.authenticationError ?? "Failed to save API key to Keychain"
        }
    }

    private func removeAPIKey() {
        // Use AuthenticationManager to remove the key
        if authManager.removeAPIKey() {
            isKeyStored = false
            showSuccess = false
            errorMessage = nil
        } else {
            errorMessage = "Failed to remove API key"
        }
    }

    private func exportEncryptionKey() {
        exportMessage = nil

        guard let keyString = KeychainService.shared.exportEncryptionKey() else {
            exportMessage = "Error: Could not export encryption key"
            return
        }

        let savePanel = NSSavePanel()
        savePanel.title = "Export Encryption Key"
        savePanel.message = "Save your encryption key to a secure location"
        savePanel.nameFieldStringValue = "lifeos-encryption-key.txt"
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try keyString.write(to: url, atomically: true, encoding: .utf8)
                    exportMessage = "Success: Encryption key exported to \(url.lastPathComponent)"

                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        exportMessage = nil
                    }
                } catch {
                    exportMessage = "Error: Failed to save key file - \(error.localizedDescription)"
                }
            }
        }
    }

    private func exportAllEntries() {
        exportMessage = nil

        let savePanel = NSSavePanel()
        savePanel.title = "Export All Entries (Plaintext)"
        savePanel.message = "Choose where to save the decrypted entries"
        savePanel.nameFieldStringValue = "lifeos-export-\(Int(Date().timeIntervalSince1970)).zip"
        savePanel.allowedContentTypes = [.zip]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                if fileService.exportAllEntriesPlaintext(to: url) {
                    exportMessage = "Success: All entries exported to \(url.lastPathComponent)"

                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        exportMessage = nil
                    }
                } else {
                    exportMessage = "Error: Failed to export entries"
                }
            }
        }
    }

    private func importEncryptionKey() {
        exportMessage = nil

        let trimmedKey = importKeyText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            exportMessage = "Error: Please paste an encryption key"
            return
        }

        if KeychainService.shared.importEncryptionKey(base64String: trimmedKey) {
            exportMessage = "Success: Encryption key imported"
            showImportField = false
            importKeyText = ""

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                exportMessage = nil
            }
        } else {
            exportMessage = "Error: Invalid encryption key format"
        }
    }

    private var embeddingsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("AI Chat Embeddings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text("Process your journal entries to enable AI chat semantic search. Each entry is converted into embeddings (vector representations) that allow the AI to understand and search through your journal content.")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Storage Information")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.primaryText)

                HStack {
                    Text("Total Entries:")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                    Text("\(totalEntries)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primaryText)
                }

                HStack {
                    Text("Entries with Embeddings:")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                    Text("\(entriesWithEmbeddings) (\(embeddingsPercentage)%)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primaryText)
                }

                HStack {
                    Text("Database Size:")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                    Text("\(dbSize) MB")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primaryText)
                }
            }
            .padding(12)
            .background(theme.hoveredBackground)
            .cornerRadius(8)

            // Actions
            VStack(alignment: .leading, spacing: 12) {
                Button("Process All Entries") {
                    processAllEntries()
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isProcessing ? theme.dividerColor : theme.accentColor)
                .cornerRadius(6)
                .disabled(isProcessing)

                Button("Clear Embeddings Database") {
                    showClearConfirmation = true
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.hoveredBackground)
                .cornerRadius(6)
            }
        }
        .onAppear {
            loadEmbeddingsStats()
        }
        .alert("Clear Embeddings Database?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearEmbeddings()
            }
        } message: {
            Text("This will delete all embeddings. You can regenerate them by processing entries again.")
        }
    }

    /* REMOVED analytics section OLD
    private var analyticsSection_OLD: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Analytics & AI")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text("Process your journal entries to enable AI-powered insights and analytics.")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                // Auto-processing toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-Process New Entries")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primaryText)

                        Text("Automatically analyze entries when saved")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryText)
                    }

                    Spacer()

                    Toggle("", isOn: $autoProcessingEnabled)
                        .labelsHidden()
                        .onChange(of: autoProcessingEnabled) { _, newValue in
                            AnalyticsObserver.shared.isAutoProcessingEnabled = newValue
                        }
                }
                .padding(12)
                .background(theme.hoveredBackground)
                .cornerRadius(8)

                Button("Process All Entries") {
                    showProcessingSheet = true
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isProcessing ? theme.dividerColor : theme.accentColor)
                .cornerRadius(6)
                .disabled(isProcessing)

                Button("Recompute Summaries") {
                    recomputeSummaries()
                }
                .buttonStyle(.plain)
                .focusable(false)
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.hoveredBackground)
                .cornerRadius(6)
                .disabled(analyzedEntries == 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Storage Information")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.primaryText)

                HStack {
                    Text("Total Entries:")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                    Text("\(totalEntries)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primaryText)
                }

                HStack {
                    Text("Analyzed Entries:")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                    Text("\(analyzedEntries) (\(percentage)%)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primaryText)
                }

                HStack {
                    Text("Database Size:")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                    Text("\(dbSize) MB")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primaryText)
                }

                if let lastProcessed = lastProcessedDate {
                    HStack {
                        Text("Last Processed:")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                        Spacer()
                        Text(lastProcessed.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.primaryText)
                    }
                }
            }
            .padding(12)
            .background(theme.hoveredBackground)
            .cornerRadius(8)

            Button("Clear All Analytics", role: .destructive) {
                showClearConfirmation = true
            }
            .buttonStyle(.plain)
            .focusable(false)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.destructive)
            .cornerRadius(6)
            .confirmationDialog("Clear All Analytics", isPresented: $showClearConfirmation) {
                Button("Clear All Data", role: .destructive) {
                    clearAnalytics()
                }
            } message: {
                Text("This will delete all analytics data, embeddings, and summaries. This action cannot be undone.")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("About Analytics")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                Text("• Journal entries are analyzed using AI to extract emotions and events")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                Text("• Embeddings enable semantic search through your journal")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                Text("• Processing may take several minutes for large journals")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(12)
            .background(theme.hoveredBackground)
            .cornerRadius(8)
        }
        .padding(24)
        .sheet(isPresented: $showProcessingSheet, onDismiss: {
            loadAnalyticsStats()
        }) {
            AnalyticsProgressView()
        }
        .onAppear {
            loadAnalyticsStats()
        }
    }
    */  // END REMOVED analytics section OLD

    /* REMOVED: analytics
    private var percentage: Int {
        guard totalEntries > 0 else { return 0 }
        return Int((Double(analyzedEntries) / Double(totalEntries)) * 100)
    }

    /* REMOVED: analytics
    private func loadAnalyticsStats() {
        totalEntries = fileService.loadExistingEntries().count

        // Load auto-processing preference
        autoProcessingEnabled = AnalyticsObserver.shared.isAutoProcessingEnabled

        do {
            let dbService = DatabaseService.shared
            try dbService.initialize()
            let analyticsRepo = EntryAnalyticsRepository(dbService: dbService)
            let allAnalytics = try analyticsRepo.getAllAnalytics()
            analyzedEntries = allAnalytics.count

            // allAnalytics is sorted DESC, so .first is the MOST RECENT
            if let latestAnalysis = allAnalytics.first {
                lastProcessedDate = latestAnalysis.analyzedAt
            }

            let dbURL = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("LifeOS/analytics.db")

            if let attributes = try? FileManager.default.attributesOfItem(atPath: dbURL.path),
               let fileSize = attributes[.size] as? Int64 {
                let sizeInMB = Double(fileSize) / 1_048_576
                dbSize = String(format: "%.2f", sizeInMB)
            }
        } catch {
            print("⚠️ Failed to load analytics stats: \(error)")
        }
    }

    private func clearAnalytics() {
        do {
            try DatabaseService.shared.clearAllData()
            loadAnalyticsStats()
        } catch {
            print("⚠️ Failed to clear analytics: \(error)")
        }
    }

    */  // END REMOVED analytics

    /* REMOVED: analytics
    private func recomputeSummaries() {
        Task {
            do {
                let dbService = DatabaseService.shared
                let analyticsRepo = EntryAnalyticsRepository(dbService: dbService)
                let monthSummaryRepo = MonthSummaryRepository(dbService: dbService)
                let yearSummaryRepo = YearSummaryRepository(dbService: dbService)

                let summarizationService = SummarizationService(
                    analyticsRepository: analyticsRepo,
                    monthSummaryRepository: monthSummaryRepo,
                    yearSummaryRepository: yearSummaryRepo
                )

                let allAnalytics = try analyticsRepo.getAllAnalytics()
                let calendar = Calendar.current

                var monthsYears: Set<String> = []
                for analytics in allAnalytics {
                    let year = calendar.component(.year, from: analytics.date)
                    let month = calendar.component(.month, from: analytics.date)
                    monthsYears.insert("\(year)-\(month)")
                }

                for monthYear in monthsYears {
                    let components = monthYear.split(separator: "-")
                    let year = Int(components[0])!
                    let month = Int(components[1])!
                    _ = try await summarizationService.summarizeMonth(year: year, month: month)
                }

                var years: Set<Int> = []
                for analytics in allAnalytics {
                    years.insert(calendar.component(.year, from: analytics.date))
                }

                for year in years {
                    _ = try await summarizationService.summarizeYear(year: year)
                }

                print("✅ Summaries recomputed successfully")
            } catch {
                print("⚠️ Failed to recompute summaries: \(error)")
            }
        }
    }
    */  // END REMOVED analytics recomputeSummaries
    */  // END REMOVED analytics percentage

    // MARK: - Embeddings Helpers

    private var embeddingsPercentage: Int {
        guard totalEntries > 0 else { return 0 }
        return Int((Double(entriesWithEmbeddings) / Double(totalEntries)) * 100)
    }

    private func loadEmbeddingsStats() {
        totalEntries = fileService.loadExistingEntries().count

        do {
            let dbService = DatabaseService.shared
            try dbService.initialize()
            let chunkRepo = ChunkRepository(dbService: dbService)

            // Count unique entry IDs that have embeddings
            let allChunks = try chunkRepo.getAllChunks()
            let uniqueEntryIds = Set(allChunks.map { $0.entryId })
            entriesWithEmbeddings = uniqueEntryIds.count

            // Calculate database size
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dbURL = documentsPath.appendingPathComponent("LifeOS/analytics.db")
            if FileManager.default.fileExists(atPath: dbURL.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: dbURL.path)
                if let fileSize = attributes[FileAttributeKey.size] as? Int64 {
                    dbSize = String(format: "%.2f", Double(fileSize) / 1_048_576) // Convert to MB
                }
            }
        } catch {
            print("⚠️ Failed to load embeddings stats: \(error)")
        }
    }

    private func processAllEntries() {
        Task {
            isProcessing = true
            defer { isProcessing = false }

            let entries = fileService.loadExistingEntries()
            print("📊 Processing \(entries.count) entries for embeddings...")

            // TODO: Implement batch processing with IngestionService
            // This will need to create chunks and generate embeddings for each entry
            // For now, this is a placeholder

            loadEmbeddingsStats()
        }
    }

    private func clearEmbeddings() {
        do {
            let dbService = DatabaseService.shared
            try dbService.initialize()
            let chunkRepo = ChunkRepository(dbService: dbService)

            try chunkRepo.deleteAll()
            print("✅ Cleared all embeddings")

            loadEmbeddingsStats()
        } catch {
            print("⚠️ Failed to clear embeddings: \(error)")
        }
    }
}
