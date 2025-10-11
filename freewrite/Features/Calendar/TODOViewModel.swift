import Foundation

@Observable
class TODOViewModel {
    var todos: [TODOItem] = []
    private let fileService: FileManagerService
    private var currentEntry: HumanEntry?

    init(fileService: FileManagerService) {
        self.fileService = fileService
    }

    func loadTODOs(for entry: HumanEntry?) {
        guard let entry = entry else {
            todos = []
            currentEntry = nil
            return
        }

        currentEntry = entry
        todos = fileService.loadTODOs(for: entry)
    }

    func addTODO(text: String) {
        guard let entry = currentEntry, !text.isEmpty else { return }

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
    }
}
