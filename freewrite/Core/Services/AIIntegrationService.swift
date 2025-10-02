
import AppKit
import Foundation

class AIIntegrationService {
    
    func openChatGPT(with text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = AppConstants.aiChatPrompt + "\n\n" + trimmedText
        
        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://chat.openai.com/?m=" + encodedText) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openClaude(with text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = AppConstants.claudePrompt + "\n\n" + trimmedText
        
        if let encodedText = fullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://claude.ai/new?q=" + encodedText) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func copyPromptToClipboard(with text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = AppConstants.aiChatPrompt + "\n\n" + trimmedText

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)
        print("Prompt copied to clipboard")
    }
    
    func calculateURLLength(for text: String) -> (gptLength: Int, claudeLength: Int) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let gptFullText = AppConstants.aiChatPrompt + "\n\n" + trimmedText
        let claudeFullText = AppConstants.claudePrompt + "\n\n" + trimmedText
        
        let encodedGptText = gptFullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedClaudeText = claudeFullText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let gptUrlLength = "https://chat.openai.com/?m=".count + encodedGptText.count
        let claudeUrlLength = "https://claude.ai/new?q=".count + encodedClaudeText.count
        
        return (gptUrlLength, claudeUrlLength)
    }
}
