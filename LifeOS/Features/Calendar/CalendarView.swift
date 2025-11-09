import SwiftUI

struct CalendarView: View {
    @Environment(\.theme) private var theme
    @Environment(EntryListViewModel.self) private var entryListViewModel
    @Environment(EditorViewModel.self) private var editorViewModel
    @Environment(SidebarHoverManager.self) private var hoverManager

    @Binding var selectedRoute: NavigationRoute

    @State private var currentMonth = Date()
    @State private var hoveredControl: String? = nil
    @State private var scrollAccumulator: CGFloat = 0
    @State private var selectedDay: Date? = Date()
    @State private var todoViewModel: TODOViewModel?
    @State private var todoCounts: [String: (incomplete: Int, completed: Int)] = [:]
    @State private var stickyNoteText: String = ""

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text(monthString)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(theme.primaryText)
                            .padding(.top, 40)
                            .padding(.bottom, 40)

                        VStack(spacing: 12) {
                            HStack(spacing: 0) {
                                ForEach(daysOfWeek, id: \.self) { day in
                                    Text(day)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(theme.secondaryText)
                                        .frame(maxWidth: .infinity)
                                }
                            }

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, day in
                                    if let day = day {
                                        let todoCounts = todosForDay(day)
                                        DayCell(
                                            day: day,
                                            hasEntry: hasEntry(for: day),
                                            isToday: isToday(day),
                                            isSelected: isSelected(day),
                                            theme: theme,
                                            incompleteTodoCount: todoCounts.incomplete,
                                            completedTodoCount: todoCounts.completed
                                        )
                                        .frame(height: 80)
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedDay = day
                                        }
                                    } else {
                                        Color.clear
                                            .frame(height: 80)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                        .frame(height: 520)
                    }

