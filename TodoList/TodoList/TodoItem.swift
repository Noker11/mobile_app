import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    let id: Int
    var title: String
    var description: String?
    var isDone: Bool
    var order: Int

    enum CodingKeys: String, CodingKey {
        case id, title, description, order
        case isDone = "completed"
    }
}
