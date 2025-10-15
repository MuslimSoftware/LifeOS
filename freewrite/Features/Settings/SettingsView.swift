import SwiftUI

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey: String = ""
    @State private var isKeyStored: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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
            
            Divider()
                .background(theme.dividerColor)
            
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
            
            Divider()
                .background(theme.dividerColor)
            
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
            
            Spacer()
            
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
        .frame(width: 550, height: 650)
        .background(theme.backgroundColor)
        .onAppear {
            checkAPIKey()
        }
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
}
