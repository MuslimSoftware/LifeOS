
import SwiftUI
import AppKit

struct UtilityButtonsView: View {
    @Environment(EditorViewModel.self) private var editorViewModel
    @Environment(EntryListViewModel.self) private var entryListViewModel
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isHoveringFullscreen = false
    @State private var isHoveringNewEntry = false
    @State private var isHoveringThemeToggle = false
    @State private var isHoveringClock = false
    @Binding var isHoveringBottomNav: Bool
    
    var body: some View {
        @Bindable var entryListBindable = entryListViewModel
        
        HStack(spacing: 8) {
            Button(editorViewModel.isFullscreen ? "Minimize" : "Fullscreen") {
                if let window = NSApplication.shared.windows.first {
                    window.toggleFullScreen(nil)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(isHoveringFullscreen ? textHoverColor : textColor)
            .onHover { hovering in
                isHoveringFullscreen = hovering
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Text("•")
                .foregroundColor(.gray)
            
            Button(action: {
                let newText = entryListViewModel.createNewEntry()
                editorViewModel.text = newText
                editorViewModel.randomizePlaceholder()
            }) {
                Text("New Entry")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundColor(isHoveringNewEntry ? textHoverColor : textColor)
            .onHover { hovering in
                isHoveringNewEntry = hovering
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Text("•")
                .foregroundColor(.gray)
            
            Button(action: {
                settings.toggleTheme()
            }) {
                Image(systemName: settings.colorScheme == .light ? "moon.fill" : "sun.max.fill")
                    .foregroundColor(isHoveringThemeToggle ? textHoverColor : textColor)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringThemeToggle = hovering
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            Text("•")
                .foregroundColor(.gray)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    entryListBindable.showingSidebar.toggle()
                }
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(isHoveringClock ? textHoverColor : textColor)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringClock = hovering
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
    
    private var textColor: Color {
        return colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
    }
    
    private var textHoverColor: Color {
        return colorScheme == .light ? Color.black : Color.white
    }
}
