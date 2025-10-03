import SwiftUI

struct HomeView: View {
    @Environment(\.theme) private var theme
    @Environment(EntryListViewModel.self) private var entryListViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Text("LifeOS")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(theme.primaryText)
            
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("\(entryListViewModel.entries.count)")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                    Text("Total Entries")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                
                VStack(spacing: 8) {
                    Text(totalWordCount)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                    Text("Total Words")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundColor)
        .padding(.top, 80)
    }
    
    private var totalWordCount: String {
        let count = entryListViewModel.entries.reduce(0) { total, entry in
            let wordCount = entry.previewText.split(separator: " ").count * 10
            return total + wordCount
        }
        return "\(count)"
    }
}
