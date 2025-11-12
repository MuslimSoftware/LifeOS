import SwiftUI

enum TimeComponent: Equatable {
    case hour
    case minute
    case period
}

struct TODOListView: View {
    @Environment(\.theme) private var theme
    @Environment(TODOViewModel.self) private var todoViewModel

    @State private var newTODOText: String = ""
    @State private var isAddingTODO: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var hoveredTODOTimePickerId: UUID? = nil
    @State private var activeTimeComponent: TimeComponent? = nil
    @State private var scrollAccumulator: CGFloat = 0
    @State private var pendingTimeUpdate: (todoId: UUID, time: Date)? = nil
    @State private var saveTimer: Timer? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.secondaryText)
                Text("To-Do List")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(todoViewModel.todos) { todo in
                        VStack(spacing: 0) {
                            TODORowView(
                                todo: todo,
                                hoveredTODOTimePickerId: $hoveredTODOTimePickerId,
                                activeTimeComponent: $activeTimeComponent
                            )
                            
                            if todo.id != todoViewModel.todos.last?.id {
                                Divider()
                                    .background(theme.dividerColor.opacity(0.3))
                                    .padding(.leading, 32)
                            }
                        }
                    }

                    if isAddingTODO {
                        VStack(spacing: 0) {
                            if !todoViewModel.todos.isEmpty {
                                Divider()
                                    .background(theme.dividerColor.opacity(0.3))
                                    .padding(.leading, 32)
                            }
                            
                            HStack(spacing: 10) {
                                Button(action: {}) {
                                    Image(systemName: "circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(theme.tertiaryText)
                                }
                                .buttonStyle(.plain)
                                .disabled(true)

                                TextField("Add a task", text: $newTODOText)
                                    .font(.system(size: 14))
                                    .textFieldStyle(.plain)
                                    .focused($isTextFieldFocused)
                                    .onSubmit {
                                        submitNewTODO()
                                    }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 0)
                        }
                    }

                    if !isAddingTODO {
                        VStack(spacing: 0) {
                            if !todoViewModel.todos.isEmpty {
                                Divider()
                                    .background(theme.dividerColor.opacity(0.3))
                                    .padding(.leading, 32)
                            }
                            
                            Button(action: {
                                isAddingTODO = true
                                isTextFieldFocused = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(theme.accentColor)
                                    Text("Add task")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(theme.accentColor)
                                }
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .hideScrollIndicators()
            .frame(height: 140)
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                guard let hoveredId = hoveredTODOTimePickerId,
                      let component = activeTimeComponent,
                      let hoveredTODO = todoViewModel.todos.first(where: { $0.id == hoveredId }),
                      hoveredTODO.dueTime != nil else {
                    return event
                }

                scrollAccumulator += event.deltaY
                let threshold: CGFloat = 3

                while scrollAccumulator >= threshold {
                    adjustTime(by: 1, component: component, for: hoveredTODO)
                    scrollAccumulator -= threshold
                }

                while scrollAccumulator <= -threshold {
                    adjustTime(by: -1, component: component, for: hoveredTODO)
                    scrollAccumulator += threshold
                }

                return nil
            }
        }
    }

    private func adjustTime(by delta: Int, component: TimeComponent, for todo: TODOItem) {
        guard todo.dueTime != nil else { return }
        let calendar = Calendar.current
        let defaultDueTime: Date = {
            var components = DateComponents()
            components.hour = 12
            components.minute = 0
            return calendar.date(from: components) ?? Date()
        }()

        let referenceTime = pendingTimeUpdate?.todoId == todo.id ? pendingTimeUpdate!.time : (todo.dueTime ?? defaultDueTime)
        var hour = calendar.component(.hour, from: referenceTime)
        var minute = calendar.component(.minute, from: referenceTime)

        switch component {
        case .hour:
            let isPM = hour >= 12
            var displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)

            displayHour += delta
            if displayHour > 12 { displayHour = 1 }
            if displayHour < 1 { displayHour = 12 }

            hour = isPM ? (displayHour == 12 ? 12 : displayHour + 12) : (displayHour == 12 ? 0 : displayHour)

        case .minute:
            minute += delta
            if minute >= 60 { minute = 0 }
            if minute < 0 { minute = 59 }

        case .period:
            if delta != 0 {
                hour = (hour + 12) % 24
            }
        }

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        if let newTime = calendar.date(from: components) {
            pendingTimeUpdate = (todoId: todo.id, time: newTime)
            todoViewModel.updateTODOTime(todo, newTime: newTime, saveImmediately: false)

            saveTimer?.invalidate()
            saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [self] _ in
                todoViewModel.saveTODOs()
                pendingTimeUpdate = nil
            }
        }
    }

    private func submitNewTODO() {
        if !newTODOText.isEmpty {
            todoViewModel.addTODO(text: newTODOText)
            newTODOText = ""
        }
        isAddingTODO = false
        isTextFieldFocused = false
    }
}

