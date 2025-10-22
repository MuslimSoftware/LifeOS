import SwiftUI

struct YearHeaderView: View {
    let year: Int
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    
    @Environment(\.theme) private var theme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 12)
                
                Text(verbatim: "\(year)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                
                Text("(\(count))")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? theme.hoveredBackground : theme.backgroundColor)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct MonthHeaderView: View {
    let monthName: String
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    
    @Environment(\.theme) private var theme
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)
                    .frame(width: 12)
                
                Text(monthName)
                    .font(.system(size: 12))
                    .foregroundColor(theme.primaryText)
                
                Text("(\(count))")
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)
                
                Spacer()
            }
            .padding(.leading, 20)  // Indented more than year
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(isHovered ? theme.hoveredBackground.opacity(0.6) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
