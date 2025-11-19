//
//  TypingIndicatorView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Animated typing indicator shown while AI is thinking
struct TypingIndicatorView: View {
    @Environment(\.theme) private var theme
    @State private var offset: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                            .offset(y: offset)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: offset
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.hoveredBackground)
                .cornerRadius(16)
            }
            .frame(maxWidth: 600, alignment: .leading)

            Spacer(minLength: 0)
        }
        .onAppear {
            offset = -5
        }
    }
}

#Preview {
    TypingIndicatorView()
        .padding()
}
