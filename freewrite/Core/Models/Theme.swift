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
        backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.12),
        surfaceColor: Color(red: 0.12, green: 0.12, blue: 0.12),
        primaryText: Color(red: 0.95, green: 0.95, blue: 0.95),
        secondaryText: Color(red: 0.65, green: 0.65, blue: 0.65),
        tertiaryText: Color(red: 0.5, green: 0.5, blue: 0.5),
        placeholderText: Color(red: 0.5, green: 0.5, blue: 0.5),
        buttonText: Color(red: 0.65, green: 0.65, blue: 0.65),
        buttonTextHover: Color(red: 0.95, green: 0.95, blue: 0.95),
        accentColor: Color(red: 0.4, green: 0.6, blue: 1.0),
        dividerColor: Color(red: 0.3, green: 0.3, blue: 0.3),
        popoverBackground: Color(red: 0.15, green: 0.15, blue: 0.15),
        destructive: .red,
        selectedBackground: Color(red: 0.2, green: 0.2, blue: 0.2),
        hoveredBackground: Color(red: 0.17, green: 0.17, blue: 0.17),
        separatorColor: Color(red: 0.5, green: 0.5, blue: 0.5)
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
