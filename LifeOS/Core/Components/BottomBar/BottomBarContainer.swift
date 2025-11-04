import SwiftUI

struct BottomBarContainer<Content: View>: View {
    @Environment(\.theme) private var theme

    let height: CGFloat
    let content: Content

    init(
        height: CGFloat = 60,
        @ViewBuilder content: () -> Content
    ) {
        self.height = height
        self.content = content()
    }

    var body: some View {
        VStack {
            Spacer()

            HStack {
                content
            }
            .padding()
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(theme.backgroundColor)
        }
    }
}

struct OpacityBottomBarContainer<Content: View>: View {
    @Environment(\.theme) private var theme

    let height: CGFloat
    let opacity: Double
    let onHover: (Bool) -> Void
    let content: Content

    init(
        height: CGFloat = 60,
        opacity: Double,
        onHover: @escaping (Bool) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.height = height
        self.opacity = opacity
        self.onHover = onHover
        self.content = content()
    }

    var body: some View {
        VStack {
            Spacer()

            HStack {
                content
            }
            .padding()
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(theme.backgroundColor)
            .opacity(opacity)
            .onHover { hovering in
                onHover(hovering)
            }
        }
    }
}
