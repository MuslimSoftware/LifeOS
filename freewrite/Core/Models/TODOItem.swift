import Foundation

struct TODOItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var completed: Bool
    var createdAt: Date
    var dueTime: Date?

    init(id: UUID = UUID(), text: String, completed: Bool, createdAt: Date = Date(), dueTime: Date? = nil) {
        self.id = id
        self.text = text
        self.completed = completed
        self.createdAt = createdAt
        self.dueTime = dueTime
    }
    
    var tags: [String] {
        extractTags(from: text)
    }
    
    var context: String? {
        extractContext(from: text)
    }
    
    private func extractTags(from text: String) -> [String] {
        let pattern = #"#(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
        
        return results.map { result in
            nsString.substring(with: result.range(at: 1))
        }
    }
    
    private func extractContext(from text: String) -> String? {
        let pattern = #"@(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        
        guard let result = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }
        
        return nsString.substring(with: result.range(at: 1))
    }
}
