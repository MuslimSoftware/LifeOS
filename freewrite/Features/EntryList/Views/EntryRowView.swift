
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
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.previewText)
                            .font(.system(size: 13))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if isHovered {
                            HStack(spacing: 8) {
                                Button(action: onExport) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 11))
                                        .foregroundColor(hoveredExportId == entry.id ?
                                            (colorScheme == .light ? .black : .white) :
                                            (colorScheme == .light ? .gray : .gray.opacity(0.8)))
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
                                        .foregroundColor(hoveredTrashId == entry.id ? .red : .gray)
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
                    
                    Text(entry.date)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
            return Color.gray.opacity(0.1)
        } else if isHovered {
            return Color.gray.opacity(0.05)
        } else {
            return Color.clear
        }
    }
}
