import SwiftUI
import AppKit

@Observable
class SidebarHoverManager {
    // Sidebar states
    var isLeftSidebarOpen: Bool = false
    var isRightSidebarOpen: Bool = false

    // Pin states (persisted)
    var isLeftSidebarPinned: Bool = false
    var isRightSidebarPinned: Bool = false

    // Hover detection parameters
    private let edgeThreshold: CGFloat = 10.0  // pixels from edge to trigger
    private var trackingArea: NSTrackingArea?
    private var mouseMonitor: Any?

    init() {
        // Load pin states from UserDefaults
        self.isLeftSidebarPinned = UserDefaults.standard.bool(forKey: "isLeftSidebarPinned")
        self.isRightSidebarPinned = UserDefaults.standard.bool(forKey: "isRightSidebarPinned")

        // Set initial open states based on pin
        self.isLeftSidebarOpen = isLeftSidebarPinned
        self.isRightSidebarOpen = isRightSidebarPinned

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

    private func handleMouseMove(_ event: NSEvent) {
        guard let window = NSApp.mainWindow,
              let screen = window.screen else { return }

        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame

        // Convert to window coordinates
        let relativeX = mouseLocation.x - windowFrame.origin.x

        // Left edge detection
        if !isLeftSidebarPinned {
            if relativeX <= edgeThreshold {
                isLeftSidebarOpen = true
            } else if relativeX > 200 { // Beyond sidebar width + buffer
                isLeftSidebarOpen = false
            }
        }

        // Right edge detection
        if !isRightSidebarPinned {
            if relativeX >= windowFrame.width - edgeThreshold {
                isRightSidebarOpen = true
            } else if relativeX < windowFrame.width - 220 { // Beyond sidebar width + buffer
                isRightSidebarOpen = false
            }
        }
    }

    func toggleLeftPin() {
        isLeftSidebarPinned.toggle()
        UserDefaults.standard.set(isLeftSidebarPinned, forKey: "isLeftSidebarPinned")

        // When pinned, ensure sidebar is open
        if isLeftSidebarPinned {
            isLeftSidebarOpen = true
        }
    }

    func toggleRightPin() {
        isRightSidebarPinned.toggle()
        UserDefaults.standard.set(isRightSidebarPinned, forKey: "isRightSidebarPinned")

        // When pinned, ensure sidebar is open
        if isRightSidebarPinned {
            isRightSidebarOpen = true
        }
    }

    func openLeftSidebarWithPin() {
        isLeftSidebarOpen = true
        isLeftSidebarPinned = true
        UserDefaults.standard.set(true, forKey: "isLeftSidebarPinned")
    }

    func openRightSidebarWithPin() {
        isRightSidebarOpen = true
        isRightSidebarPinned = true
        UserDefaults.standard.set(true, forKey: "isRightSidebarPinned")
    }

    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
