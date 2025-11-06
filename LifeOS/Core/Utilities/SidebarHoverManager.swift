import SwiftUI
import AppKit

@Observable
class SidebarHoverManager {
    // Sidebar states
    var isLeftSidebarOpen: Bool = false
    private var rightSidebarOpenStates: [NavigationRoute: Bool] = [:]

    // Pin states (persisted)
    var isLeftSidebarPinned: Bool = false
    private var rightSidebarPinnedStates: [NavigationRoute: Bool] = [:]

    var isLeftModalOpen: Bool = false
    var isRightModalOpen: Bool = false

    // Current route for right sidebar tracking
    var currentRoute: NavigationRoute = .calendar

    // Hover detection parameters
    private let edgeThreshold: CGFloat = 10.0  // pixels from edge to trigger
    private var trackingArea: NSTrackingArea?
    private var mouseMonitor: Any?

    init() {
        // Load pin states from UserDefaults
        self.isLeftSidebarPinned = UserDefaults.standard.bool(forKey: "isLeftSidebarPinned")

        // Load per-route right sidebar pin states
        for route in NavigationRoute.allCases {
            let key = "isRightSidebarPinned_\(route.rawValue)"
            rightSidebarPinnedStates[route] = UserDefaults.standard.bool(forKey: key)
            rightSidebarOpenStates[route] = rightSidebarPinnedStates[route] ?? false
        }

        // Set initial open state for left sidebar based on pin
        self.isLeftSidebarOpen = isLeftSidebarPinned

        setupMouseTracking()
    }

    func setupMouseTracking() {
        // Monitor global mouse movements
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove(event)
        }

        // Also monitor local events (within app)
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove(event)
            return event
        }
    }

    func isRightSidebarOpen(for route: NavigationRoute) -> Bool {
        return rightSidebarOpenStates[route] ?? false
    }

    func isRightSidebarPinned(for route: NavigationRoute) -> Bool {
        return rightSidebarPinnedStates[route] ?? false
    }

    func setRightSidebarOpen(_ isOpen: Bool, for route: NavigationRoute) {
        rightSidebarOpenStates[route] = isOpen
    }

    func setRightSidebarPinned(_ isPinned: Bool, for route: NavigationRoute) {
        rightSidebarPinnedStates[route] = isPinned
        let key = "isRightSidebarPinned_\(route.rawValue)"
        UserDefaults.standard.set(isPinned, forKey: key)

        if isPinned {
            rightSidebarOpenStates[route] = true
        }
    }

    private func handleMouseMove(_ event: NSEvent) {
        guard let window = NSApp.mainWindow else { return }

        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame

        // Convert to window coordinates
        let relativeX = mouseLocation.x - windowFrame.origin.x

        // Left edge detection
        if !isLeftSidebarPinned {
            if relativeX <= edgeThreshold {
                isLeftSidebarOpen = true
            } else if relativeX > 200 && !isLeftModalOpen {
                isLeftSidebarOpen = false
            }
        }

        // Right edge detection - use current route
        if !isRightSidebarPinned(for: currentRoute) {
            if relativeX >= windowFrame.width - edgeThreshold {
                setRightSidebarOpen(true, for: currentRoute)
            } else if relativeX < windowFrame.width - 220 && !isRightModalOpen {
                setRightSidebarOpen(false, for: currentRoute)
            }
        }
    }

    func toggleLeftPin() {
        isLeftSidebarPinned.toggle()
        UserDefaults.standard.set(isLeftSidebarPinned, forKey: "isLeftSidebarPinned")

        if isLeftSidebarPinned {
            isLeftSidebarOpen = true
        }
    }

    func toggleRightPin(for route: NavigationRoute) {
        let currentPinState = isRightSidebarPinned(for: route)
        setRightSidebarPinned(!currentPinState, for: route)
    }

    func openLeftSidebarWithPin() {
        isLeftSidebarOpen = true
        isLeftSidebarPinned = true
        UserDefaults.standard.set(true, forKey: "isLeftSidebarPinned")
    }

    func openRightSidebarWithPin(for route: NavigationRoute) {
        setRightSidebarOpen(true, for: route)
        setRightSidebarPinned(true, for: route)
    }

    func hasRightSidebar(for route: NavigationRoute) -> Bool {
        switch route {
        case .aiChat, .journal:
            return true
        case .calendar:
            return false
        }
    }

    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
