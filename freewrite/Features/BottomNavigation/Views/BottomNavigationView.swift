
import SwiftUI
import AppKit

struct BottomNavigationView: View {
    @Environment(EditorViewModel.self) private var editorViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    let availableFonts: [String]
    
    var body: some View {
        @Bindable var vm = editorViewModel
        
        HStack {
            FontSelectorView(
                isHoveringBottomNav: $vm.isHoveringBottomNav,
                availableFonts: availableFonts
            )
            
            Spacer()
            
            HStack(spacing: 8) {
                TimerButtonView(isHoveringBottomNav: $vm.isHoveringBottomNav)
                
                Text("•")
                    .foregroundColor(.gray)
                
                UtilityButtonsView(isHoveringBottomNav: $vm.isHoveringBottomNav)
            }
            .padding(8)
            .cornerRadius(6)
            .onHover { hovering in
                vm.isHoveringBottomNav = hovering
            }
        }
        .padding()
        .background(Color(colorScheme == .light ? .white : .black))
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
    }
}
