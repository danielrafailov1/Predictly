import SwiftUI
import Supabase

struct PartyInvitesView: View {
    let userId: String
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var invites: [PartyInviteBasic] = []
    @State private var partyNames: [Int64: String] = [:]
    @State private var inviterUsernames: [String: String] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient that covers entire screen
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(.all) // Changed to .all
                
                VStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .colorScheme(.dark) // Force dark
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.white) // Force white
                                .multilineTextAlignment(.center)
                                .font(.body)
                            Button("Retry") {
                                Task { await loadInvites() }
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white) // Force white
                            .cornerRadius(10)
                        }
                    } else if invites.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "envelope")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.5))
                            Text("No party invites")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white) // Force white
                        }
                    } else {
                        List {
                            ForEach(invites) { invite in
                                PartyInviteRow(
                                    invite: invite,
                                    partyName: partyNames[invite.partyId] ?? "Unknown Party",
                                    inviterUsername: inviterUsernames[invite.inviterUserId] ?? "Unknown User",
                                    onInviteProcessed: { inviteId in
                                        invites.removeAll { $0.id == inviteId }
                                    }
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(PlainListStyle()) // Add this
                        .scrollContentBackground(.hidden) // Add this for iOS 16+
                        .colorScheme(.dark) // Force dark color scheme
                    }
                }
            }
            .navigationTitle("Party Invites")
            .navigationBarTitleDisplayMode(.inline) // Add this
            .toolbarBackground(.clear, for: .navigationBar) // Make toolbar clear
            .toolbarColorScheme(.dark, for: .navigationBar) // Force dark scheme
            .preferredColorScheme(.dark) // Force entire view to dark
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white) // Force white button text
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Prevent split view issues
        .preferredColorScheme(.dark) // Apply to entire NavigationView
        .task {
            await loadInvites()
        }
    }
    
    // Rest of your loadInvites function remains the same...
    private func loadInvites() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let invitesResponse = try await supabaseClient
                .from("Party Invites")
                .select("id, party_id, inviter_user_id, invitee_user_id, status, created_at")
                .eq("invitee_user_id", value: userId)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
            
            let fetchedInvites = try JSONDecoder().decode([PartyInviteBasic].self, from: invitesResponse.data)
                .filter { $0.status == "pending" }
            
            let partyIds = Array(Set(fetchedInvites.map { Int($0.partyId) }))
            var partyNames: [Int64: String] = [:]
            
            if !partyIds.isEmpty {
                let partiesResponse = try await supabaseClient
                    .from("Parties")
                    .select("id, party_name")
                    .in("id", values: partyIds)
                    .execute()
                
                struct PartyNameRow: Codable {
                    let id: Int64
                    let party_name: String
                }
                
                let partyNameRows = try JSONDecoder().decode([PartyNameRow].self, from: partiesResponse.data)
                partyNames = Dictionary(uniqueKeysWithValues: partyNameRows.map { ($0.id, $0.party_name) })
            }
            
            let inviterIds = Array(Set(fetchedInvites.map { $0.inviterUserId }))
            var inviterUsernames: [String: String] = [:]
            
            if !inviterIds.isEmpty {
                let usernamesResponse = try await supabaseClient
                    .from("Username")
                    .select("user_id, username")
                    .in("user_id", values: inviterIds)
                    .execute()
                
                struct UsernameRow: Codable {
                    let user_id: String
                    let username: String
                }
                
                let usernameRows = try JSONDecoder().decode([UsernameRow].self, from: usernamesResponse.data)
                inviterUsernames = Dictionary(uniqueKeysWithValues: usernameRows.map { ($0.user_id, $0.username) })
            }
            
            await MainActor.run {
                self.invites = fetchedInvites
                self.partyNames = partyNames
                self.inviterUsernames = inviterUsernames
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load invites: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

struct PartyInviteRow: View {
    let invite: PartyInviteBasic
    let partyName: String
    let inviterUsername: String
    let onInviteProcessed: (Int64) -> Void
    
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(partyName)
                .font(.headline)
                .foregroundColor(.white) // Force white
            
            Text("Invited by: \(inviterUsername)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7)) // Force white with opacity
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            if let success = successMessage {
                Text(success)
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            if invite.status == "pending" {
                HStack(spacing: 12) {
                    Button("Accept") {
                        Task { await acceptInvite() }
                    }
                    .disabled(isProcessing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white) // Force white
                    .cornerRadius(8)
                    .font(.system(size: 14, weight: .semibold))
                    
                    Button("Decline") {
                        Task { await declineInvite() }
                    }
                    .disabled(isProcessing)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white) // Force white
                    .cornerRadius(8)
                    .font(.system(size: 14, weight: .semibold))
                    
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .colorScheme(.dark) // Force dark
                    }
                }
            } else {
                Text("Status: \(invite.status.capitalized)")
                    .font(.caption)
                    .foregroundColor(invite.status == "accepted" ? .green : .red)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .colorScheme(.dark) // Force entire row to dark scheme
    }
    
    // Rest of your functions remain the same...
    private func acceptInvite() async {
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let handler = PartyInviteHandler(supabaseClient: supabaseClient)
            try await handler.acceptPartyInvite(
                inviteId: invite.id,
                partyId: invite.partyId,
                userId: invite.inviteeUserId
            )
            
            await MainActor.run {
                self.successMessage = "Joined party successfully!"
                self.isProcessing = false
            }
            
            onInviteProcessed(invite.id)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
            }
        }
    }
    
    private func declineInvite() async {
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let handler = PartyInviteHandler(supabaseClient: supabaseClient)
            try await handler.declinePartyInvite(inviteId: invite.id)
            
            await MainActor.run {
                self.successMessage = "Invite declined"
                self.isProcessing = false
            }
            
            onInviteProcessed(invite.id)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isProcessing = false
            }
        }
    }
}
