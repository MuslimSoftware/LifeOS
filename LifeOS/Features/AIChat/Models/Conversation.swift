//
//  Conversation.swift
//  LifeOS
//
//  Created by Claude on 10/26/25.
//

import Foundation

struct Conversation: Codable, Identifiable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "New Chat", messages: [ChatMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Generate a title from the latest message (user or assistant)
    mutating func updateTitleFromLatestMessage() {
        if let latestMessage = messages.last {
            let preview = latestMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if preview.count > 40 {
                title = String(preview.prefix(40)) + "..."
            } else {
                title = preview.isEmpty ? "New Chat" : preview
            }
        }
    }
}
