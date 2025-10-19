import SwiftUI

enum SettingsSection: String, CaseIterable {
    case openai = "OpenAI API"
    case backup = "Data Backup"
}

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var isKeyStored: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String?
    @State private var exportMessage: String?
    @State private var importKeyText: String = ""
    @State private var showImportField: Bool = false
    @State private var selectedSection: SettingsSection = .openai
    @State private var hoveredSection: SettingsSection?

    private let fileService = FileManagerService()

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
            checkAPIKey()
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
                case .openai:
                    openAISection
                case .backup:
                    backupSection
                }
            }
        }
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
    
    private func checkAPIKey() {
        isKeyStored = KeychainService.shared.hasAPIKey()
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

        if KeychainService.shared.saveAPIKey(trimmedKey) {
            isKeyStored = true
            showSuccess = true
            apiKey = ""

            // Note: saveAPIKey() already caches the key, no need to invalidate

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSuccess = false
            }
        } else {
            errorMessage = "Failed to save API key to Keychain"
        }
    }
    
    private func removeAPIKey() {
        if KeychainService.shared.deleteAPIKey() {
            isKeyStored = false
            showSuccess = false
            errorMessage = nil

            KeychainService.shared.invalidateCache()
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
        savePanel.nameFieldStringValue = "freewrite-encryption-key.txt"
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
        savePanel.nameFieldStringValue = "freewrite-export-\(Int(Date().timeIntervalSince1970)).zip"
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
}
