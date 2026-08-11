import Foundation

@MainActor
final class TodoListStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isOffline = false
    @Published var errorMessage: String?

    private let network = NetworkMonitor()
    private var pendingOperations: [PendingOperation] = []
    private var nextLocalId = -1
    private var serverReachable = true
    private var retryTimer: Timer?

    init() {
        items = LocalStore.loadItems()
        pendingOperations = LocalStore.loadQueue()
        nextLocalId = (pendingOperations.compactMap { op -> Int? in
            if case .create(let localId, _, _) = op { return localId }
            return nil
        }.min() ?? 0) - 1
        isLoading = items.isEmpty
        isOffline = !network.isConnected

        network.onChange = { [weak self] connected in
            guard let self else { return }
            self.updateOfflineState()
            if connected {
                Task { await self.sync() }
            }
        }

        // NWPathMonitor only reports whether the device has a network path
        // (Wi-Fi/cellular up), not whether our specific server is reachable
        // — e.g. its Docker container can stop while Wi-Fi stays connected.
        // A periodic retry catches that case and flushes/syncs once it
        // comes back, without waiting for the user to relaunch or pull-to-refresh.
        retryTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.sync() }
        }

        Task { await sync() }
    }

    deinit {
        retryTimer?.invalidate()
    }

    private func updateOfflineState() {
        isOffline = !network.isConnected || !serverReachable
    }

    /// Replays any queued offline edits against the server, then refreshes
    /// from the server's current state. Safe to call whenever connectivity
    /// is (re)gained, on launch, and periodically as a backstop.
    ///
    /// What's in the app always wins over what's on the server: the server
    /// snapshot is only pulled in once every locally queued edit has been
    /// pushed. If any edit is still stuck in the queue (partial failure
    /// mid-flush), a stale server list is never allowed to overwrite it.
    func sync() async {
        guard network.isConnected else {
            isLoading = false
            return
        }
        await flushPendingOperations()
        guard pendingOperations.isEmpty else {
            serverReachable = false
            updateOfflineState()
            isLoading = false
            return
        }
        do {
            items = try await APIClient.listTasks().sorted { $0.order < $1.order }
            LocalStore.saveItems(items)
            errorMessage = nil
            serverReachable = true
        } catch {
            // Server unreachable (e.g. its container is down): keep whatever
            // we have locally and retry on the next timer tick / reconnect.
            serverReachable = false
        }
        updateOfflineState()
        isLoading = false
    }

    private func flushPendingOperations() async {
        var idMap: [Int: Int] = [:]
        var index = 0
        while index < pendingOperations.count {
            let operation = pendingOperations[index].remapped(using: idMap)
            do {
                switch operation {
                case .create(let localId, let title, let description):
                    let created = try await APIClient.createTask(title: title, description: description)
                    idMap[localId] = created.id
                    if let itemIndex = items.firstIndex(where: { $0.id == localId }) {
                        items[itemIndex] = created
                    }
                case .update(let id, let completed):
                    _ = try await APIClient.updateTask(id: id, completed: completed)
                case .delete(let id):
                    try await APIClient.deleteTask(id: id)
                case .reorder(let ids):
                    try await APIClient.reorderTasks(ids: ids)
                }
                index += 1
            } catch {
                break
            }
        }
        pendingOperations = pendingOperations[index...].map { $0.remapped(using: idMap) }
        LocalStore.saveQueue(pendingOperations)
        LocalStore.saveItems(items)
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard network.isConnected else {
            addOffline(title: trimmed)
            return
        }
        Task {
            do {
                let created = try await APIClient.createTask(title: trimmed)
                items.append(created)
                LocalStore.saveItems(items)
            } catch {
                addOffline(title: trimmed)
            }
        }
    }

    private func addOffline(title: String) {
        let localId = nextLocalId
        nextLocalId -= 1
        let order = (items.map(\.order).max() ?? 0) + 1
        items.append(TodoItem(id: localId, title: title, description: nil, isDone: false, order: order))
        pendingOperations.append(.create(localId: localId, title: title, description: nil))
        LocalStore.saveItems(items)
        LocalStore.saveQueue(pendingOperations)
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let newValue = !items[index].isDone
        items[index].isDone = newValue
        LocalStore.saveItems(items)

        // Item was created offline and hasn't been synced yet: the queued
        // create will pick up its final state, no separate call needed yet.
        guard item.id > 0 else {
            queue(.update(id: item.id, completed: newValue))
            return
        }
        guard network.isConnected else {
            queue(.update(id: item.id, completed: newValue))
            return
        }
        Task {
            do {
                _ = try await APIClient.updateTask(id: item.id, completed: newValue)
            } catch {
                queue(.update(id: item.id, completed: newValue))
            }
        }
    }

    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { items[$0] }
        items.remove(atOffsets: offsets)
        LocalStore.saveItems(items)

        for item in toDelete {
            if item.id < 0 {
                // Never made it to the server: drop the queued create/update for it.
                pendingOperations.removeAll { op in
                    switch op {
                    case .create(let localId, _, _): return localId == item.id
                    case .update(let id, _): return id == item.id
                    default: return false
                    }
                }
                continue
            }
            if network.isConnected {
                Task {
                    do {
                        try await APIClient.deleteTask(id: item.id)
                    } catch {
                        queue(.delete(id: item.id))
                    }
                }
            } else {
                pendingOperations.append(.delete(id: item.id))
            }
        }
        LocalStore.saveQueue(pendingOperations)
    }

    func deleteCheckedItems() {
        let indices = IndexSet(items.indices.filter { items[$0].isDone })
        delete(at: indices)
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        LocalStore.saveItems(items)

        let ids = items.map(\.id)
        guard network.isConnected else {
            queue(.reorder(ids: ids))
            return
        }
        Task {
            do {
                try await APIClient.reorderTasks(ids: ids.filter { $0 > 0 })
            } catch {
                queue(.reorder(ids: ids))
            }
        }
    }

    private func queue(_ operation: PendingOperation) {
        pendingOperations.append(operation)
        LocalStore.saveQueue(pendingOperations)
    }
}
