
import SwiftUI

@Observable
class AppSettings {
    var colorScheme: ColorScheme = .light
    var selectedFont: String = "Lato-Regular"
    var fontSize: CGFloat = 18
    var currentRandomFont: String = ""

    var isSidebarCollapsed: Bool = false

    var currentTheme: Theme {
        colorScheme == .light ? .light : .dark
    }

    var sidebarWidth: CGFloat {
        isSidebarCollapsed ? 0 : 160
    }
    
    init() {
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "light"
        colorScheme = savedScheme == "dark" ? .dark : .light

        isSidebarCollapsed = UserDefaults.standard.bool(forKey: "isSidebarCollapsed")
    }
    
    func toggleTheme() {
        colorScheme = colorScheme == .light ? .dark : .light
        UserDefaults.standard.set(colorScheme == .light ? "light" : "dark", forKey: "colorScheme")
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

    func toggleSidebar() {
        isSidebarCollapsed.toggle()
        UserDefaults.standard.set(isSidebarCollapsed, forKey: "isSidebarCollapsed")
    }
}
