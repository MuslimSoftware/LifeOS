import SwiftUI

enum NavigationRoute: String, CaseIterable {
    case home = "Home"
    case journal = "Journal"
    case calendar = "Calendar"
}

struct SidebarView: View {
    @Environment(\.theme) private var theme
    @Binding var selectedRoute: NavigationRoute
    
    @State private var hoveredRoute: NavigationRoute? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer()
                .frame(height: 24)
            
            ForEach(NavigationRoute.allCases, id: \.self) { route in
                Button(action: {
                    selectedRoute = route
                }) {
                    Text(route.rawValue)
                        .font(.system(size: 15, weight: selectedRoute == route ? .semibold : .regular))
                        .foregroundColor(textColorFor(route))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(backgroundColorFor(route))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredRoute = hovering ? route : nil
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(width: 160)
        .background(theme.surfaceColor)
    }
    
    private func backgroundColorFor(_ route: NavigationRoute) -> Color {
        if selectedRoute == route {
            return theme.selectedBackground
        } else if hoveredRoute == route {
            return theme.hoveredBackground
        }
        return Color.clear
    }
    
    private func textColorFor(_ route: NavigationRoute) -> Color {
        if selectedRoute == route || hoveredRoute == route {
            return theme.buttonTextHover
        }
        return theme.buttonText
    }
}
