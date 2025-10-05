import Foundation

struct EntryGroup: Identifiable {
    let year: Int
    let months: [MonthGroup]
    
    var id: Int { year }
    
    var totalCount: Int {
        months.reduce(0) { $0 + $1.entries.count }
    }
}

struct MonthGroup: Identifiable {
    let year: Int
    let month: Int
    let monthName: String
    let entries: [HumanEntry]
    
    var id: String { "\(year)-\(month)" }
    
    var count: Int { entries.count }
}
