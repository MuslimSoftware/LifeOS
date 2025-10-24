//
//  ChatInputView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Text input component with send button for chat interface
struct ChatInputView: View {
    @Environment(\.theme) private var theme
    @Binding var messageText: String
    let onSend: (String) -> Void
    let isLoading: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask about your journal...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .padding(12)
                .lineLimit(1...5)
                .focused($isFocused)
                .disabled(isLoading)
                .onSubmit {
                    sendMessage()
                }

            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(canSend ? theme.primaryText : theme.primaryText.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 650)
        .background(theme.hoveredBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    private func sendMessage() {
        guard canSend else { return }
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        onSend(text)
    }
}

#Preview {
    @Previewable @State var text = ""
    ChatInputView(messageText: $text, onSend: { _ in }, isLoading: false)
}
