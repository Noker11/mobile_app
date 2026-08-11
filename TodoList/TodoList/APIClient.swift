import Foundation

enum APIError: Error {
    case invalidResponse
}

enum APIClient {
    static let baseURL = URL(string: "http://localhost:8080")!

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func listTasks() async throws -> [TodoItem] {
        let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("tasks"))
        try validate(response)
        return try decoder.decode([TodoItem].self, from: data)
    }

    static func createTask(title: String, description: String? = nil) async throws -> TodoItem {
        var request = URLRequest(url: baseURL.appendingPathComponent("tasks"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(TaskCreatePayload(title: title, description: description))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, allowed: [200, 201])
        return try decoder.decode(TodoItem.self, from: data)
    }

    static func updateTask(id: Int, completed: Bool) async throws -> TodoItem {
        var request = URLRequest(url: baseURL.appendingPathComponent("tasks/\(id)"))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(TaskUpdatePayload(completed: completed))
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try decoder.decode(TodoItem.self, from: data)
    }

    static func deleteTask(id: Int) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("tasks/\(id)"))
        request.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response, allowed: [200, 204])
    }

    static func reorderTasks(ids: [Int]) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("tasks/order"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(TaskReorderPayload(ids: ids))
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
    }

    private static func validate(_ response: URLResponse, allowed: Set<Int> = [200, 201, 204]) throws {
        guard let http = response as? HTTPURLResponse, allowed.contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
    }
}

private struct TaskCreatePayload: Encodable {
    let title: String
    let description: String?
}

private struct TaskUpdatePayload: Encodable {
    let completed: Bool
}

private struct TaskReorderPayload: Encodable {
    let ids: [Int]
}
