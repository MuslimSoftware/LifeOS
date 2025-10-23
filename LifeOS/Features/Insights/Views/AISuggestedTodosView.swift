//
//  AISuggestedTodosView.swift
//  LifeOS
//
//  Created by Claude on 10/22/25.
//

import SwiftUI

/// Expandable todo suggestions from AI, grouped by theme
struct AISuggestedTodosView: View {
    let todos: [AISuggestedTodo]
    let onAdd: (AISuggestedTodo) -> Void

    private var groupedTodos: [String: [AISuggestedTodo]] {
        Dictionary(grouping: todos, by: { $0.theme })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Suggestions")
                    .font(.headline)
                    .foregroundColor(.purple)
                Text("(\(todos.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ForEach(groupedTodos.keys.sorted(), id: \.self) { theme in
                if let themeTodos = groupedTodos[theme] {
                    themeSection(theme: theme, todos: themeTodos)
                }
            }
        }
    }

    private func themeSection(theme: String, todos: [AISuggestedTodo]) -> some View {
        DisclosureGroup {
            VStack(spacing: 12) {
                ForEach(todos) { todo in
                    todoCard(todo)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text(themeIcon(theme))
                    .font(.body)
                Text(theme.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(todos.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func todoCard(_ todo: AISuggestedTodo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.body)
                        .fontWeight(.semibold)

                    Text(todo.firstStep)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }

                Spacer()

                Button(action: { onAdd(todo) }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
            }

            DisclosureGroup {
                Text(todo.whyItMatters)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } label: {
                Text("Why it matters")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }

            HStack {
                Label("\(todo.estimatedMinutes) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private func themeIcon(_ theme: String) -> String {
        let lowercased = theme.lowercased()
        if lowercased.contains("work") || lowercased.contains("career") {
            return "💼"
        } else if lowercased.contains("health") {
            return "❤️"
        } else if lowercased.contains("relationship") || lowercased.contains("social") {
            return "👥"
        } else if lowercased.contains("financial") {
            return "💰"
        } else {
            return "✨"
        }
    }
}

#Preview {
    AISuggestedTodosView(
        todos: [
            AISuggestedTodo(
                title: "Break down project into smaller tasks",
                firstStep: "List all project deliverables in a document",
                whyItMatters: "Reduce overwhelm by having a clear roadmap",
                theme: "work",
                estimatedMinutes: 30
            ),
            AISuggestedTodo(
                title: "Schedule weekly review",
                firstStep: "Block Friday 4pm on calendar",
                whyItMatters: "Stay on track with goals and adjust plans",
                theme: "work",
                estimatedMinutes: 15
            ),
            AISuggestedTodo(
                title: "Establish bedtime routine",
                firstStep: "Set phone alarm for 30min before target bedtime",
                whyItMatters: "Better sleep will improve energy and mood",
                theme: "health",
                estimatedMinutes: 15
            )
        ],
        onAdd: { _ in }
    )
    .padding()
}
