import SwiftUI

struct EdgeHintView: View {
    @Environment(\.theme) private var theme
    let isLeftEdge: Bool
    let isVisible: Bool

    @State private var isPulsing = false

    var body: some View {
        if isVisible {
            Image(systemName: isLeftEdge ? "chevron.right" : "chevron.left")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.buttonText.opacity(0.3))
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.hoveredBackground.opacity(0.5))
                )
                .opacity(isPulsing ? 0.4 : 0.7)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .padding(isLeftEdge ? .leading : .trailing, 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isLeftEdge ? .leading : .trailing)
                .allowsHitTesting(false)
                .onAppear {
                    isPulsing = true
                }
        }
    }
}

#Preview("Left Edge") {
    EdgeHintView(isLeftEdge: true, isVisible: true)
        .frame(width: 400, height: 600)
        .background(Color.gray.opacity(0.1))
}

#Preview("Right Edge") {
    EdgeHintView(isLeftEdge: false, isVisible: true)
        .frame(width: 400, height: 600)
        .background(Color.gray.opacity(0.1))
}
