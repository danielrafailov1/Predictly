//
//  PartyInviteHandler.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-07-28.
//
import Foundation
import Supabase

// Handle party invite acceptance/decline logic
class PartyInviteHandler {
    let supabaseClient: SupabaseClient
    
    init(supabaseClient: SupabaseClient) {
        self.supabaseClient = supabaseClient
    }
    
    // Function to accept a party invite
    func acceptPartyInvite(inviteId: Int64, partyId: Int64, userId: String) async throws {
        // Step 1: Check if the party still has room for more members
        let partyResponse = try await supabaseClient
            .from("Parties")
            .select("max_members")
            .eq("id", value: Int(partyId))
            .limit(1)
            .execute()
        
        struct PartyInfo: Codable { let max_members: Int64 }
        let partyInfos = try JSONDecoder().decode([PartyInfo].self, from: partyResponse.data)
        
        guard let partyInfo = partyInfos.first else {
            throw PartyInviteError.partyNotFound
        }
        
        // Step 2: Check current member count
        let membersResponse = try await supabaseClient
            .from("Party Members")
            .select("user_id", count: .exact)
            .eq("party_id", value: Int(partyId))
            .execute()
        
        let currentMemberCount = membersResponse.count ?? 0
        
        if currentMemberCount >= partyInfo.max_members {
            throw PartyInviteError.partyFull
        }
        
        // Step 3: Check if user is already a member (safety check)
        let existingMemberResponse = try await supabaseClient
            .from("Party Members")
            .select("user_id", count: .exact)
            .eq("party_id", value: Int(partyId))
            .eq("user_id", value: userId)
            .execute()
        
        if (existingMemberResponse.count ?? 0) > 0 {
            throw PartyInviteError.alreadyMember
        }
        
        // Step 4: Add user to Party Members table
        let newMember = PartyMemberInsert(party_id: Int(partyId), user_id: userId)
        _ = try await supabaseClient
            .from("Party Members")
            .insert(newMember)
            .execute()
        
        // Step 5: Update the invite status to "accepted"
        _ = try await supabaseClient
            .from("Party Invites")
            .update(["status": "accepted"])
            .eq("id", value: Int(inviteId))
            .execute()
        
        print("✅ Successfully accepted party invite and added user to party members")
    }
    
    // Function to decline a party invite
    func declinePartyInvite(inviteId: Int64) async throws {
        _ = try await supabaseClient
            .from("Party Invites")
            .update(["status": "declined"])
            .eq("id", value: Int(inviteId))
            .execute()
        
        print("✅ Successfully declined party invite")
    }
}

// Custom error types for better error handling
enum PartyInviteError: LocalizedError {
    case partyNotFound
    case partyFull
    case alreadyMember
    case inviteNotFound
    
    var errorDescription: String? {
        switch self {
        case .partyNotFound:
            return "Party not found"
        case .partyFull:
            return "Party is full"
        case .alreadyMember:
            return "You are already a member of this party"
        case .inviteNotFound:
            return "Invite not found"
        }
    }
}
