//
//  ChatInputView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Text input component with send button for chat interface
struct ChatInputView: View {
    @Binding var messageText: String
    let onSend: (String) -> Void
    let isLoading: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField("Ask about your journal...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused($isFocused)
                .disabled(isLoading)
                .onSubmit {
                    sendMessage()
                }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? .accentColor : .gray)
            }
            .disabled(!canSend)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
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
