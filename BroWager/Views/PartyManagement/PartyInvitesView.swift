import SwiftUI
import Supabase

struct PartyInvitesView: View {
    let userId: String
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var invites: [PartyInviteRow] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    var body: some View {
        ZStack {
            // Gradient layer - this will be the true background
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            // Navigation layer on top of the gradient
            NavigationView {
                VStack(spacing: 16) {
                    Text("Party Invites")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 16)
                    if isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if let error = errorMessage {
                        Text(error).foregroundColor(.red)
                    } else if invites.isEmpty {
                        Text("No pending invites.").foregroundColor(.white.opacity(0.7))
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(invites) { invite in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(invite.partyName ?? "Invite to a Party")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("From: \(invite.inviterUsername ?? "a friend")")
                                                .font(.subheadline)
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        
                                        Spacer()
                                        
                                        Button("Decline") { Task { await decline(invite) } }
                                            .buttonStyle(.bordered)
                                            .tint(.red)
                                        
                                        Button("Accept") { Task { await accept(invite) } }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.green)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    if let success = successMessage {
                        Text(success).foregroundColor(.green)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.clear) // Make the VStack background clear
                .navigationTitle("Party Invites")
                .navigationBarTitleDisplayMode(.inline) // Optional: for a cleaner look
                .toolbar { 
                    ToolbarItem(placement: .navigationBarLeading) { 
                        Button("Close") { dismiss() }
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .task { await loadInvites() }
    }
    
    private func loadInvites() async {
        isLoading = true
        errorMessage = nil
        do {
            let resp = try await supabaseClient
                .from("Party Invites")
                .select("id, party_id, inviter_user_id, status")
                .eq("invitee_user_id", value: userId)
                .eq("status", value: "pending")
                .execute()
            
            let initialInvites = try JSONDecoder().decode([PartyInviteRow].self, from: resp.data)

            // Use a TaskGroup to fetch details concurrently and safely
            let invitesWithDetails = await withTaskGroup(of: PartyInviteRow.self, returning: [PartyInviteRow].self) { group in
                var results: [PartyInviteRow] = []

                for invite in initialInvites {
                    group.addTask {
                        var detailedInvite = invite
                        detailedInvite.inviterUsername = await fetchUsername(for: invite.inviter_user_id)
                        detailedInvite.partyName = await fetchPartyName(for: invite.party_id)
                        return detailedInvite
                    }
                }

                for await result in group {
                    results.append(result)
                }
                return results
            }

            await MainActor.run {
                self.invites = invitesWithDetails
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load invites: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    private func fetchUsername(for userId: String) async -> String? {
        do {
            let userResp = try await supabaseClient
                .from("Username")
                .select("username")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            struct UsernameRow: Decodable { let username: String }
            let usernameRow = try JSONDecoder().decode(UsernameRow.self, from: userResp.data)
            return usernameRow.username
        } catch {
            print("[PartyInvitesView] Failed to fetch username for inviter \(userId): \(error)")
            return nil
        }
    }

    private func fetchPartyName(for partyId: Int64) async -> String? {
        do {
            let partyResp = try await supabaseClient
                .from("Parties")
                .select("party_name")
                .eq("id", value: Int(partyId)) // Cast Int64 to Int to fix PostgrestFilterValue error
                .limit(1)
                .execute()
            struct PartyNameRow: Decodable { let party_name: String }
            let partyNameRow = try JSONDecoder().decode(PartyNameRow.self, from: partyResp.data)
            return partyNameRow.party_name
        } catch {
            print("[PartyInvitesView] Failed to fetch party name for party \(partyId): \(error)")
            return nil
        }
    }
    
    private func accept(_ invite: PartyInviteRow) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            // Update invite status
            _ = try await supabaseClient
                .from("Party Invites")
                .update(["status": "accepted"])
                .eq("id", value: Int(invite.id))
                .execute()
            // Add to Party Members
            let now = ISO8601DateFormatter().string(from: Date())
            let newMember = NewPartyMember(
                party_id: invite.party_id,
                user_id: userId,
                joined_at: now,
                created_at: now
            )
            _ = try await supabaseClient
                .from("Party Members")
                .insert(newMember)
                .execute()
            await MainActor.run {
                self.successMessage = "Joined party!"
                self.isLoading = false
            }
            await loadInvites()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to accept invite: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    private func decline(_ invite: PartyInviteRow) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            _ = try await supabaseClient
                .from("Party Invites")
                .update(["status": "declined"])
                .eq("id", value: Int(invite.id))
                .execute()
            await MainActor.run {
                self.successMessage = "Invite declined."
                self.isLoading = false
            }
            await loadInvites()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to decline invite: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

struct PartyInviteRow: Decodable, Identifiable {
    let id: Int64
    let party_id: Int64
    let inviter_user_id: String
    let status: String
    
    // New fields for display
    var inviterUsername: String?
    var partyName: String?
}

#Preview {
    PartyInvitesView(userId: "test-user-id")
        .environment(\.supabaseClient, .development)
} 


 