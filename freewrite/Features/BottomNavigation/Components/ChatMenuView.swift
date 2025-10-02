
import SwiftUI

struct ChatMenuView: View {
    @Environment(EditorViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isHoveringChat = false
    @State private var showingChatMenu = false
    @State private var didCopyPrompt = false
    @Binding var isHoveringBottomNav: Bool
    
    let aiService: AIIntegrationService
    
    var body: some View {
        Button("Chat") {
            showingChatMenu = true
            didCopyPrompt = false
        }
        .buttonStyle(.plain)
        .foregroundColor(isHoveringChat ? textHoverColor : textColor)
        .onHover { hovering in
            isHoveringChat = hovering
            isHoveringBottomNav = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .popover(isPresented: $showingChatMenu, attachmentAnchor: .point(UnitPoint(x: 0.5, y: 0)), arrowEdge: .top) {
            VStack(spacing: 0) {
                let trimmedText = viewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let urlLengths = aiService.calculateURLLength(for: viewModel.text)
                let isUrlTooLong = urlLengths.gptLength > 6000 || urlLengths.claudeLength > 6000
                
                if isUrlTooLong {
                    Text("Hey, your entry is long. It'll break the URL. Instead, copy prompt by clicking below and paste into AI of your choice!")
                        .font(.system(size: 14))
                        .foregroundColor(popoverTextColor)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .frame(width: 200, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    
                    Divider()
                    
                    Button(action: {
                        aiService.copyPromptToClipboard(with: viewModel.text)
                        didCopyPrompt = true
                    }) {
                        Text(didCopyPrompt ? "Copied!" : "Copy Prompt")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(popoverTextColor)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    
                } else if viewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("hi. my name is farza.") {
                    Text("Yo. Sorry, you can't chat with the guide lol. Please write your own entry.")
                        .font(.system(size: 14))
                        .foregroundColor(popoverTextColor)
                        .frame(width: 250)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else if viewModel.text.count < 350 {
                    Text("Please free write for at minimum 5 minutes first. Then click this. Trust.")
                        .font(.system(size: 14))
                        .foregroundColor(popoverTextColor)
                        .frame(width: 250)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    Button(action: {
                        showingChatMenu = false
                        aiService.openChatGPT(with: viewModel.text)
                    }) {
                        Text("ChatGPT")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(popoverTextColor)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        showingChatMenu = false
                        aiService.openClaude(with: viewModel.text)
                    }) {
                        Text("Claude")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(popoverTextColor)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        aiService.copyPromptToClipboard(with: viewModel.text)
                        didCopyPrompt = true
                    }) {
                        Text(didCopyPrompt ? "Copied!" : "Copy Prompt")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(popoverTextColor)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }
            .frame(minWidth: 120, maxWidth: 250)
            .background(popoverBackgroundColor)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
            .onChange(of: showingChatMenu) { newValue in
                if !newValue {
                    didCopyPrompt = false
                }
            }
        }
    }
    
    private var textColor: Color {
        return colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
    }
    
    private var textHoverColor: Color {
        return colorScheme == .light ? Color.black : Color.white
    }
    
    private var popoverBackgroundColor: Color {
        return colorScheme == .light ? Color(NSColor.controlBackgroundColor) : Color(NSColor.darkGray)
    }
    
    private var popoverTextColor: Color {
        return colorScheme == .light ? Color.primary : Color.white
    }
}
