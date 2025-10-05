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
    let month: Int  // 1-12
    let monthName: String
    let entries: [HumanEntry]
    
    var id: Int { month }
    
    var count: Int { entries.count }
}
