
import SwiftUI

struct TimerButtonView: View {
    @Environment(EditorViewModel.self) private var viewModel
    @Environment(\.theme) private var theme
    
    @State private var isHoveringTimer = false
    @Binding var isHoveringBottomNav: Bool
    @Binding var hoveredControl: String?
    @Binding var scrollAccumulator: CGFloat
    
    var body: some View {
        @Bindable var vm = viewModel
        
        ZStack {
            // "Timer" label layer
            Text("Timer")
                .font(.system(size: 13))
                .foregroundColor(timerColor)
                .opacity(showTimerLabel ? 1.0 : 0.0)
            
            // Timer countdown layer with scroll indicator
            Text(vm.timerButtonTitle())
                .font(.system(size: 13))
                .foregroundColor(timerColor)
                .frame(minWidth: 50)
                .overlay(alignment: .leading) {
                    if isHoveringTimer && !vm.timerIsRunning {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10))
                            .foregroundColor(theme.primaryText)
                            .offset(x: -12)
                    }
                }
                .opacity(showTimerLabel ? 0.0 : 1.0)
        }
        .animation(.easeInOut(duration: 0.2), value: showTimerLabel)
        .animation(.easeInOut(duration: 0.2), value: isHoveringTimer)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.toggleTimer()
        }
        .onHover { hovering in
            isHoveringTimer = hovering
            isHoveringBottomNav = hovering
            hoveredControl = hovering ? "timer" : nil
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    private var showTimerLabel: Bool {
        return !viewModel.timerIsRunning && !isHoveringTimer
    }
    
    private var timerColor: Color {
        if viewModel.timerIsRunning {
            return isHoveringTimer ? theme.buttonTextHover : theme.tertiaryText
        } else {
            return isHoveringTimer ? theme.buttonTextHover : theme.buttonText
        }
    }
}