                    VStack(spacing: 0) {
                        if let selectedDay = selectedDay, let todoVM = todoViewModel {
                            HStack(alignment: .top, spacing: 0) {
                                Spacer()

                                VStack(alignment: .leading, spacing: 0) {
                                    TextEditor(text: $stickyNoteText)
                                        .font(.system(size: 14))
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                        .padding(16)
                                        .frame(maxHeight: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(theme.backgroundColor)
                                        )
                                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 0)
                                        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 12)
                                }
                                .frame(maxWidth: .infinity)

                                Rectangle()
                                    .fill(theme.dividerColor.opacity(0.3))
                                    .frame(width: 1)

                                TODOListView()
                                    .environment(todoVM)
                                    .frame(maxWidth: .infinity)

                                Spacer()
                            }
                            .frame(width: geometry.size.width * 0.80)
                            .frame(maxWidth: .infinity)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 240)
                    .background(theme.surfaceColor.opacity(0.3))

                    Spacer()
                        .frame(height: 60)
                }
                .frame(width: geometry.size.width * 0.90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        HStack(spacing: 20) {
                            ScrollableValueControl.month(
                                date: currentMonth,
                                hoveredControl: $hoveredControl,
                                scrollAccumulator: $scrollAccumulator,
                                onAdjust: adjustMonth
                            )

                            Text("•")
                                .foregroundColor(theme.separatorColor)

                            ScrollableValueControl.year(
                                date: currentMonth,
                                hoveredControl: $hoveredControl,
                                scrollAccumulator: $scrollAccumulator,
                                onAdjust: adjustYear
                            )

                            Text("•")
                                .foregroundColor(theme.separatorColor)

                            Button(action: goToToday) {
                                Text("Today")
                                    .font(.system(size: 13))
                                    .foregroundColor(hoveredControl == "today" ? theme.buttonTextHover : theme.buttonText)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                hoveredControl = hovering ? "today" : nil
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                        .padding(8)
                    }
                    .padding()
                    .frame(height: 60)
                    .background(theme.backgroundColor)
                }
            }
            .overlay(
                EdgeHintView(
                    isLeftEdge: true,
                    isVisible: !hoverManager.isLeftSidebarOpen
                        && !hoverManager.isLeftSidebarPinned
                )
            )
            .onAppear {
                if todoViewModel == nil {
                    todoViewModel = TODOViewModel(fileService: entryListViewModel.fileService)
                    updateTODOsForSelectedDay()
                }
                refreshTODOCounts()
                loadStickyNoteForSelectedDay()

                NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    if hoveredControl == "month" || hoveredControl == "year" {
                        scrollAccumulator += event.deltaY

                        if scrollAccumulator > 3 {
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                            if hoveredControl == "month" {
                                adjustMonth(by: 1)
                            } else if hoveredControl == "year" {
                                adjustYear(by: 1)
                            }
                            scrollAccumulator = 0
                        } else if scrollAccumulator < -3 {
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                            if hoveredControl == "month" {
                                adjustMonth(by: -1)
                            } else if hoveredControl == "year" {
                                adjustYear(by: -1)
                            }
                            scrollAccumulator = 0
                        }
                    }
                    return event
                }
            }
            .onChange(of: selectedDay) {
                updateTODOsForSelectedDay()
                loadStickyNoteForSelectedDay()
            }
            .onChange(of: stickyNoteText) { oldValue, newValue in
                saveStickyNoteForSelectedDay()
            }
            .onChange(of: todoViewModel?.todos.count) { oldValue, newValue in
                if let selectedDay = selectedDay {
                    updateTODOCountsForDate(selectedDay)
                }
            }
            .onChange(of: todoViewModel?.todos.map { $0.completed }) { oldValue, newValue in
                if let selectedDay = selectedDay {
                    updateTODOCountsForDate(selectedDay)
                }
            }
            .onChange(of: currentMonth) {
                refreshTODOCounts()
            }
            .onReceive(NotificationCenter.default.publisher(for: .todosDidChange)) { _ in
                refreshTODOCounts()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.backgroundColor)
    }
    
    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: currentMonth)
    }
    
    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday else {
            return []
        }
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        let leadingEmptyDays = firstWeekday - 1
        
        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)
        
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func hasEntry(for date: Date) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: date)
        
        let dateYear = calendar.component(.year, from: date)
        
        return entryListViewModel.entries.contains { entry in
            entry.date == dateString && entry.year == dateYear && !entry.previewText.isEmpty
        }
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    private func isSelected(_ date: Date) -> Bool {
        guard let selectedDay = selectedDay else { return false }
        return calendar.isDate(date, inSameDayAs: selectedDay)
    }
    
    private func adjustMonth(by direction: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: direction, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private func adjustYear(by direction: Int) {
        var components = calendar.dateComponents([.year, .month, .day], from: currentMonth)
        components.year = (components.year ?? 0) + direction
        if let newDate = calendar.date(from: components) {
            currentMonth = newDate
        }
    }
    
    private func goToToday() {
        let today = Date()
        currentMonth = today
        selectedDay = today
    }
    
    private func entriesForSelectedDay(_ date: Date) -> [HumanEntry] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: date)
        let dateYear = calendar.component(.year, from: date)
        
        return entryListViewModel.entries.filter { entry in
            entry.date == dateString && entry.year == dateYear
        }
    }
    
    private func openEntry(_ entry: HumanEntry) {
        entryListViewModel.expandSectionsForEntry(entry)
        entryListViewModel.selectedEntryId = entry.id
        if let content = entryListViewModel.loadEntry(entry: entry) {
            editorViewModel.isLoadingContent = true
            editorViewModel.text = content
            editorViewModel.isLoadingContent = false
        }
        selectedRoute = .journal
    }

    private func createJournalForSelectedDay() {
        guard let selectedDay = selectedDay else { return }

        if let existingFilename = entryListViewModel.fileService.findExistingFileForDate(date: selectedDay) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            let displayDate = dateFormatter.string(from: selectedDay)
            let year = calendar.component(.year, from: selectedDay)

            if let uuidMatch = existingFilename.range(of: "\\[(.*?)\\]", options: .regularExpression),
               let uuid = UUID(uuidString: String(existingFilename[uuidMatch].dropFirst().dropLast())) {

                let entry = HumanEntry(
                    id: uuid,
                    date: displayDate,
                    filename: existingFilename,
                    previewText: "",
                    year: year
                )

                entryListViewModel.addEntryAndRefresh(entry)
                entryListViewModel.expandSectionsForEntry(entry)
                entryListViewModel.selectedEntryId = entry.id

                editorViewModel.isLoadingContent = true
                if let content = entryListViewModel.loadEntry(entry: entry) {
                    editorViewModel.text = content
                } else {
                    editorViewModel.text = ""
                }
                editorViewModel.isLoadingContent = false

                selectedRoute = .journal
            }
        } else {
            let newEntry = HumanEntry.createWithDate(date: selectedDay)

            entryListViewModel.addEntryAndRefresh(newEntry)
            entryListViewModel.fileService.saveEntry(newEntry, content: "")
            entryListViewModel.expandSectionsForEntry(newEntry)
            entryListViewModel.selectedEntryId = newEntry.id

            editorViewModel.isLoadingContent = true
            editorViewModel.text = ""
            editorViewModel.isLoadingContent = false
            selectedRoute = .journal
        }
    }

    private func updateTODOsForSelectedDay() {
        guard let selectedDay = selectedDay else {
            todoViewModel?.loadTODOs(for: nil, date: nil)
            return
        }

        let entries = entriesForSelectedDay(selectedDay)
        let entry = entries.first
        todoViewModel?.loadTODOs(for: entry, date: selectedDay)

        // Update calendar counts for this day after loading
        updateTODOCountsForDate(selectedDay)
    }

    private func loadStickyNoteForSelectedDay() {
        guard let selectedDay = selectedDay else {
            stickyNoteText = ""
            return
        }

        stickyNoteText = entryListViewModel.fileService.loadStickyNoteForDate(date: selectedDay)
    }

    private func saveStickyNoteForSelectedDay() {
        guard let selectedDay = selectedDay else { return }

        let entries = entriesForSelectedDay(selectedDay)
        var entry = entries.first

        // If no entry exists for this day, create one
        if entry == nil {
            if let existingFilename = entryListViewModel.fileService.findExistingFileForDate(date: selectedDay) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d"
                let displayDate = dateFormatter.string(from: selectedDay)
                let year = calendar.component(.year, from: selectedDay)

                if let uuidMatch = existingFilename.range(of: "\\[(.*?)\\]", options: .regularExpression),
                   let uuid = UUID(uuidString: String(existingFilename[uuidMatch].dropFirst().dropLast())) {
                    entry = HumanEntry(
                        id: uuid,
                        date: displayDate,
                        filename: existingFilename,
                        previewText: "",
                        year: year
                    )
                }
            } else {
                let newEntry = HumanEntry.createWithDate(date: selectedDay)
                entryListViewModel.fileService.saveEntry(newEntry, content: "")
                entry = newEntry
            }
        }

        if let entry = entry {
            entryListViewModel.fileService.saveStickyNote(stickyNoteText, for: entry)
        }
    }

    private func updateTODOCountsForDate(_ date: Date) {
        guard let todos = todoViewModel?.todos else { return }

        let incomplete = todos.filter { !$0.completed }.count
        let completed = todos.filter { $0.completed }.count

        let key = dateKey(for: date)
        if incomplete > 0 || completed > 0 {
            todoCounts[key] = (incomplete, completed)
        } else {
            todoCounts.removeValue(forKey: key)
        }
    }

    private func refreshTODOCounts() {
        var newCounts: [String: (incomplete: Int, completed: Int)] = [:]

        for day in daysInMonth {
            guard let day = day else { continue }

            let todos = entryListViewModel.fileService.loadTODOsForDate(date: day)
            let incomplete = todos.filter { !$0.completed }.count
            let completed = todos.filter { $0.completed }.count

            if incomplete > 0 || completed > 0 {
                let dateKey = dateKey(for: day)
                newCounts[dateKey] = (incomplete, completed)
            }
        }

        todoCounts = newCounts
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func todosForDay(_ date: Date) -> (incomplete: Int, completed: Int) {
        let key = dateKey(for: date)
        return todoCounts[key] ?? (0, 0)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
    }
}

