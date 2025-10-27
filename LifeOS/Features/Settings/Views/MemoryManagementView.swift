import SwiftUI

struct MemoryManagementView: View {
    @Environment(\.theme) private var theme
    @ObservedObject var viewModel: MemoryManagementViewModel
    @State private var showDeleteAllConfirmation = false
    @State private var memoryToDelete: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            header

            // Filters
            filtersSection

            // Stats
            statsSection

            Divider()
                .background(theme.dividerColor)

            // Memory List
            if viewModel.isLoading {
                ProgressView("Loading memories...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredMemories.isEmpty {
                emptyState
            } else {
                memoryList
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .task {
            await viewModel.loadMemories()
        }
        .alert("Delete All Memories", isPresented: $showDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                Task {
                    await viewModel.deleteAllMemories()
                }
            }
        } message: {
            Text("Are you sure you want to delete all \(viewModel.totalCount) memories? This action cannot be undone.")
        }
        .alert("Delete Memory", isPresented: Binding(
            get: { memoryToDelete != nil },
            set: { if !$0 { memoryToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                memoryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let id = memoryToDelete {
                    Task {
                        await viewModel.deleteMemory(id: id)
                    }
                }
                memoryToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this memory?")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Agent Memories")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text("Insights and patterns saved by the AI assistant")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            if viewModel.totalCount > 0 {
                Button(action: {
                    showDeleteAllConfirmation = true
                }) {
                    Label("Delete All", systemImage: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Filters

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.secondaryText)
                TextField("Search memories...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(theme.surfaceColor)
            .cornerRadius(6)

            // Filter Row
            HStack(spacing: 12) {
                // Kind Filter
                Menu {
                    Button("All Kinds") {
                        viewModel.selectedKindFilter = nil
                    }
                    Divider()
                    ForEach([AgentMemory.MemoryKind.insight, .decision, .todo, .rule, .value, .commitment], id: \.self) { kind in
                        Button(action: {
                            viewModel.selectedKindFilter = kind
                        }) {
                            Label(viewModel.kindDisplayName(kind), systemImage: viewModel.kindIcon(kind))
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(viewModel.selectedKindFilter.map { viewModel.kindDisplayName($0) } ?? "All Kinds")
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.surfaceColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // Tag Filter
                if !viewModel.allTags.isEmpty {
                    Menu {
                        Button("All Tags") {
                            viewModel.selectedTagFilter = nil
                        }
                        Divider()
                        ForEach(viewModel.allTags, id: \.self) { tag in
                            Button(tag) {
                                viewModel.selectedTagFilter = tag
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "tag")
                            Text(viewModel.selectedTagFilter ?? "All Tags")
                            Image(systemName: "chevron.down")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.surfaceColor)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                // Sort
                Menu {
                    ForEach(MemoryManagementViewModel.SortOrder.allCases, id: \.self) { order in
                        Button(order.rawValue) {
                            viewModel.sortOrder = order
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(viewModel.sortOrder.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.surfaceColor)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 20) {
            statBadge(
                title: "Total",
                value: "\(viewModel.totalCount)",
                icon: "brain.head.profile"
            )

            if viewModel.totalCount != viewModel.filteredCount {
                statBadge(
                    title: "Filtered",
                    value: "\(viewModel.filteredCount)",
                    icon: "line.3.horizontal.decrease.circle"
                )
            }

            if viewModel.totalAccessCount > 0 {
                statBadge(
                    title: "Total Uses",
                    value: "\(viewModel.totalAccessCount)",
                    icon: "eye"
                )
            }

            Spacer()
        }
    }

    private func statBadge(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryText)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryText)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.surfaceColor)
        .cornerRadius(6)
    }

    // MARK: - Memory List

    private var memoryList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredMemories, id: \.id) { memory in
                    MemoryCardView(
                        memory: memory,
                        viewModel: viewModel,
                        onDelete: {
                            memoryToDelete = memory.id
                        }
                    )
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.totalCount == 0 ? "brain.head.profile" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(theme.secondaryText.opacity(0.5))

            Text(viewModel.totalCount == 0 ? "No memories saved yet" : "No memories match your filters")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.secondaryText)

            if viewModel.totalCount == 0 {
                Text("The AI assistant will save insights and patterns here as you use the chat feature")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Button("Clear Filters") {
                    viewModel.searchText = ""
                    viewModel.selectedKindFilter = nil
                    viewModel.selectedTagFilter = nil
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Memory Card

struct MemoryCardView: View {
    @Environment(\.theme) private var theme
    let memory: AgentMemory
    let viewModel: MemoryManagementViewModel
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Label(
                    viewModel.kindDisplayName(memory.kind),
                    systemImage: viewModel.kindIcon(memory.kind)
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.primaryText)

                Spacer()

                // Confidence Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.confidenceColor(memory.confidence))
                        .frame(width: 6, height: 6)
                    Text(memory.confidence.rawValue.capitalized)
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.surfaceColor)
                .cornerRadius(4)
            }

            // Content
            Text(memory.content)
                .font(.system(size: 13))
                .foregroundColor(theme.primaryText)
                .lineLimit(3)

            // Metadata
            HStack(spacing: 16) {
                Label(formatDate(memory.createdAt), systemImage: "calendar")
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)

                Label("\(memory.accessCount) views", systemImage: "eye")
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)

                Spacer()

                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            // Tags
            if !memory.tags.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "tag")
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryText)

                    ForEach(memory.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10))
                            .foregroundColor(theme.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(theme.surfaceColor)
                            .cornerRadius(3)
                    }
                }
            }
        }
        .padding(12)
        .background(theme.backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.dividerColor, lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
