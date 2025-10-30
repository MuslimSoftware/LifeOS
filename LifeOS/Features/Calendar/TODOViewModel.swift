import Foundation

extension Notification.Name {
    static let todosDidChange = Notification.Name("todosDidChange")
}

@Observable
class TODOViewModel {
    var todos: [TODOItem] = []
    private let fileService: FileManagerService
    private var currentEntry: HumanEntry?
    private var selectedDate: Date?

    init(fileService: FileManagerService) {
        self.fileService = fileService
    }

    func loadTODOs(for entry: HumanEntry?, date: Date? = nil) {
        selectedDate = date

        if let entry = entry {
            currentEntry = entry
            todos = fileService.loadTODOs(for: entry)
        } else if let date = date {
            todos = fileService.loadTODOsForDate(date: date)
            currentEntry = nil
        } else {
            currentEntry = nil
            todos = []
        }
    }

    func addTODO(text: String) {
        guard !text.isEmpty else { return }

        if currentEntry == nil, let date = selectedDate {
            currentEntry = HumanEntry.createWithDate(date: date)
            fileService.saveEntry(currentEntry!, content: "")
        }

        guard let entry = currentEntry else { return }

        let newTODO = TODOItem(text: text, completed: false)
        todos.append(newTODO)
        saveTODOs()
    }

    func toggleTODO(_ todo: TODOItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index] = TODOItem(
            id: todos[index].id,
            text: todos[index].text,
            completed: !todos[index].completed,
            createdAt: todos[index].createdAt,
            dueTime: todos[index].dueTime
        )
        saveTODOs()
    }

    func deleteTODO(_ todo: TODOItem) {
        todos.removeAll { $0.id == todo.id }
        saveTODOs()
    }

    func updateTODO(_ todo: TODOItem, newText: String) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index] = TODOItem(
            id: todos[index].id,
            text: newText,
            completed: todos[index].completed,
            createdAt: todos[index].createdAt,
            dueTime: todos[index].dueTime
        )
        saveTODOs()
    }

    func updateTODOTime(_ todo: TODOItem, newTime: Date?, saveImmediately: Bool = true) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index] = TODOItem(
            id: todos[index].id,
            text: todos[index].text,
            completed: todos[index].completed,
            createdAt: todos[index].createdAt,
            dueTime: newTime
        )
        if saveImmediately {
            saveTODOs()
        }
    }

    func saveTODOs() {
        guard let entry = currentEntry else { return }
        fileService.saveTODOs(todos, for: entry)

        // Notify that TODOs changed
        NotificationCenter.default.post(
            name: .todosDidChange,
            object: nil,
            userInfo: ["entryId": entry.id, "date": selectedDate as Any]
        )
    }
}
