
import SwiftUI
import AppKit

struct BottomNavigationView: View {
    @Environment(EditorViewModel.self) private var editorViewModel
    @Environment(\.theme) private var theme
    
    let availableFonts: [String]
    let fileService: FileManagerService
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
                ScrollableValueControl.month(
                    date: selectedDate,
                    hoveredControl: $hoveredDateControl,
                    scrollAccumulator: $scrollAccumulator,
                    onAdjust: adjustMonth
                )
                .onHover { hovering in
                    vm.isHoveringBottomNav = hovering
                }

                Text("•")
                    .foregroundColor(theme.separatorColor)

                ScrollableValueControl.day(
                    date: selectedDate,
                    hoveredControl: $hoveredDateControl,
                    scrollAccumulator: $scrollAccumulator,
                    onAdjust: adjustDay
                )
                .onHover { hovering in
                    vm.isHoveringBottomNav = hovering
                }

                Text("•")
                    .foregroundColor(theme.separatorColor)

                ScrollableValueControl.year(
                    date: selectedDate,
                    hoveredControl: $hoveredDateControl,
                    scrollAccumulator: $scrollAccumulator,
                    onAdjust: adjustYear
                )
                .onHover { hovering in
                    vm.isHoveringBottomNav = hovering
                }

                Text("•")
                    .foregroundColor(theme.separatorColor)

                TimerButtonView(isHoveringBottomNav: $vm.isHoveringBottomNav)

                Text("•")
                    .foregroundColor(theme.separatorColor)

                UtilityButtonsView(isHoveringBottomNav: $vm.isHoveringBottomNav, fileService: fileService)
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
                if hoveredDateControl != nil {
                    scrollAccumulator += event.deltaY

                    if scrollAccumulator > 3 {
                        handleScroll(direction: 1)
                        scrollAccumulator = 0
                    } else if scrollAccumulator < -3 {
                        handleScroll(direction: -1)
                        scrollAccumulator = 0
                    }
                    return nil
                }
                return event
            }
        }
    }

    private func handleScroll(direction: Int) {
        switch hoveredDateControl {
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
