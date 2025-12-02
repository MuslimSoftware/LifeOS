import Foundation
import GRDB

class ConversationRepository {
    private let dbService: DatabaseService

    init(dbService: DatabaseService = .shared) {
        self.dbService = dbService
    }

    func save(_ conversation: Conversation) throws {
        try dbService.getQueue().write { db in
            var mutableConv = conversation
            mutableConv.updatedAt = Date()
            try mutableConv.save(db)

            try db.execute(sql: "DELETE FROM chat_messages WHERE conversation_id = ?",
                          arguments: [conversation.id.uuidString])

            for message in conversation.messages {
                let toolsJson = (try? JSONEncoder().encode(message.toolsUsed)) ?? Data()
                let toolsJsonString = String(data: toolsJson, encoding: .utf8) ?? "[]"

                try db.execute(
                    sql: """
                        INSERT INTO chat_messages (id, conversation_id, role, content, tools_used_json, timestamp)
                        VALUES (?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        message.id.uuidString,
                        conversation.id.uuidString,
                        message.role.rawValue,
                        message.content,
                        toolsJsonString,
                        message.timestamp
                    ]
                )
            }
        }
    }

    func getConversation(id: UUID) throws -> Conversation? {
        try dbService.getQueue().read { db in
            guard var conversation = try Conversation.fetchOne(db, key: id.uuidString) else {
                return nil
            }

            let rows = try Row.fetchAll(db, sql: """
                SELECT id, role, content, tools_used_json, timestamp
                FROM chat_messages
                WHERE conversation_id = ?
                ORDER BY timestamp ASC
                """, arguments: [id.uuidString])

            let messages = rows.compactMap { row -> ChatMessage? in
                guard let id = UUID(uuidString: row["id"]),
                      let roleString: String = row["role"],
                      let role = ChatMessage.Role(rawValue: roleString),
                      let content: String = row["content"],
                      let toolsJsonString: String = row["tools_used_json"],
                      let timestamp: Date = row["timestamp"] else {
                    return nil
                }

                let toolsUsed = (try? JSONDecoder().decode([String].self, from: toolsJsonString.data(using: .utf8)!)) ?? []

                return ChatMessage(id: id, role: role, content: content, toolsUsed: toolsUsed, timestamp: timestamp)
            }

            conversation.messages = messages
            return conversation
        }
    }

    func getAllConversations() throws -> [Conversation] {
        try dbService.getQueue().read { db in
            let conversations = try Conversation
                .order(Column("updated_at").desc)
                .fetchAll(db)

            return try conversations.map { conversation in
                var conv = conversation

                let rows = try Row.fetchAll(db, sql: """
                    SELECT id, role, content, tools_used_json, timestamp
                    FROM chat_messages
                    WHERE conversation_id = ?
                    ORDER BY timestamp ASC
                    """, arguments: [conversation.id.uuidString])

                let messages = rows.compactMap { row -> ChatMessage? in
                    guard let id = UUID(uuidString: row["id"]),
                          let roleString: String = row["role"],
                          let role = ChatMessage.Role(rawValue: roleString),
                          let content: String = row["content"],
                          let toolsJsonString: String = row["tools_used_json"],
                          let timestamp: Date = row["timestamp"] else {
                        return nil
                    }

                    let toolsUsed = (try? JSONDecoder().decode([String].self, from: toolsJsonString.data(using: .utf8)!)) ?? []

                    return ChatMessage(id: id, role: role, content: content, toolsUsed: toolsUsed, timestamp: timestamp)
                }

                conv.messages = messages
                return conv
            }
        }
    }

    func delete(id: UUID) throws {
        try dbService.getQueue().write { db in
            try Conversation.deleteOne(db, key: id.uuidString)
        }
    }
}
