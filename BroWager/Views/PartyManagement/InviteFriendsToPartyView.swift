import SwiftUI
import Supabase
import Foundation // For Codable
// Import shared model

struct InviteFriendsToPartyView: View {
    let partyId: Int64
    let inviterUserId: String
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FriendUser] = []
    @State private var selectedFriendIds: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let error = errorMessage {
                    Text(error).foregroundColor(.red)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(friends, id: \.user_id) { friend in
                                HStack {
                                    Text(friend.username)
                                        .foregroundColor(.gray.opacity(0.9))
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    selectedFriendIds.contains(friend.user_id)
                                    ? Color.blue.opacity(0.3)
                                    : Color.gray.opacity(0.15)
                                )
                                .cornerRadius(10)
                                .onTapGesture {
                                    if selectedFriendIds.contains(friend.user_id) {
                                        selectedFriendIds.remove(friend.user_id)
                                    } else {
                                        selectedFriendIds.insert(friend.user_id)
                                    }
                                }
                            }
                        }
                    }
                }

                if let success = successMessage {
                    Text(success).foregroundColor(.green)
                }

                Button("Send Invites") {
                    Task { await sendInvites() }
                }
                .disabled(selectedFriendIds.isEmpty)
                .foregroundColor(.white)
                .padding()
                .background(selectedFriendIds.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(12)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2),
                                                Color(red: 0.15, green: 0.15, blue: 0.25)]),
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task { await loadFriends() }
    }


    
    private func loadFriends() async {
        isLoading = true
        errorMessage = nil
        do {
            // Step 1: Get the list of current party members
            let membersResp = try await supabaseClient
                .from("Party Members")
                .select("user_id")
                .eq("party_id", value: Int(partyId))
                .execute()
            
            struct MemberRow: Decodable { let user_id: String }
            let memberRows = try JSONDecoder().decode([MemberRow].self, from: membersResp.data)
            let partyMemberIds = Set(memberRows.map { $0.user_id })

            // Step 2: Get the user's friends
            let friendsResp = try await supabaseClient
                .rpc("get_friends", params: ["uid": inviterUserId])
                .execute()
            let allFriends = try JSONDecoder().decode([FriendUser].self, from: friendsResp.data)
            
            // Step 3: Filter out the inviter and existing members
            let filteredFriends = allFriends.filter { friend in
                !partyMemberIds.contains(friend.user_id) && friend.user_id != inviterUserId
            }
            
            await MainActor.run {
                self.friends = filteredFriends
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load friends: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func sendInvites() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            let invites = selectedFriendIds.map { friendId in
                PartyInvite(
                    party_id: partyId,
                    inviter_user_id: inviterUserId,
                    invitee_user_id: friendId,
                    status: "pending"
                )
            }
            _ = try await supabaseClient
                .from("Party Invites")
                .insert(invites)
                .execute()
            await MainActor.run {
                self.successMessage = "Invites sent!"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to send invites: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
} 


