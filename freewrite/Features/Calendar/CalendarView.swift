import SwiftUI

struct CalendarView: View {
    @Environment(\.theme) private var theme
    @Environment(EntryListViewModel.self) private var entryListViewModel
    @Environment(EditorViewModel.self) private var editorViewModel

    @Binding var selectedRoute: NavigationRoute

    @State private var currentMonth = Date()
    @State private var hoveredControl: String? = nil
    @State private var scrollAccumulator: CGFloat = 0
    @State private var selectedDay: Date? = Date()
    @State private var todoViewModel: TODOViewModel?
    @State private var todoCounts: [String: (incomplete: Int, completed: Int)] = [:]

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 0) {
            Text(monthString)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(theme.primaryText)
                .padding(.top, 40)
                .padding(.bottom, 32)
            
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
            
            if let selectedDay = selectedDay, !entriesForSelectedDay(selectedDay).isEmpty, let todoVM = todoViewModel {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Journal")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, 40)
                            .padding(.top, 24)
                            .padding(.bottom, 16)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(entriesForSelectedDay(selectedDay)) { entry in
                                    VStack(alignment: .leading, spacing: 6) {
                                        if !entry.previewText.isEmpty {
                                            Text(entry.previewText)
                                                .font(.system(size: 14))
                                                .foregroundColor(theme.primaryText)
                                                .lineLimit(1)
                                        } else {
                                            Text("Empty entry")
                                                .font(.system(size: 14))
                                                .foregroundColor(theme.tertiaryText)
                                                .italic()
                                        }
                                    }
                                    .padding(16)
                                    .background(theme.dividerColor.opacity(0.15))
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        openEntry(entry)
                                    }
                                    .onHover { hovering in
                                        if hovering {
                                            NSCursor.pointingHand.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.bottom, 20)
                        }
                        .frame(height: 180)
                    }
                    .frame(maxWidth: .infinity)

                    TODOListView()
                        .environment(todoVM)
                        .frame(maxWidth: .infinity)
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                
                HStack(spacing: 20) {
                    Text(monthString)
                    .font(.system(size: 13))
                    .foregroundColor(hoveredControl == "month" ? theme.buttonTextHover : theme.buttonText)
                    .onHover { hovering in
                        hoveredControl = hovering ? "month" : nil
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                
                Text("•")
                    .foregroundColor(theme.separatorColor)
                
                Text(verbatim: yearString)
                    .font(.system(size: 13))
                    .foregroundColor(hoveredControl == "year" ? theme.buttonTextHover : theme.buttonText)
                    .onHover { hovering in
                        hoveredControl = hovering ? "year" : nil
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                
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
            .onAppear {
                if todoViewModel == nil {
                    todoViewModel = TODOViewModel(fileService: entryListViewModel.fileService)
                    updateTODOsForSelectedDay()
                }
                refreshTODOCounts()

                NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    if hoveredControl == "month" || hoveredControl == "year" {
                        scrollAccumulator += event.deltaY

                        if scrollAccumulator > 3 {
                            if hoveredControl == "month" {
                                adjustMonth(by: 1)
                            } else if hoveredControl == "year" {
                                adjustYear(by: 1)
                            }
                            scrollAccumulator = 0
                        } else if scrollAccumulator < -3 {
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
            }
            .onChange(of: todoViewModel?.todos) {
                refreshTODOCounts()
            }
            .onChange(of: currentMonth) {
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
        currentMonth = Date()
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
            editorViewModel.text = content
        }
        selectedRoute = .journal
    }

    private func updateTODOsForSelectedDay() {
        guard let selectedDay = selectedDay else {
            todoViewModel?.loadTODOs(for: nil)
            return
        }

        let entries = entriesForSelectedDay(selectedDay)
        let entry = entries.first
        todoViewModel?.loadTODOs(for: entry)
    }

    private func refreshTODOCounts() {
        var newCounts: [String: (incomplete: Int, completed: Int)] = [:]

        for day in daysInMonth {
            guard let day = day else { continue }
            let entries = entriesForSelectedDay(day)
            guard let firstEntry = entries.first else { continue }

            let todos = entryListViewModel.fileService.loadTODOs(for: firstEntry)
            let incomplete = todos.filter { !$0.completed }.count
            let completed = todos.filter { $0.completed }.count

            let dateKey = dateKey(for: day)
            newCounts[dateKey] = (incomplete, completed)
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

