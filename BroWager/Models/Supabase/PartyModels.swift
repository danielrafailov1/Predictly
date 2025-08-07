import Foundation

struct Party: Decodable {
    let id: Int64?
    let party_code: String?
    let created_by: String?
    let party_name: String?
    let privacy_option: String?
    let max_members: Int?
    let bet: String?
    let bet_type: String?
    let options: [String]?
    let terms: String?
    let status: String?
    let max_selections: Int?
    let timer_duration: Int?
    let allow_early_finish: Bool?
    let contest_unit: String?
    let contest_target: Int?
    let allow_ties: Bool?
    
    static func == (lhs: Party, rhs: Party) -> Bool {
        return lhs.id == rhs.id
    }
}

struct UserBet: Codable, Identifiable {
    let id: Int64
    let user_id: String
    let party_id: Int64
    let bet_selection: [String]
    let bet_resolved: Bool
    let is_winner: Bool
    let created_at: String?
    let updated_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id, user_id, party_id, bet_selection, bet_resolved, is_winner, created_at, updated_at
    }
}

struct PartyInsertPayload: Codable {
    let created_by: String
    let party_name: String
    let privacy_option: String
    let max_members: Int
    let bet: String
    let bet_date: String
    let bet_type: String?
    let options: [String]
    let terms: String
    let status: String
    let party_code: String
    let max_selections: Int // Changed from Int? to Int
    // Optional fields that might be set by database defaults
    let game_status: String?
    
    init(created_by: String, party_name: String, privacy_option: String, max_members: Int, bet: String, bet_date: String, bet_type: String, options: [String], terms: String, status: String, party_code: String, max_selections: Int, game_status: String? = "waiting") { // Added max_selections parameter
        self.created_by = created_by
        self.party_name = party_name
        self.privacy_option = privacy_option
        self.max_members = max_members
        self.bet = bet
        self.bet_date = bet_date
        self.bet_type = bet_type
        self.options = options
        self.terms = terms
        self.status = status
        self.party_code = party_code
        self.max_selections = max_selections // Changed from nil to the parameter value
        self.game_status = game_status
    }
}

struct PartyMember: Codable {
    let id: Int64?
    let party_id: Int64
    let user_id: String
    let joined_at: String?
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
    let wins: Int?
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

struct PartyMemberInsert: Codable {
    let party_id: Int
    let user_id: String
}

struct PartyInviteWithDetails: Codable, Identifiable {
    let id: Int64
    let partyId: Int64
    let partyName: String
    let inviterUserId: String
    let inviterUsername: String
    let inviteeUserId: String
    let status: String
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case partyId = "party_id"
        case partyName = "party_name"
        case inviterUserId = "inviter_user_id"
        case inviterUsername = "inviter_username"
        case inviteeUserId = "invitee_user_id"
        case status
        case createdAt = "created_at"
    }
}

struct PartyInviteBasic: Codable, Identifiable {
    let id: Int64
    let partyId: Int64
    let inviterUserId: String
    let inviteeUserId: String
    let status: String
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case partyId = "party_id"
        case inviterUserId = "inviter_user_id"
        case inviteeUserId = "invitee_user_id"
        case status
        case createdAt = "created_at"
    }
}
