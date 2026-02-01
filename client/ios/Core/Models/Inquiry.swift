import Foundation

struct Inquiry: Identifiable, Codable {
    let id: String
    let userId: String
    let category: Category
    let content: String
    let answer: String?
    let status: Status
    let isReadByUser: Bool?
    let createdAt: String // ISO String
    let answeredAt: String? // ISO String
    
    enum Status: String, Codable {
        case pending
        case answered
        
        var localized: String {
            switch self {
            case .pending: return "answered" // Simplification for port
            case .answered: return "answered"
            }
        }
    }
    
    enum Category: String, Codable, CaseIterable {
        case bug
        case complaint
        case suggestion
        case other
        
        var localized: String {
            return self.rawValue 
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, category, content, answer, status
        case userId = "user_id"
        case isReadByUser = "is_read_by_user"
        case createdAt = "created_at"
        case answeredAt = "answered_at"
    }
}
