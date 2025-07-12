import SwiftUI
import Supabase
import Foundation // For Codable
// Import shared model

struct InviteOthersToPartyView: View {
    let partyId: Int64
    let inviterUserId: String
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Invite Others to Party")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 16)
                TextField("Enter email address", text: $email)
                    .font(.system(size: 18))
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                if let error = errorMessage {
                    Text(error).foregroundColor(.red)
                }
                if let success = successMessage {
                    Text(success).foregroundColor(.green)
                }
                Button("Send Invite") {
                    Task { await sendInvite() }
                }
                .disabled(email.isEmpty || isLoading)
                .foregroundColor(.white)
                .padding()
                .background(email.isEmpty ? Color.gray : Color.green)
                .cornerRadius(12)
                Spacer()
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()
            )
            .navigationTitle("Invite Others")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } } }
        }
    }
    
    private func sendInvite() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            // Look up user_id by email
            let userResp = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .limit(1)
                .execute()
            struct UserIdRow: Decodable { let user_id: String }
            let userIdRows = try JSONDecoder().decode([UserIdRow].self, from: userResp.data)
            guard let userIdRow = userIdRows.first else {
                errorMessage = "User not found"
                isLoading = false
                return
            }
            let inviteeUserId = userIdRow.user_id

            // Check 1: Prevent self-invites
            if inviteeUserId == inviterUserId {
                errorMessage = "You cannot invite yourself to a party."
                isLoading = false
                return
            }

            // Check 2: Prevent inviting existing members
            let membersResp = try await supabaseClient
                .from("Party Members")
                .select("user_id", count: .exact)
                .eq("party_id", value: Int(partyId))
                .eq("user_id", value: inviteeUserId)
                .execute()
            
            if (membersResp.count ?? 0) > 0 {
                errorMessage = "This user is already in the party."
                isLoading = false
                return
            }

            // Insert invite if all checks pass
            let invite = PartyInvite(
                party_id: partyId,
                inviter_user_id: inviterUserId,
                invitee_user_id: inviteeUserId,
                status: "pending"
            )
            _ = try await supabaseClient
                .from("Party Invites")
                .insert(invite)
                .execute()
            await MainActor.run {
                self.successMessage = "Invite sent!"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to send invite: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
} 