struct DayCell: View {
    let day: Date
    let hasEntry: Bool
    let isToday: Bool
    let isSelected: Bool
    let theme: Theme
    let incompleteTodoCount: Int
    let completedTodoCount: Int

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
            
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.dividerColor.opacity(0.3), lineWidth: isToday ? 2 : 0)
            
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 16))
                    .foregroundColor(textColor)

                if hasEntry {
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 6, height: 6)
                } else {
                    Spacer()
                        .frame(height: 6)
                }

                if incompleteTodoCount > 0 || completedTodoCount > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(incompleteTodoCount, 3), id: \.self) { _ in
                            Circle()
                                .stroke(theme.tertiaryText.opacity(0.6), lineWidth: 1)
                                .frame(width: 5, height: 5)
                        }
                        ForEach(0..<min(completedTodoCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(theme.tertiaryText.opacity(0.6))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(height: 6)
                } else {
                    Spacer()
                        .frame(height: 6)
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return theme.dividerColor.opacity(0.3)
        }
        return Color.clear
    }
    
    private var textColor: Color {
        if isSelected {
            return theme.primaryText
        }
        if hasEntry {
            return theme.primaryText
        }
        return theme.secondaryText
    }
}

struct JournalEntryCard: View {
    let entry: HumanEntry
    let theme: Theme
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !entry.previewText.isEmpty {
                Text(entry.previewText)
                    .font(.system(size: 14))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Empty entry")
                    .font(.system(size: 14))
                    .foregroundColor(theme.tertiaryText)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.01))
                .shadow(color: theme.dividerColor.opacity(isHovering ? 0.4 : 0.2), radius: isHovering ? 8 : 4, x: 0, y: 2)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

