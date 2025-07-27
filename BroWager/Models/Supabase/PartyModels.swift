import Foundation


// Party Models
struct Party: Codable, Identifiable, Hashable {
    let id: Int64?
    let created_at: String
    let party_code: String
    let created_by: String
    let party_name: String
    let privacy_option: String
    let max_members: Int64
    let bet: String
    let bet_type: String
    let options: [String]
    let status: String
    let terms: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Party, rhs: Party) -> Bool {
        lhs.id == rhs.id
    }
}

struct PartyInsertPayload: Encodable {
    let created_by: String
    let party_name: String
    let privacy_option: String
    let max_members: Int
    let bet: String
    let bet_type: String
    let options: [String]
    let terms: String
    let status: String
    let party_code: String
}

struct PartyMember: Codable {
    let id: Int
    let created_at: String
    let party_id: Int64
    let joined_at: String
    let user_id: String
}

struct NewPartyMember: Codable {
    let party_id: Int64
    let user_id: String
    let joined_at: String
    let created_at: String
}

struct NewParty: Codable {
    let party_code: String
    let game_id: Int64
    let created_by: String
    let party_name: String
    let privacy_option: String
    let max_members: Int64
    let bet_quantity: Int64
    let bet_type: String
    let events: [String]
}

struct LoginInfo: Codable {
    let created_at: String?
    let email: String?
    let user_id: String
    let music_on: Bool?
}

struct PartyInvite: Codable {
    let party_id: Int64
    let inviter_user_id: String
    let invitee_user_id: String
    let status: String
}

struct NewUserBet: Codable {
    let party_id: Int64
    let user_id: String
    let bet_events: [String]
    let score: Int
}

struct UserBet: Codable {
    let id: Int
    let created_at: String
    let party_id: Int64
    let user_id: String
    let bet_events: [String]
    let score: Int?
}
