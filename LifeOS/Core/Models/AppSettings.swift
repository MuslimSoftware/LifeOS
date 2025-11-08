
import SwiftUI
import AppKit

@Observable
class AppSettings {
    var colorScheme: ColorScheme? = nil  // nil = system
    var selectedFont: String = "Lato-Regular"
    var fontSize: CGFloat = 18
    var currentRandomFont: String = ""

    var currentTheme: Theme {
        if let scheme = colorScheme {
            return scheme == .light ? .light : .dark
        }
        // System theme - use actual system appearance
        return NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }

    // Note: sidebarWidth kept for backward compatibility but will be controlled by SidebarHoverManager
    var sidebarWidth: CGFloat {
        160
    }

    init() {
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme")
        if savedScheme == "system" || savedScheme == nil {
            colorScheme = nil  // System
        } else {
            colorScheme = savedScheme == "dark" ? .dark : .light
        }
    }
    
    func setTheme(_ scheme: ColorScheme?) {
        colorScheme = scheme
        if let scheme = scheme {
            UserDefaults.standard.set(scheme == .light ? "light" : "dark", forKey: "colorScheme")
        } else {
            UserDefaults.standard.set("system", forKey: "colorScheme")
        }
    }
    
    func toggleTheme() {
        if colorScheme == nil {
            colorScheme = .light
        } else if colorScheme == .light {
            colorScheme = .dark
        } else {
            colorScheme = nil
        }
        setTheme(colorScheme)
    }
    
    func cycleFont(to font: String) {
        selectedFont = font
        currentRandomFont = ""
    }
    
    func setRandomFont(from availableFonts: [String]) {
        if let randomFont = availableFonts.randomElement() {
            selectedFont = randomFont
            currentRandomFont = randomFont
        }
    }
    
    func cycleFontSize(from sizes: [CGFloat]) {
        if let currentIndex = sizes.firstIndex(of: fontSize) {
            let nextIndex = (currentIndex + 1) % sizes.count
            fontSize = sizes[nextIndex]
        }
    }
    
    func adjustFontSize(by direction: Int, from sizes: [CGFloat]) {
        if let currentIndex = sizes.firstIndex(of: fontSize) {
            let newIndex = max(0, min(sizes.count - 1, currentIndex + direction))
            fontSize = sizes[newIndex]
        }
    }
}
