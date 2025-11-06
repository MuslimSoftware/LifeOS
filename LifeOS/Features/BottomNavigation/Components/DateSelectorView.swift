import SwiftUI
import AppKit

struct DateSelectorView: View {
    @Environment(\.theme) private var theme
    
    @State private var isExpanded = false
    @State private var hoveredControl: String? = nil
    @State private var scrollAccumulator: CGFloat = 0
    @Binding var isHoveringBottomNav: Bool
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    
    var body: some View {
        HStack(spacing: 20) {
            if !isExpanded {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10))
                        .foregroundColor(textColor)
                    
                    Text("Date")
                        .font(.system(size: 13))
                        .foregroundColor(textColor)
                }
            }
            
            if isExpanded {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(textColor)
                
                ScrollableValueControl.month(
                    date: selectedDate,
                    hoveredControl: $hoveredControl,
                    scrollAccumulator: $scrollAccumulator,
                    onAdjust: adjustMonth
                )
                .onHover { hovering in
                    isHoveringBottomNav = hovering
                }

                Text("•")
                    .foregroundColor(theme.separatorColor)

                ScrollableValueControl.day(
                    date: selectedDate,
                    hoveredControl: $hoveredControl,
                    scrollAccumulator: $scrollAccumulator,
                    onAdjust: adjustDay
                )
                .onHover { hovering in
                    isHoveringBottomNav = hovering
                }

                Text("•")
                    .foregroundColor(theme.separatorColor)

                ScrollableValueControl.year(
                    date: selectedDate,
                    hoveredControl: $hoveredControl,
                    scrollAccumulator: $scrollAccumulator,
                    onAdjust: adjustYear
                )
                .onHover { hovering in
                    isHoveringBottomNav = hovering
                }
            }
        }
        .padding(8)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = hovering
            }
            isHoveringBottomNav = hovering
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                if hoveredControl != nil {
                    scrollAccumulator += event.deltaY

                    if scrollAccumulator > 3 {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        handleScroll(direction: 1)
                        scrollAccumulator = 0
                    } else if scrollAccumulator < -3 {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        handleScroll(direction: -1)
                        scrollAccumulator = 0
                    }
                    return nil
                }
                return event
            }
        }
    }
    
    private var textColor: Color {
        return theme.buttonText
    }
    
    private var textHoverColor: Color {
        return theme.buttonTextHover
    }
    
    private func handleScroll(direction: Int) {
        switch hoveredControl {
        case "month":
            adjustMonth(by: direction)
        case "day":
            adjustDay(by: direction)
        case "year":
            adjustYear(by: direction)
        default:
            break
        }
    }
    
    private func adjustMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func adjustDay(by value: Int) {
        if let newDate = calendar.date(byAdding: .day, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func adjustYear(by value: Int) {
        if let newDate = calendar.date(byAdding: .year, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }
}
