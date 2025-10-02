import SwiftUI

struct Theme {
    let backgroundColor: Color
    let surfaceColor: Color
    
    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color
    let placeholderText: Color
    
    let buttonText: Color
    let buttonTextHover: Color
    let accentColor: Color
    
    let dividerColor: Color
    let popoverBackground: Color
    
    let destructive: Color
    
    let selectedBackground: Color
    let hoveredBackground: Color
    
    let separatorColor: Color
    
    static let light = Theme(
        backgroundColor: .white,
        surfaceColor: .white,
        primaryText: Color(red: 0.20, green: 0.20, blue: 0.20),
        secondaryText: .gray,
        tertiaryText: Color.gray.opacity(0.8),
        placeholderText: Color.gray.opacity(0.5),
        buttonText: .gray,
        buttonTextHover: .black,
        accentColor: .blue,
        dividerColor: Color.gray.opacity(0.3),
        popoverBackground: Color(NSColor.controlBackgroundColor),
        destructive: .red,
        selectedBackground: Color.gray.opacity(0.1),
        hoveredBackground: Color.gray.opacity(0.05),
        separatorColor: .gray
    )
    
    static let dark = Theme(
        backgroundColor: .black,
        surfaceColor: .black,
        primaryText: Color(red: 0.9, green: 0.9, blue: 0.9),
        secondaryText: Color.gray.opacity(0.8),
        tertiaryText: Color.gray.opacity(0.6),
        placeholderText: Color.gray.opacity(0.6),
        buttonText: Color.gray.opacity(0.8),
        buttonTextHover: .white,
        accentColor: .blue,
        dividerColor: Color.gray.opacity(0.3),
        popoverBackground: Color(NSColor.darkGray),
        destructive: .red,
        selectedBackground: Color.gray.opacity(0.1),
        hoveredBackground: Color.gray.opacity(0.05),
        separatorColor: Color.gray.opacity(0.8)
    )
}

extension EnvironmentValues {
    @Entry var theme: Theme = .light
}

extension View {
    func theme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
    }
}
