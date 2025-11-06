
import SwiftUI
import AppKit

struct BottomNavigationView: View {
    @Environment(EditorViewModel.self) private var editorViewModel
    @Environment(\.theme) private var theme
    
    let availableFonts: [String]
    let fileService: FileManagerService
    @Binding var selectedDate: Date
    
    @State private var hoveredTimerControl: String? = nil
    @State private var timerScrollAccumulator: CGFloat = 0
    
    var body: some View {
        @Bindable var vm = editorViewModel
        
        HStack {
            Spacer()
            
            DateSelectorView(
                isHoveringBottomNav: $vm.isHoveringBottomNav,
                selectedDate: $selectedDate
            )
            
            Text("•")
                .foregroundColor(theme.separatorColor)
                .padding(.horizontal, 8)
            
            FontSelectorView(
                isHoveringBottomNav: $vm.isHoveringBottomNav,
                availableFonts: availableFonts
            )

            Text("•")
                .foregroundColor(theme.separatorColor)
                .padding(.horizontal, 8)

            TimerButtonView(
                isHoveringBottomNav: $vm.isHoveringBottomNav,
                hoveredControl: $hoveredTimerControl,
                scrollAccumulator: $timerScrollAccumulator
            )
        }
        .padding(8)
        .onHover { hovering in
            vm.isHoveringBottomNav = hovering
        }
        .padding()
        .frame(height: 60)
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
                if hoveredTimerControl != nil {
                    timerScrollAccumulator += event.deltaY

                    if timerScrollAccumulator > 3 {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        adjustTimer(by: 1)
                        timerScrollAccumulator = 0
                    } else if timerScrollAccumulator < -3 {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        adjustTimer(by: -1)
                        timerScrollAccumulator = 0
                    }
                    return nil
                }
                return event
            }
        }
    }

    private func adjustTimer(by direction: Int) {
        let minutes = direction * 5
        let seconds = minutes * 60
        let newTime = editorViewModel.timeRemaining + seconds
        editorViewModel.timeRemaining = min(max(newTime, 0), 2700)
    }
}
