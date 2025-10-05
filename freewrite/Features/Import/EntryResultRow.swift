import SwiftUI

struct EntryResultRow: View {
    let entry: ImportedEntry
    @Bindable var viewModel: ImportViewModel
    @Environment(\.theme) private var theme
    
    @State private var isExpanded = false
    @State private var showDatePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Button(action: { showDatePicker.toggle() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11))
                                Text(formattedDate)
                                    .font(.system(size: 13, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(theme.accentColor)
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.accentColor.opacity(0.1))
                        .cornerRadius(4)
                        
                        if showDatePicker {
                            DatePicker("", selection: Binding(
                                get: { entry.date },
                                set: { viewModel.updateDate(for: entry, to: $0) }
                            ), displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                        }
                        
                        Spacer()
                    }
                    
                    if isExpanded {
                        ScrollView {
                            Text(entry.text)
                                .font(.system(size: 12))
                                .foregroundColor(theme.secondaryText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300)
                    } else {
                        Text(entry.text.prefix(200) + (entry.text.count > 200 ? "..." : ""))
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                            .lineLimit(3)
                    }
                }
                
                Button(action: { viewModel.removeEntry(entry) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            
            if entry.text.count > 200 {
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show less" : "Show full text")
                            .font(.system(size: 11))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(theme.accentColor)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(12)
        .background(theme.hoveredBackground)
        .cornerRadius(8)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: entry.date)
    }
}
