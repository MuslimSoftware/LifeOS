import SwiftUI

enum NavigationRoute: String, CaseIterable {
    case calendar = "Calendar"
    case journal = "Journal"
}

struct SidebarView: View {
    @Environment(\.theme) private var theme
    @Environment(AppSettings.self) private var settings
    @Binding var selectedRoute: NavigationRoute
    
    @State private var hoveredRoute: NavigationRoute? = nil
    @State private var isHoveringThemeToggle = false
    @State private var isHoveringSettings = false
    @State private var showSettings = false
    
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
                .focusable(false)
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
            
            HStack(spacing: 12) {
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(isHoveringSettings ? theme.buttonTextHover : theme.buttonText)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .onHover { hovering in
                    isHoveringSettings = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                
                Spacer()
                
                Button(action: {
                    settings.toggleTheme()
                }) {
                    Image(systemName: settings.colorScheme == .light ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(isHoveringThemeToggle ? theme.buttonTextHover : theme.buttonText)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .onHover { hovering in
                    isHoveringThemeToggle = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .padding(.trailing, 4)
            }
            .padding(.bottom, 16)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 12)
        .frame(width: 160)
        .background(theme.surfaceColor)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
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
