import Foundation
import Supabase

class AccountDeletionService {
    private let supabaseClient: SupabaseClient
    
    init(supabaseClient: SupabaseClient) {
        self.supabaseClient = supabaseClient
    }
    
    func deleteAccount(userId: String) async -> (success: Bool, errorMessage: String?) {
        do {
            print("🗑️ Starting account deletion for user: \(userId)")
            
            // Delete in the correct order to avoid foreign key constraints
            // 1. Delete direct messages (both sent and received)
            try await deleteDirectMessages(userId: userId)
            
            // 2. Delete party chat messages
            try await deletePartyChatMessages(userId: userId)
            
            // 3. Delete party invites (both sent and received)
            try await deletePartyInvites(userId: userId)
            
            // 4. Delete user bets (from both User Bets and partybets tables)
            try await deleteUserBets(userId: userId)
            try await deletePartyBets(userId: userId)
            
            // 5. Delete party memberships
            try await deletePartyMemberships(userId: userId)
            
            // 6. Delete parties created by this user (must be before login info deletion)
            try await deleteUserCreatedParties(userId: userId)
            
            // 7. Delete friend relationships
            try await deleteFriendRelationships(userId: userId)
            
            // 8. Delete profile images
            try await deleteProfileImages(userId: userId)
            
            // 9. Delete username
            try await deleteUsername(userId: userId)
            
            // 10. Delete user wins
            try await deleteUserWins(userId: userId)
            
            // 11. Delete user device tokens
            try await deleteUserDeviceTokens(userId: userId)
            
            // 12. Delete login information (must be last due to foreign key constraints)
            try await deleteLoginInformation(userId: userId)
            
            // 13. Finally, sign out the user (actual user deletion requires admin access)
            try await deleteUserFromAuth()
            
            print("✅ Successfully deleted account data for user: \(userId)")
            print("⚠️ Note: User account in Supabase Auth needs manual deletion from admin panel")
            return (true, nil)
            
        } catch {
            print("❌ Error deleting account: \(error.localizedDescription)")
            return (false, "Failed to delete account: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private deletion methods
    
    private func deletePartyInvites(userId: String) async throws {
        print("🗑️ Deleting party invites for user: \(userId)")
        
        // Delete invites sent by this user
        let sentInvitesResult = try await supabaseClient
            .from("Party Invites")
            .delete()
            .eq("inviter_user_id", value: userId)
            .execute()
        
        // Delete invites received by this user
        let receivedInvitesResult = try await supabaseClient
            .from("Party Invites")
            .delete()
            .eq("invitee_user_id", value: userId)
            .execute()
        
        print("✅ Deleted party invites - sent: \(sentInvitesResult.count ?? 0), received: \(receivedInvitesResult.count ?? 0)")
    }
    
    private func deletePartyMemberships(userId: String) async throws {
        print("🗑️ Deleting party memberships for user: \(userId)")
        
        let result = try await supabaseClient
            .from("Party Members")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Deleted party memberships: \(result.count ?? 0)")
    }
    
    private func deleteUserBets(userId: String) async throws {
        print("🗑️ Deleting user bets for user: \(userId)")
        
        let result = try await supabaseClient
            .from("User Bets")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Deleted user bets: \(result.count ?? 0)")
    }
    
    private func deleteFriendRelationships(userId: String) async throws {
        print("🗑️ Deleting friend relationships for user: \(userId)")
        
        // Delete friendships where user is the initiator
        let sentFriendshipsResult = try await supabaseClient
            .from("Friends")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        // Delete friendships where user is the friend
        let receivedFriendshipsResult = try await supabaseClient
            .from("Friends")
            .delete()
            .eq("friend_id", value: userId)
            .execute()
        
        print("✅ Deleted friend relationships - sent: \(sentFriendshipsResult.count ?? 0), received: \(receivedFriendshipsResult.count ?? 0)")
    }
    
    private func deleteProfileImages(userId: String) async throws {
        print("🗑️ Deleting profile images for user: \(userId)")
        
        // First, get the profile image URL to delete from storage
        let imageResponse = try await supabaseClient
            .from("Profile Images")
            .select("profile_image_url")
            .eq("user_id", value: userId)
            .execute()
        
        struct ImageRow: Decodable { let profile_image_url: String }
        let imageRows = try JSONDecoder().decode([ImageRow].self, from: imageResponse.data)
        
        // Delete from storage if image exists
        for imageRow in imageRows {
            if !imageRow.profile_image_url.isEmpty {
                do {
                    try await supabaseClient.storage
                        .from("profile-images")
                        .remove(paths: [imageRow.profile_image_url])
                    print("✅ Deleted profile image from storage: \(imageRow.profile_image_url)")
                } catch {
                    print("⚠️ Could not delete profile image from storage: \(error.localizedDescription)")
                }
            }
        }
        
        // Delete from Profile Images table
        let result = try await supabaseClient
            .from("Profile Images")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Deleted profile images from database: \(result.count ?? 0)")
    }
    
    private func deleteUsername(userId: String) async throws {
        print("🗑️ Deleting username for user: \(userId)")
        
        let result = try await supabaseClient
            .from("Username")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Deleted username: \(result.count ?? 0)")
    }
    
    private func deleteLoginInformation(userId: String) async throws {
        print("🗑️ Deleting login information for user: \(userId)")
        
        let result = try await supabaseClient
            .from("Login Information")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Deleted login information: \(result.count ?? 0)")
    }
    
    private func deleteUserTokens(userId: String) async throws {
        print("🗑️ Deleting user tokens for user: \(userId)")
        
        let result = try await supabaseClient
            .from("User Tokens")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Deleted user tokens: \(result.count ?? 0)")
    }
    
    private func deleteDirectMessages(userId: String) async throws {
        print("🗑️ Deleting direct messages for user: \(userId)")
        
        // Delete messages sent by this user
        let sentMessagesResult = try await supabaseClient
            .from("DirectMessages")
            .delete()
            .eq("sender_id", value: userId)
            .execute()
        
        // Delete messages received by this user
        let receivedMessagesResult = try await supabaseClient
            .from("DirectMessages")
            .delete()
            .eq("receiver_id", value: userId)
            .execute()
        
        print("✅ Deleted direct messages - sent: \(sentMessagesResult.count ?? 0), received: \(receivedMessagesResult.count ?? 0)")
    }
    
    private func deletePartyChatMessages(userId: String) async throws {
        print("🗑️ Deleting party chat messages for user: \(userId)")
        
        let result = try await supabaseClient
            .from("PartyChatMessages")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Deleted party chat messages: \(result.count ?? 0)")
    }
    
    private func deletePartyBets(userId: String) async throws {
        print("🗑️ Deleting party bets for user: \(userId)")
        
        let result = try await supabaseClient
            .from("partybets")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Deleted party bets: \(result.count ?? 0)")
    }
    
    private func deleteUserWins(userId: String) async throws {
        print("🗑️ Deleting user wins for user: \(userId)")
        
        let result = try await supabaseClient
            .from("user_wins")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Deleted user wins: \(result.count ?? 0)")
    }
    
    private func deleteUserDeviceTokens(userId: String) async throws {
        print("🗑️ Deleting user device tokens for user: \(userId)")
        
        let result = try await supabaseClient
            .from("user_device_tokens")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Deleted user device tokens: \(result.count ?? 0)")
    }
    
    private func deleteUserCreatedParties(userId: String) async throws {
        print("🗑️ Deleting parties created by user: \(userId)")
        
        // First, get all parties created by this user
        let partiesResponse = try await supabaseClient
            .from("Parties")
            .select("id")
            .eq("created_by", value: userId)
            .execute()
        
        struct PartyRow: Decodable { let id: Int64 }
        let parties = try JSONDecoder().decode([PartyRow].self, from: partiesResponse.data)
        
        print("🗑️ Found \(parties.count) parties created by user \(userId)")
        
        // Delete each party and its associated data
        for party in parties {
            let partyId = party.id
            print("🗑️ Deleting party ID: \(partyId)")
            
            // Delete party members for this party
            let membersResult = try await supabaseClient
                .from("Party Members")
                .delete()
                .eq("party_id", value: String(partyId))
                .execute()
            
            // Delete party invites for this party
            let invitesResult = try await supabaseClient
                .from("Party Invites")
                .delete()
                .eq("party_id", value: String(partyId))
                .execute()
            
            // Delete party chat messages for this party
            let chatResult = try await supabaseClient
                .from("PartyChatMessages")
                .delete()
                .eq("party_id", value: String(partyId))
                .execute()
            
            // Delete user bets for this party
            let betsResult = try await supabaseClient
                .from("User Bets")
                .delete()
                .eq("party_id", value: String(partyId))
                .execute()
            
            // Delete party bets for this party
            let partyBetsResult = try await supabaseClient
                .from("partybets")
                .delete()
                .eq("party_id", value: String(partyId))
                .execute()
            
            // Finally, delete the party itself
            let partyResult = try await supabaseClient
                .from("Parties")
                .delete()
                .eq("id", value: String(partyId))
                .execute()
            
            print("✅ Deleted party \(partyId) and all associated data")
        }
        
        print("✅ Successfully deleted all parties created by user \(userId)")
    }
    
    private func deleteUserFromAuth() async throws {
        print("🗑️ Deleting user from Supabase Auth")
        
        // For client-side deletion, we'll sign out the user
        // The actual user deletion should be handled by the backend or admin panel
        // This is a limitation of client-side Supabase
        try await supabaseClient.auth.signOut()
        
        print("✅ Signed out user from Supabase Auth")
    }
}
