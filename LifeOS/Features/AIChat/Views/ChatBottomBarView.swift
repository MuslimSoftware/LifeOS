//
//  ChatBottomBarView.swift
//  LifeOS
//
//  Created by Claude on 11/17/25.
//

import SwiftUI

/// Shimmer effect modifier for loading states
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if isActive {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.3)
                        .offset(x: geometry.size.width * phase - geometry.size.width * 0.3)
                        .blendMode(.overlay)
                        .allowsHitTesting(false)
                        .onAppear {
                            withAnimation(
                                Animation.linear(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                            ) {
                                phase = 1.3
                            }
                        }
                    }
                }
            )
            .clipped()
    }
}

extension View {
    func shimmer(isActive: Bool) -> some View {
        modifier(ShimmerEffect(isActive: isActive))
    }
}

/// Bottom bar showing embedding processing progress
struct ChatBottomBarView: View {
    @Environment(\.theme) private var theme
    @ObservedObject var embeddingService: EmbeddingProcessingService
    @State private var isHovering: Bool = false

    private var progressPercentage: Int {
        guard embeddingService.totalEntries > 0 else { return 0 }
        return Int((Double(embeddingService.processedEntries) / Double(embeddingService.totalEntries)) * 100)
    }

    private var isComplete: Bool {
        progressPercentage >= 100 && embeddingService.totalEntries > 0
    }

    private var displayText: String {
        if isHovering && !isComplete {
            let action = embeddingService.isProcessing ? "Cancel" : "Process"
            return "\(action) (\(progressPercentage)%)"
        } else {
            return "\(embeddingService.processedEntries)/\(embeddingService.totalEntries) entries (\(progressPercentage)%)"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Spacer()

            // Progress info
            HStack(spacing: 8) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.hoveredBackground)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHovering ? theme.buttonTextHover.opacity(0.6) : theme.secondaryText.opacity(0.6))
                            .frame(width: geometry.size.width * CGFloat(progressPercentage) / 100.0, height: 8)
                    }
                }
                .frame(width: 120, height: 8)

                // Text
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundColor(isHovering ? theme.buttonTextHover : theme.buttonText)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
            )
            .shimmer(isActive: embeddingService.isProcessing)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isComplete {
                    if embeddingService.isProcessing {
                        embeddingService.cancelProcessing()
                    } else {
                        embeddingService.processAllEntries()
                    }
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    if !isComplete {
                        NSCursor.pointingHand.set()
                    }
                case .ended:
                    NSCursor.arrow.set()
                }
            }
        }
        .padding(8)
        .padding()
        .frame(height: 60)
        .background(theme.backgroundColor)
    }
}

#Preview {
    @Previewable @StateObject var service = EmbeddingProcessingService.shared
    ChatBottomBarView(embeddingService: service)
}
