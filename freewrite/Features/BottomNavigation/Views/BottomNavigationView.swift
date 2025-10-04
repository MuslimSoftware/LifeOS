
import SwiftUI
import AppKit

struct BottomNavigationView: View {
    @Environment(EditorViewModel.self) private var editorViewModel
    @Environment(\.theme) private var theme
    
    let availableFonts: [String]
    @Binding var selectedDate: Date
    
    @State private var hoveredDateControl: String? = nil
    @State private var scrollAccumulator: CGFloat = 0
    
    private let calendar = Calendar.current
    
    var body: some View {
        @Bindable var vm = editorViewModel
        
        HStack {
            FontSelectorView(
                isHoveringBottomNav: $vm.isHoveringBottomNav,
                availableFonts: availableFonts
            )
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(monthOnlyString)
                    .font(.system(size: 13))
                    .foregroundColor(hoveredDateControl == "month" ? theme.buttonTextHover : theme.buttonText)
                    .padding(.horizontal, 8)
                    .onHover { hovering in
                        hoveredDateControl = hovering ? "month" : nil
                        vm.isHoveringBottomNav = hovering
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                
                Text("•")
                    .foregroundColor(theme.separatorColor)
                
                Text(dayString)
                    .font(.system(size: 13))
                    .foregroundColor(hoveredDateControl == "day" ? theme.buttonTextHover : theme.buttonText)
                    .padding(.horizontal, 8)
                    .onHover { hovering in
                        hoveredDateControl = hovering ? "day" : nil
                        vm.isHoveringBottomNav = hovering
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                
                Text("•")
                    .foregroundColor(theme.separatorColor)
                
                Text(yearString)
                    .font(.system(size: 13))
                    .foregroundColor(hoveredDateControl == "year" ? theme.buttonTextHover : theme.buttonText)
                    .padding(.horizontal, 8)
                    .onHover { hovering in
                        hoveredDateControl = hovering ? "year" : nil
                        vm.isHoveringBottomNav = hovering
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                
                Text("•")
                    .foregroundColor(theme.separatorColor)
                
                TimerButtonView(isHoveringBottomNav: $vm.isHoveringBottomNav)
                
                Text("•")
                    .foregroundColor(theme.separatorColor)
                
                UtilityButtonsView(isHoveringBottomNav: $vm.isHoveringBottomNav)
            }
            .padding(8)
            .cornerRadius(6)
            .onHover { hovering in
                vm.isHoveringBottomNav = hovering
            }
        }
        .padding()
        .background(theme.backgroundColor)
        .opacity(vm.bottomNavOpacity)
        .onHover { hovering in
            vm.isHoveringBottomNav = hovering
            if hovering {
                withAnimation(.easeOut(duration: 0.2)) {
                    vm.bottomNavOpacity = 1.0
                }
            } else if vm.timerIsRunning {
                withAnimation(.easeIn(duration: 1.0)) {
                    vm.bottomNavOpacity = 0.0
                }
            }
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                if hoveredDateControl == "month" || hoveredDateControl == "day" || hoveredDateControl == "year" {
                    scrollAccumulator += event.deltaY
                    
                    if scrollAccumulator > 3 {
                        if hoveredDateControl == "month" {
                            adjustMonth(by: 1)
                        } else if hoveredDateControl == "day" {
                            adjustDay(by: 1)
                        } else if hoveredDateControl == "year" {
                            adjustYear(by: 1)
                        }
                        scrollAccumulator = 0
                    } else if scrollAccumulator < -3 {
                        if hoveredDateControl == "month" {
                            adjustMonth(by: -1)
                        } else if hoveredDateControl == "day" {
                            adjustDay(by: -1)
                        } else if hoveredDateControl == "year" {
                            adjustYear(by: -1)
                        }
                        scrollAccumulator = 0
                    }
                    return nil
                }
                return event
            }
        }
    }
    
    private var monthOnlyString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: selectedDate)
    }
    
    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: selectedDate)
    }
    
    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: selectedDate)
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
