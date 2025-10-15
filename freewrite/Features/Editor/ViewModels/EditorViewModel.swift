
import SwiftUI
import AppKit

@Observable
class EditorViewModel {
    var text: String = ""
    var placeholderText: String = ""
    var isLoadingContent: Bool = false

    var timeRemaining: Int = AppConstants.defaultTimerDuration
    var timerIsRunning = false
    var lastClickTime: Date? = nil

    var isFullscreen = false
    var bottomNavOpacity: Double = 1.0
    var isHoveringBottomNav = false
    
    private let fileService: FileManagerService
    let settings: AppSettings
    
    var lineHeight: CGFloat {
        let font = NSFont(name: settings.selectedFont, size: settings.fontSize) ?? .systemFont(ofSize: settings.fontSize)
        let defaultLineHeight = getLineHeight(font: font)
        return (settings.fontSize * 1.5) - defaultLineHeight
    }
    
    var placeholderOffset: CGFloat {
        return settings.fontSize / 2
    }
    
    init(fileService: FileManagerService, settings: AppSettings) {
        self.fileService = fileService
        self.settings = settings
        self.placeholderText = AppConstants.placeholderOptions.randomElement() ?? "Begin writing"
    }
    
    func toggleTimer() {
        let now = Date()
        if let lastClick = lastClickTime,
           now.timeIntervalSince(lastClick) < 0.3 {
            timeRemaining = AppConstants.defaultTimerDuration
            timerIsRunning = false
            lastClickTime = nil
        } else {
            timerIsRunning.toggle()
            lastClickTime = now
        }
    }
    
    func timerTick() {
        if timerIsRunning && timeRemaining > 0 {
            timeRemaining -= 1
        } else if timeRemaining == 0 {
            timerIsRunning = false
            if !isHoveringBottomNav {
                withAnimation(.easeOut(duration: 1.0)) {
                    bottomNavOpacity = 1.0
                }
            }
        }
    }
    
    func adjustTimerWithScroll(_ delta: CGFloat) {
        let scrollBuffer = delta * 0.25
        
        if abs(scrollBuffer) >= 0.1 {
            let currentMinutes = timeRemaining / 60
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            let direction = -scrollBuffer > 0 ? 5 : -5
            let newMinutes = currentMinutes + direction
            let roundedMinutes = (newMinutes / 5) * 5
            let newTime = roundedMinutes * 60
            timeRemaining = min(max(newTime, 0), 2700)
        }
    }
    
    func randomizePlaceholder() {
        placeholderText = AppConstants.placeholderOptions.randomElement() ?? "Begin writing"
    }
    
    func timerButtonTitle() -> String {
        if !timerIsRunning && timeRemaining == AppConstants.defaultTimerDuration {
            return "15:00"
        }
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