struct TODORowView: View {
    @Environment(\.theme) private var theme
    @Environment(TODOViewModel.self) private var todoViewModel

    let todo: TODOItem
    @Binding var hoveredTODOTimePickerId: UUID?
    @Binding var activeTimeComponent: TimeComponent?
    @State private var isHovering: Bool = false
    @State private var isEditing: Bool = false
    @State private var editText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button(action: {
                todoViewModel.toggleTODO(todo)
            }) {
                Image(systemName: todo.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(todo.completed ? theme.secondaryText : theme.tertiaryText)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            TimePickerView(
                todo: todo,
                hoveredTODOTimePickerId: $hoveredTODOTimePickerId,
                activeTimeComponent: $activeTimeComponent
            )

            if isEditing {
                TextField("", text: $editText)
                    .font(.system(size: 14))
                    .foregroundColor(theme.primaryText)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        saveEdit()
                    }
                    .onExitCommand {
                        cancelEdit()
                    }
            } else {
                Text(todo.text)
                    .font(.system(size: 14))
                    .foregroundColor(todo.completed ? theme.tertiaryText : theme.primaryText)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !todo.completed {
                            startEditing()
                        }
                    }
            }

            Spacer()

            if isHovering {
                Button(action: {
                    todoViewModel.deleteTODO(todo)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.tertiaryText)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 0)
        .background(isHovering ? theme.dividerColor.opacity(0.05) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .onChange(of: isTextFieldFocused) {
            if !isTextFieldFocused && isEditing {
                saveEdit()
            }
        }
    }

    private func startEditing() {
        editText = todo.text
        isEditing = true
        isTextFieldFocused = true
    }

    private func saveEdit() {
        guard !editText.isEmpty else {
            cancelEdit()
            return
        }
        todoViewModel.updateTODO(todo, newText: editText)
        isEditing = false
        isTextFieldFocused = false
    }

    private func cancelEdit() {
        isEditing = false
        isTextFieldFocused = false
        editText = ""
    }
}

struct TimePickerView: View {
    @Environment(\.theme) private var theme
    @Environment(TODOViewModel.self) private var todoViewModel

    let todo: TODOItem
    @Binding var hoveredTODOTimePickerId: UUID?
    @Binding var activeTimeComponent: TimeComponent?
    @State private var isHoveringTime: Bool = false

    private var defaultDueTime: Date {
        var components = DateComponents()
        components.hour = 12
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        Group {
            if let dueTime = todo.dueTime {
                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        let components = timeComponents(from: dueTime)

                        timeSegment(text: components.hourString, component: .hour, minWidth: 18)

                        Text(":")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.secondaryText)

                        timeSegment(text: components.minuteString, component: .minute, minWidth: 22)

                        timeSegment(text: components.period, component: .period, minWidth: 22)
                    }

                    if isHoveringTime {
                        Button(action: clearDueTime) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(theme.tertiaryText)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(theme.dividerColor.opacity(0.2))
                )
                .overlay(
                    Capsule()
                        .stroke(theme.dividerColor.opacity(0.3), lineWidth: 0.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .onHover { hovering in
                    if !todo.completed {
                        isHoveringTime = hovering
                        if hovering {
                            hoveredTODOTimePickerId = todo.id
                            if activeTimeComponent == nil {
                                activeTimeComponent = .minute
                            }
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                            hoveredTODOTimePickerId = nil
                            activeTimeComponent = nil
                        }
                    }
                }
            } else {
                Button(action: handleIconTap) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(theme.dividerColor.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
                .disabled(todo.completed)
                .onHover { hovering in
                    if hovering && !todo.completed {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
    }

    private func handleIconTap() {
        todoViewModel.updateTODOTime(todo, newTime: defaultDueTime)
        hoveredTODOTimePickerId = todo.id
        activeTimeComponent = .minute
    }

    private func clearDueTime() {
        todoViewModel.updateTODOTime(todo, newTime: nil)
        isHoveringTime = false
        hoveredTODOTimePickerId = nil
        activeTimeComponent = nil
    }

    private func timeComponents(from date: Date) -> (hourString: String, minuteString: String, period: String) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)

        return (
            hourString: "\(displayHour)",
            minuteString: String(format: "%02d", minute),
            period: period
        )
    }

    @ViewBuilder
    private func timeSegment(text: String, component: TimeComponent, minWidth: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(activeTimeComponent == component ? theme.primaryText : theme.secondaryText)
            .frame(minWidth: minWidth)
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
            .background(activeTimeComponent == component ? theme.dividerColor.opacity(0.3) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering && !todo.completed {
                    hoveredTODOTimePickerId = todo.id
                    activeTimeComponent = component
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onTapGesture {
                if !todo.completed {
                    hoveredTODOTimePickerId = todo.id
                    activeTimeComponent = component
                }
            }
    }
}
