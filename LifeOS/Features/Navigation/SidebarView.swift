import SwiftUI

enum NavigationRoute: String, CaseIterable {
    case calendar = "Calendar"
    case journal = "Journal"
    case aiChat = "Chat"
}

struct SidebarView: View {
    @Environment(\.theme) private var theme
    @Environment(AppSettings.self) private var settings
    @Binding var selectedRoute: NavigationRoute

    @State private var hoveredRoute: NavigationRoute? = nil
    @State private var isHoveringThemeToggle = false
    @State private var isHoveringSettings = false
    @State private var isHoveringClose = false
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Top section with close button
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        settings.toggleSidebar()
                    }
                    // Announce state change for VoiceOver
                    NSAccessibility.post(element: NSApp.mainWindow as Any, notification: .announcementRequested, userInfo: [.announcement: "Sidebar hidden", .priority: NSAccessibilityPriorityLevel.high.rawValue])
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(isHoveringClose ? theme.buttonTextHover : theme.buttonText)
                        .font(.system(size: 12))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isHoveringClose ? theme.hoveredBackground : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .onHover { hovering in
                    isHoveringClose = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .accessibilityLabel("Close sidebar")
                .accessibilityHint("Double tap to close the sidebar")
                .accessibilityAddTraits(.isButton)
                .help("Close sidebar")
            }
            .padding(.top, 12)
            .padding(.trailing, 4)

            Spacer()
                .frame(height: 12)
            
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
                .accessibilityLabel("\(route.rawValue) page")
                .accessibilityHint(selectedRoute == route ? "Currently selected" : "Double tap to navigate")
                .accessibilityAddTraits(selectedRoute == route ? [.isButton, .isSelected] : .isButton)
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
                .accessibilityLabel("Settings")
                .accessibilityHint("Double tap to open settings")
                .accessibilityAddTraits(.isButton)
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
                .accessibilityLabel("Toggle theme")
                .accessibilityHint(settings.colorScheme == .light ? "Double tap to switch to dark mode" : "Double tap to switch to light mode")
                .accessibilityAddTraits(.isButton)
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
