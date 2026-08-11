import Foundation

@MainActor
final class TodoListStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    init() {
        Task { await refresh() }
    }

    func refresh() async {
        do {
            items = try await APIClient.listTasks().sorted { $0.order < $1.order }
        } catch {
            errorMessage = "Nepodarilo sa načítať úlohy zo servera."
        }
        isLoading = false
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                let created = try await APIClient.createTask(title: trimmed)
                items.append(created)
            } catch {
                errorMessage = "Nepodarilo sa pridať úlohu."
            }
        }
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let newValue = !items[index].isDone
        items[index].isDone = newValue
        Task {
            do {
                _ = try await APIClient.updateTask(id: item.id, completed: newValue)
            } catch {
                items[index].isDone.toggle()
                errorMessage = "Nepodarilo sa uložiť zmenu."
            }
        }
    }

    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { items[$0] }
        items.remove(atOffsets: offsets)
        Task {
            for item in toDelete {
                do {
                    try await APIClient.deleteTask(id: item.id)
                } catch {
                    errorMessage = "Nepodarilo sa zmazať úlohu."
                }
            }
        }
    }

    func deleteCheckedItems() {
        let toDelete = items.filter { $0.isDone }
        items.removeAll { $0.isDone }
        Task {
            for item in toDelete {
                do {
                    try await APIClient.deleteTask(id: item.id)
                } catch {
                    errorMessage = "Nepodarilo sa zmazať úlohy."
                }
            }
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        let ids = items.map { $0.id }
        Task {
            do {
                try await APIClient.reorderTasks(ids: ids)
            } catch {
                errorMessage = "Nepodarilo sa uložiť poradie."
            }
        }
    }
}
