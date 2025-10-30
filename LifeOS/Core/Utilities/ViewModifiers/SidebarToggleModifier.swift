import SwiftUI
import AppKit

struct SidebarToggleModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @Environment(\.theme) private var theme

    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topLeading) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        settings.toggleSidebar()
                    }
                    // Announce state change for VoiceOver
                    let message = settings.isSidebarCollapsed ? "Sidebar hidden" : "Sidebar shown"
                    NSAccessibility.post(element: NSApp.mainWindow as Any, notification: .announcementRequested, userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
                }) {
                    Image(systemName: settings.isSidebarCollapsed ? "line.3.horizontal" : "chevron.left")
                        .font(.system(size: 15))
                        .foregroundColor(isHovered ? theme.buttonTextHover : theme.buttonText)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isHovered ? theme.hoveredBackground : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.top, 16)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .accessibilityLabel("Toggle sidebar")
                .accessibilityHint(settings.isSidebarCollapsed ? "Double tap to show the sidebar" : "Double tap to hide the sidebar")
                .accessibilityAddTraits(.isButton)
                .help(settings.isSidebarCollapsed ? "Show sidebar" : "Hide sidebar")
            }
    }
}

extension View {
    func withSidebarToggle() -> some View {
        self.modifier(SidebarToggleModifier())
    }
}
