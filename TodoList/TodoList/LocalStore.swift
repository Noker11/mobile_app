import Foundation

/// A change made while offline, queued to be replayed against the server
/// once connectivity is back. `localId` values are negative placeholder
/// ids assigned to items created offline, before the server has issued
/// a real id for them.
enum PendingOperation: Codable, Equatable {
    case create(localId: Int, title: String, description: String?)
    case update(id: Int, completed: Bool)
    case delete(id: Int)
    case reorder(ids: [Int])

    /// Rewrites any ids that were placeholders for offline-created items
    /// once the real server id is known.
    func remapped(using idMap: [Int: Int]) -> PendingOperation {
        switch self {
        case .create:
            return self
        case .update(let id, let completed):
            return .update(id: idMap[id] ?? id, completed: completed)
        case .delete(let id):
            return .delete(id: idMap[id] ?? id)
        case .reorder(let ids):
            return .reorder(ids: ids.map { idMap[$0] ?? $0 })
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, localId, title, description, id, completed, ids
    }

    private enum OpType: String, Codable {
        case create, update, delete, reorder
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .create(let localId, let title, let description):
            try container.encode(OpType.create, forKey: .type)
            try container.encode(localId, forKey: .localId)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(description, forKey: .description)
        case .update(let id, let completed):
            try container.encode(OpType.update, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(completed, forKey: .completed)
        case .delete(let id):
            try container.encode(OpType.delete, forKey: .type)
            try container.encode(id, forKey: .id)
        case .reorder(let ids):
            try container.encode(OpType.reorder, forKey: .type)
            try container.encode(ids, forKey: .ids)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(OpType.self, forKey: .type) {
        case .create:
            self = .create(
                localId: try container.decode(Int.self, forKey: .localId),
                title: try container.decode(String.self, forKey: .title),
                description: try container.decodeIfPresent(String.self, forKey: .description)
            )
        case .update:
            self = .update(
                id: try container.decode(Int.self, forKey: .id),
                completed: try container.decode(Bool.self, forKey: .completed)
            )
        case .delete:
            self = .delete(id: try container.decode(Int.self, forKey: .id))
        case .reorder:
            self = .reorder(ids: try container.decode([Int].self, forKey: .ids))
        }
    }
}

/// Persists the last known task list and any offline edits still waiting
/// to be sent to the server, so the app keeps working (and remembers
/// changes) without a connection.
enum LocalStore {
    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static let itemsURL = documentsURL.appendingPathComponent("todos_cache.json")
    private static let queueURL = documentsURL.appendingPathComponent("pending_operations.json")

    static func loadItems() -> [TodoItem] {
        guard let data = try? Data(contentsOf: itemsURL),
              let items = try? JSONDecoder().decode([TodoItem].self, from: data) else { return [] }
        return items
    }

    static func saveItems(_ items: [TodoItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: itemsURL, options: .atomic)
    }

    static func loadQueue() -> [PendingOperation] {
        guard let data = try? Data(contentsOf: queueURL),
              let ops = try? JSONDecoder().decode([PendingOperation].self, from: data) else { return [] }
        return ops
    }

    static func saveQueue(_ operations: [PendingOperation]) {
        guard let data = try? JSONEncoder().encode(operations) else { return }
        try? data.write(to: queueURL, options: .atomic)
    }
}
