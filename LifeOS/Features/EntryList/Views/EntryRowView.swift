
import SwiftUI

struct EntryRowView: View {
    let entry: HumanEntry
    let isSelected: Bool
    let isHovered: Bool
    let hoveredTrashId: UUID?
    let hoveredExportId: UUID?
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void
    
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.previewText)
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .foregroundColor(theme.primaryText)
                        
                        Spacer()
                        
                        if isHovered {
                            HStack(spacing: 8) {
                                Button(action: onExport) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 11))
                                        .foregroundColor(hoveredExportId == entry.id ?
                                            theme.buttonTextHover :
                                            theme.buttonText)
                                }
                                .buttonStyle(.plain)
                                .help("Export entry as PDF")
                                .onHover { hovering in
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                                
                                Button(action: onDelete) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(hoveredTrashId == entry.id ? theme.destructive : theme.secondaryText)
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                            }
                        }
                    }
                    
                        Text(verbatim: "\(entry.date), \(entry.year)")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
        .help("Click to select this entry")
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return theme.selectedBackground
        } else if isHovered {
            return theme.hoveredBackground
        } else {
            return Color.clear
        }
    }
}
