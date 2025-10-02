
import SwiftUI

struct TimerButtonView: View {
    @Environment(EditorViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isHoveringTimer = false
    @Binding var isHoveringBottomNav: Bool
    
    var body: some View {
        @Bindable var vm = viewModel
        
        Button(vm.timerButtonTitle()) {
            vm.toggleTimer()
        }
        .buttonStyle(.plain)
        .foregroundColor(timerColor)
        .onHover { hovering in
            isHoveringTimer = hovering
            isHoveringBottomNav = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                if isHoveringTimer {
                    vm.adjustTimerWithScroll(event.deltaY)
                }
                return event
            }
        }
    }
    
    private var timerColor: Color {
        if viewModel.timerIsRunning {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : .gray.opacity(0.8)
        } else {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : (colorScheme == .light ? .gray : .gray.opacity(0.8))
        }
    }
}
