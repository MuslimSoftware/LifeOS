//
//  ChatHistoryView.swift
//  LifeOS
//
//  Created by Claude on 10/26/25.
//

import SwiftUI

/// Sidebar showing conversation list grouped by date
struct ChatHistoryView: View {
    @Environment(\.theme) private var theme
    @Environment(SidebarHoverManager.self) private var hoverManager
    let conversations: [Conversation]
    let currentConversationId: UUID?
    let onConversationTap: (UUID) -> Void
    let onDeleteConversation: (UUID) -> Void
    let onCopyConversation: (UUID) -> Void
    let onNewConversation: () -> Void

    @State private var isHoveringNewChat = false
    @State private var isHoveringPin = false
    @State private var hoveredConversationId: UUID?
    @State private var hoveredTrashId: UUID?
    @State private var hoveredCopyId: UUID?
    @State private var conversationToDelete: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with Pin button and New Chat button
            HStack {
                // Pin button (on left/inner edge)
                Button(action: {
                    hoverManager.toggleRightPin(for: .aiChat)
                }) {
                    Image(systemName: hoverManager.isRightSidebarPinned(for: .aiChat) ? "chevron.right.2" : "line.horizontal.3")
                        .foregroundColor(isHoveringPin ? theme.buttonTextHover : theme.buttonText)
                        .font(.system(size: 12))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isHoveringPin ? theme.hoveredBackground : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringPin = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .accessibilityLabel(hoverManager.isRightSidebarPinned(for: .aiChat) ? "Unpin sidebar" : "Pin sidebar")
                .help(hoverManager.isRightSidebarPinned(for: .aiChat) ? "Unpin sidebar" : "Pin sidebar")

                Spacer()

                // New Chat button (on right/outer edge)
                Button(action: onNewConversation) {
                    HStack {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 13))
                            .foregroundColor(isHoveringNewChat ? theme.buttonTextHover : theme.buttonText)
                        Text("New Chat")
                            .font(.system(size: 13))
                            .foregroundColor(isHoveringNewChat ? theme.buttonTextHover : theme.buttonText)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New Chat")
                .accessibilityHint("Double tap to start a new conversation")
                .accessibilityAddTraits(.isButton)
                .onHover { hovering in
                    isHoveringNewChat = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Conversation list
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedConversations(), id: \.date) { group in
                        Section {
                            ForEach(group.conversations) { conversation in
                                ConversationRow(
                                    conversation: conversation,
                                    isSelected: currentConversationId == conversation.id,
                                    isHovered: hoveredConversationId == conversation.id,
                                    hoveredTrashId: hoveredTrashId,
                                    hoveredCopyId: hoveredCopyId,
                                    onTap: { onConversationTap(conversation.id) },
                                    onDelete: { conversationToDelete = conversation.id },
                                    onCopy: { onCopyConversation(conversation.id) },
                                    onTrashHover: { hovering in
                                        hoveredTrashId = hovering ? conversation.id : nil
                                    },
                                    onCopyHover: { hovering in
                                        hoveredCopyId = hovering ? conversation.id : nil
                                    }
                                )
                                .onHover { hovering in
                                    hoveredConversationId = hovering ? conversation.id : nil
                                }

                                if conversation.id != group.conversations.last?.id {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        } header: {
                            DateHeaderView(date: group.date)
                        }
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .frame(width: 200)
        .background(theme.backgroundColor)
        .alert("Delete Conversation", isPresented: Binding(
            get: { conversationToDelete != nil },
            set: { if !$0 { conversationToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                conversationToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let id = conversationToDelete {
                    onDeleteConversation(id)
                }
                conversationToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }
    }

    private func groupedConversations() -> [(date: Date, conversations: [Conversation])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: conversations) { conversation in
            calendar.startOfDay(for: conversation.updatedAt)
        }
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, conversations: $0.value.sorted { $0.updatedAt > $1.updatedAt }) }
    }
}

// MARK: - Date Header View
struct DateHeaderView: View {
    @Environment(\.theme) private var theme
    let date: Date

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.buttonText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            Spacer()
        }
        .background(theme.backgroundColor)
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let conversationDate = calendar.startOfDay(for: date)

        if conversationDate == today {
            return "Today"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), conversationDate == yesterday {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Conversation Row
struct ConversationRow: View {
    @Environment(\.theme) private var theme
    let conversation: Conversation
    let isSelected: Bool
    let isHovered: Bool
    let hoveredTrashId: UUID?
    let hoveredCopyId: UUID?
    let onTap: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onTrashHover: (Bool) -> Void
    let onCopyHover: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(conversation.title)
                    .font(.system(size: 11))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11))
                            .foregroundColor(hoveredCopyId == conversation.id ? theme.buttonTextHover : theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy conversation")
                    .accessibilityHint("Double tap to copy conversation to clipboard")
                    .accessibilityAddTraits(.isButton)
                    .onHover { hovering in
                        onCopyHover(hovering)
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(hoveredTrashId == conversation.id ? theme.destructive : theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete conversation")
                    .accessibilityHint("Double tap to delete this conversation")
                    .accessibilityAddTraits(.isButton)
                    .onHover { hovering in
                        onTrashHover(hovering)
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .frame(width: isHovered ? nil : 0)
                .clipped()
                .opacity(isHovered ? 1.0 : 0.0)
            }

            HStack(spacing: 4) {
                Text("\(conversation.messages.count) messages")
                    .font(.system(size: 9))
                    .foregroundColor(theme.secondaryText)

                Text("•")
                    .font(.system(size: 9))
                    .foregroundColor(theme.secondaryText)

                Text(conversation.updatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 9))
                    .foregroundColor(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            // Subtle background for both selected and hovered states
            (isSelected || isHovered ? theme.hoveredBackground : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Conversation: \(conversation.title)")
        .accessibilityValue("\(conversation.messages.count) messages, updated \(conversation.updatedAt.formatted(date: .omitted, time: .shortened))")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to open this conversation")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
