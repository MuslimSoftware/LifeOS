import Foundation
import GRDB

extension Notification.Name {
    static let todosDidChange = Notification.Name("todosDidChange")
}

@Observable
class TODOViewModel {
    var todos: [TODOItem] = []
    private let todoRepo: TODORepository
    private var selectedDate: Date?

    init(todoRepo: TODORepository, entryRepo: EntryRepository) {
        self.todoRepo = todoRepo
    }

    func loadTODOs(forDate date: Date?) {
        selectedDate = date

        guard let date = date else {
            todos = []
            return
        }

        do {
            todos = try todoRepo.getTODOs(forDate: date)
        } catch {
            print("Error loading TODOs: \(error)")
            todos = []
        }
    }

    func addTODO(text: String) {
        guard !text.isEmpty else { return }
        guard let date = selectedDate else { return }

        do {
            let newTODO = TODOItem(
                id: UUID(),
                date: date,
                text: text,
                completed: false,
                createdAt: Date(),
                dueTime: nil
            )
            try todoRepo.save(newTODO)
            todos.append(newTODO)

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .todosDidChange,
                    object: nil,
                    userInfo: ["date": self.selectedDate as Any]
                )
            }
        } catch {
            print("Error adding TODO: \(error)")
        }
    }

    func toggleTODO(_ todo: TODOItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        var updatedTODO = TODOItem(
            id: todos[index].id,
            date: todos[index].date,
            text: todos[index].text,
            completed: !todos[index].completed,
            createdAt: todos[index].createdAt,
            dueTime: todos[index].dueTime
        )

        do {
            try todoRepo.save(updatedTODO)
            todos[index] = updatedTODO

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .todosDidChange,
                    object: nil,
                    userInfo: ["date": self.selectedDate as Any]
                )
            }
        } catch {
            print("Error toggling TODO: \(error)")
        }
    }

    func deleteTODO(_ todo: TODOItem) {
        do {
            try todoRepo.delete(id: todo.id)
            todos.removeAll { $0.id == todo.id }

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .todosDidChange,
                    object: nil,
                    userInfo: ["date": self.selectedDate as Any]
                )
            }
        } catch {
            print("Error deleting TODO: \(error)")
        }
    }

    func updateTODO(_ todo: TODOItem, newText: String) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        var updatedTODO = TODOItem(
            id: todos[index].id,
            date: todos[index].date,
            text: newText,
            completed: todos[index].completed,
            createdAt: todos[index].createdAt,
            dueTime: todos[index].dueTime
        )

        do {
            try todoRepo.save(updatedTODO)
            todos[index] = updatedTODO

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .todosDidChange,
                    object: nil,
                    userInfo: ["date": self.selectedDate as Any]
                )
            }
        } catch {
            print("Error updating TODO: \(error)")
        }
    }

    func updateTODOTime(_ todo: TODOItem, newTime: Date?, saveImmediately: Bool = true) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        var updatedTODO = TODOItem(
            id: todos[index].id,
            date: todos[index].date,
            text: todos[index].text,
            completed: todos[index].completed,
            createdAt: todos[index].createdAt,
            dueTime: newTime
        )

        todos[index] = updatedTODO

        if saveImmediately {
            do {
                try todoRepo.save(updatedTODO)

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .todosDidChange,
                        object: nil,
                        userInfo: ["date": self.selectedDate as Any]
                    )
                }
            } catch {
                print("Error updating TODO time: \(error)")
            }
        }
    }

    func saveTODOs() {
        do {
            for todo in todos {
                try todoRepo.save(todo)
            }

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .todosDidChange,
                    object: nil,
                    userInfo: ["date": self.selectedDate as Any]
                )
            }
        } catch {
            print("Error saving TODOs: \(error)")
        }
    }
}
