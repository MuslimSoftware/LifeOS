import Foundation
import GRDB

extension ChatMessage: FetchableRecord, PersistableRecord {
    static let databaseTableName = "chat_messages"

    enum Columns: String, ColumnExpression {
        case id, conversationId = "conversation_id", role, content
        case toolsUsedJson = "tools_used_json", timestamp
    }
}

extension Conversation: FetchableRecord, PersistableRecord {
    static let databaseTableName = "conversations"

    enum Columns: String, ColumnExpression {
        case id, title, createdAt = "created_at", updatedAt = "updated_at"
    }
}
