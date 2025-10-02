
import SwiftUI
import AppKit

struct FontSelectorView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var hoveredFont: String? = nil
    @State private var isHoveringSize = false
    @Binding var isHoveringBottomNav: Bool
    
    let availableFonts: [String]
    
    var body: some View {
        @Bindable var settingsBindable = settings
        
        HStack(spacing: 8) {
            Button(fontSizeButtonTitle) {
                settings.cycleFontSize(from: AppConstants.fontSizes)
            }
            .buttonStyle(.plain)
            .foregroundColor(isHoveringSize ? textHoverColor : textColor)
            .onHover { hovering in
                isHoveringSize = hovering
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Text("•")
                .foregroundColor(.gray)
            
            Button("Lato") {
                settings.cycleFont(to: "Lato-Regular")
            }
            .buttonStyle(.plain)
            .foregroundColor(hoveredFont == "Lato" ? textHoverColor : textColor)
            .onHover { hovering in
                hoveredFont = hovering ? "Lato" : nil
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Text("•")
                .foregroundColor(.gray)
            
            Button("Arial") {
                settings.cycleFont(to: "Arial")
            }
            .buttonStyle(.plain)
            .foregroundColor(hoveredFont == "Arial" ? textHoverColor : textColor)
            .onHover { hovering in
                hoveredFont = hovering ? "Arial" : nil
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Text("•")
                .foregroundColor(.gray)
            
            Button("System") {
                settings.cycleFont(to: ".AppleSystemUIFont")
            }
            .buttonStyle(.plain)
            .foregroundColor(hoveredFont == "System" ? textHoverColor : textColor)
            .onHover { hovering in
                hoveredFont = hovering ? "System" : nil
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Text("•")
                .foregroundColor(.gray)
            
            Button("Serif") {
                settings.cycleFont(to: "Times New Roman")
            }
            .buttonStyle(.plain)
            .foregroundColor(hoveredFont == "Serif" ? textHoverColor : textColor)
            .onHover { hovering in
                hoveredFont = hovering ? "Serif" : nil
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            
            Text("•")
                .foregroundColor(.gray)
            
            Button(randomButtonTitle) {
                settings.setRandomFont(from: availableFonts)
            }
            .buttonStyle(.plain)
            .foregroundColor(hoveredFont == "Random" ? textHoverColor : textColor)
            .onHover { hovering in
                hoveredFont = hovering ? "Random" : nil
                isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(8)
        .cornerRadius(6)
        .onHover { hovering in
            isHoveringBottomNav = hovering
        }
    }
    
    private var fontSizeButtonTitle: String {
        return "\(Int(settings.fontSize))px"
    }
    
    private var randomButtonTitle: String {
        return settings.currentRandomFont.isEmpty ? "Random" : "Random [\(settings.currentRandomFont)]"
    }
    
    private var textColor: Color {
        return colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
    }
    
    private var textHoverColor: Color {
        return colorScheme == .light ? Color.black : Color.white
    }
}
