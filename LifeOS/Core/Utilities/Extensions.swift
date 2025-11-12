
import AppKit
import SwiftUI

func getLineHeight(font: NSFont) -> CGFloat {
    return font.ascender - font.descender + font.leading
}

extension NSView {
    func findTextView() -> NSView? {
        if self is NSTextView {
            return self
        }
        for subview in subviews {
            if let textView = subview.findTextView() {
                return textView
            }
        }
        return nil
    }
}

extension NSView {
    func findSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let typedSelf = self as? T {
            return typedSelf
        }
        for subview in subviews {
            if let found = subview.findSubview(ofType: type) {
                return found
            }
        }
        return nil
    }
}

// MARK: - Scrollbar Hiding

struct HideScrollIndicatorsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ScrollViewConfigurator())
    }
}

struct ScrollViewConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        DispatchQueue.main.async {
            // Find the NSScrollView in the view hierarchy
            if let scrollView = view.superview?.superview?.findSubview(ofType: NSScrollView.self) {
                configureScrollView(scrollView)
            } else if let hostView = view.superview {
                // Search more aggressively for nested scroll views
                var currentView: NSView? = hostView
                for _ in 0..<5 { // Search up to 5 levels
                    if let scrollView = currentView?.findSubview(ofType: NSScrollView.self) {
                        configureScrollView(scrollView)
                        break
                    }
                    currentView = currentView?.superview
                }
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    private func configureScrollView(_ scrollView: NSScrollView) {
        // Use overlay scroller style (auto-hiding, appears only when scrolling)
        scrollView.scrollerStyle = .overlay
        
        // Keep scrollers enabled so they can appear when scrolling
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        
        // Enable auto-hiding (scrollers disappear when not in use)
        scrollView.autohidesScrollers = true
        
        // Use light knob style for better visibility when it appears
        scrollView.scrollerKnobStyle = .light
    }
}

extension View {
    func hideScrollIndicators() -> some View {
        self.modifier(HideScrollIndicatorsModifier())
    }
}
