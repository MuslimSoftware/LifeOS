
import SwiftUI
import AppKit

struct UtilityButtonsView: View {
    @Environment(\.theme) private var theme
    @Binding var isHoveringBottomNav: Bool
    
    var body: some View {
        EmptyView()
    }
    
    private var textColor: Color {
        return theme.buttonText
    }
    
    private var textHoverColor: Color {
        return theme.buttonTextHover
    }
}
