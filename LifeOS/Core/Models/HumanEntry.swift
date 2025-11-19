
import Foundation

struct HumanEntry: Identifiable {
    let id: UUID
    var date: String
    let filename: String
    var previewText: String
    var year: Int
    
    static func createNew() -> HumanEntry {
        let id = UUID()
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        dateFormatter.timeZone = TimeZone.current
        let dateString = dateFormatter.string(from: now)
        
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: now)
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        
        return HumanEntry(
            id: id,
            date: displayDate,
            filename: "[\(id)]-[\(dateString)].md",
            previewText: "",
            year: year
        )
    }
    
    static func createWithDate(date: Date) -> HumanEntry {
        let id = UUID()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        dateFormatter.timeZone = TimeZone.current
        let timestampString = dateFormatter.string(from: Date())
        
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: date)
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        
        return HumanEntry(
            id: id,
            date: displayDate,
            filename: "[\(id)]-[\(timestampString)].md",
            previewText: "",
            year: year
        )
    }
}
