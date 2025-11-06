
import SwiftUI
import AppKit

struct FontSelectorView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.theme) private var theme
    
    @State private var hoveredFont: String? = nil
    @State private var isExpanded = false
    @State private var hoveredFontSize: String? = nil
    @State private var scrollAccumulator: CGFloat = 0
    @Binding var isHoveringBottomNav: Bool
    
    let availableFonts: [String]
    
    var body: some View {
        @Bindable var settingsBindable = settings
        
        HStack(spacing: 20) {
            if !isExpanded {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10))
                        .foregroundColor(textColor)
                    
                    Text("Font")
                        .font(.system(size: 13))
                        .foregroundColor(textColor)
                }
            }
            
            if isExpanded {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(textColor)
                
                ScrollableValueControl(
                    value: settings.fontSize,
                    formatter: { size in "\(Int(size))px" },
                    identifier: "fontSize",
                    minWidth: 50,
                    hoveredControl: $hoveredFontSize,
                    scrollAccumulator: $scrollAccumulator,
                    onScroll: adjustFontSize
                )
                
                Text("•")
                    .foregroundColor(theme.separatorColor)
                
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
                    .foregroundColor(theme.separatorColor)
                
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
                    .foregroundColor(theme.separatorColor)
                
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
                    .foregroundColor(theme.separatorColor)
                
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
                    .foregroundColor(theme.separatorColor)
                
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
                if hoveredFontSize == "fontSize" {
                    scrollAccumulator += event.deltaY
                    
                    if scrollAccumulator > 3 {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        adjustFontSize(by: 1)
                        scrollAccumulator = 0
                    } else if scrollAccumulator < -3 {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        adjustFontSize(by: -1)
                        scrollAccumulator = 0
                    }
                    return nil
                }
                return event
            }
        }
    }
    
    private var fontSizeButtonTitle: String {
        return "\(Int(settings.fontSize))px"
    }
    
    private var randomButtonTitle: String {
        return settings.currentRandomFont.isEmpty ? "Random" : "Random [\(settings.currentRandomFont)]"
    }
    
    private var textColor: Color {
        return theme.buttonText
    }
    
    private var textHoverColor: Color {
        return theme.buttonTextHover
    }
    
    private func adjustFontSize(by direction: Int) {
        settings.adjustFontSize(by: direction, from: AppConstants.fontSizes)
    }
}
