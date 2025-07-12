import Foundation

// User Models
struct User: Codable {
    let id: Int64
    let created_at: String
    let email: String
    let password: String
    let user_id: String
}

struct UserToken: Codable {
    let balance: Double
    let updated_at: String
    let user_id: String
}

struct Friend: Codable {
    let id: Int64
    let created_at: String
    let status: String
    let user_id: String
    let friend_id: String
} 