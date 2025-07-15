import SwiftUI
import Supabase

struct FriendsView: View {
    let email: String
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var userId: String = ""
    @State private var friends: [FriendUser] = []
    @State private var pendingRequests: [FriendRequest] = []
    @State private var isLoading = true
    @State private var showAddFriend = false
    @State private var showRequests = false
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @State private var inviteTarget: FriendUser? = nil
    @State private var showPartyPicker = false
    @State private var userParties: [Party] = []
    @State private var isLoadingParties = false
    @State private var inviteStatus: String? = nil
    @State private var activeChatFriend: FriendUser? = nil
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Friends")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 16)
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    if friends.isEmpty {
                        Text("No friends yet.")
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(friends, id: \.user_id) { friend in
                                    HStack {
                                        AsyncProfileImage(userId: friend.user_id, supabaseClient: supabaseClient)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                        Text("\(friend.username)#\(friend.identifier)")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Button(action: {
                                            inviteTarget = friend
                                            Task { await loadUserParties() }
                                            showPartyPicker = true
                                        }) {
                                            Image(systemName: "person.crop.circle.badge.plus")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 22))
                                        }
                                        .buttonStyle(.plain)
                                        Button(action: {
                                            activeChatFriend = friend
                                        }) {
                                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 22))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(10)
                                }
                            }.padding(.horizontal)
                        }
                    }
                }
                Spacer()
                HStack {
                    Button(action: { showAddFriend = true }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Add Friend")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    Button(action: { showRequests = true }) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Friend Requests")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                
            }
            .sheet(isPresented: $showAddFriend, onDismiss: { Task { await loadFriends() } }) {
                AddFriendView(email: email)
                    .environment(\.supabaseClient, supabaseClient)
            }
            .sheet(isPresented: $showRequests, onDismiss: { Task { await loadFriends() } }) {
                FriendRequestsView(email: email)
                    .environment(\.supabaseClient, supabaseClient)
            }
            .sheet(isPresented: $showPartyPicker) {
                VStack(spacing: 20) {
                    Text("Invite \(inviteTarget != nil ? "\(inviteTarget!.username)#\(inviteTarget!.identifier)" : "Friend") to a Party")
                        .font(.title2)
                        .padding(.top, 24)
                    if isLoadingParties {
                        ProgressView()
                    } else if userParties.isEmpty {
                        Text("You have no active parties to invite to.")
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(userParties, id: \.id) { party in
                                    Button(action: {
                                        Task { await inviteFriendToParty(friend: inviteTarget!, party: party) }
                                    }) {
                                        HStack {
                                            Text(party.party_name ?? "Unnamed Party")
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "arrowshape.turn.up.right.fill")
                                                .foregroundColor(.blue)
                                        }
                                        .padding()
                                        .background(Color.blue.opacity(0.08))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    if let status = inviteStatus {
                        Text(status)
                            .foregroundColor(.green)
                            .padding(.top, 8)
                    }
                    Spacer()
                    Button("Cancel") { showPartyPicker = false }
                        .padding(.bottom, 24)
                }
                .onDisappear { inviteStatus = nil }
                .padding()
                .background(Color(.systemBackground))
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: .constant(NavigationPath()), email: email)
        }
        .sheet(item: $activeChatFriend) { friend in
            DirectMessageView(friend: friend, currentUserId: userId)
        }
        .task { 
            await loadFriends()
            profileImage = await fetchProfileImage(for: email, supabaseClient: supabaseClient)
        }
    }
    
    private func loadFriends() async {
        isLoading = true
        do {
            // Get user_id
            let userResp = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .limit(1)
                .execute()
            struct UserIdRow: Decodable { let user_id: String }
            let userIdRows = try JSONDecoder().decode([UserIdRow].self, from: userResp.data)
            guard let userIdRow = userIdRows.first else {
                print("[FriendsView] User not found for email: \(email)")
                await MainActor.run { self.isLoading = false }
                return
            }
            userId = userIdRow.user_id
            // Get accepted friends
            let friendsResp = try await supabaseClient
                .rpc("get_friends", params: ["uid": userId])
                .execute()
            let friendsArr = try JSONDecoder().decode([FriendUser].self, from: friendsResp.data)
            print("[FriendsView] Friends fetched: \(friendsArr)")
            await MainActor.run {
                self.friends = friendsArr
                self.isLoading = false
            }
        } catch {
            print("[FriendsView] Error loading friends: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
    
    private func loadUserParties() async {
        isLoadingParties = true
        do {
            // Get user_id if not already loaded
            if userId.isEmpty {
                let userResp = try await supabaseClient
                    .from("Login Information")
                    .select("user_id")
                    .eq("email", value: email)
                    .limit(1)
                    .execute()
                struct UserIdRow: Decodable { let user_id: String }
                let userIdRows = try JSONDecoder().decode([UserIdRow].self, from: userResp.data)
                guard let userIdRow = userIdRows.first else { isLoadingParties = false; return }
                userId = userIdRow.user_id
            }
            // Fetch parties where user is a member and not expired/deleted
            let partiesResp = try await supabaseClient
                .rpc("get_user_parties", params: ["uid": userId])
                .execute()
            let allParties = try JSONDecoder().decode([Party].self, from: partiesResp.data)
            // Filter to only active/joinable parties
            userParties = allParties.filter { ($0.status ?? "active") != "expired" && ($0.status ?? "active") != "deleted" }
        } catch {
            print("[FriendsView] Error loading user parties: \(error)")
            userParties = []
        }
        isLoadingParties = false
    }
    
    private func inviteFriendToParty(friend: FriendUser, party: Party) async {
        do {
            let invite = PartyInvite(
                party_id: party.id,
                inviter_user_id: userId,
                invitee_user_id: friend.user_id,
                status: "pending"
            )
            _ = try await supabaseClient
                .from("Party Invites")
                .insert(invite)
                .execute()
            await MainActor.run {
                inviteStatus = "Invite sent to \(friend.username)!"
            }
        } catch {
            print("[FriendsView] Error inviting friend: \(error)")
            await MainActor.run {
                inviteStatus = "Failed to send invite."
            }
        }
    }
}

struct FriendUser: Decodable, Identifiable {
    let user_id: String
    let username: String
    let identifier: String
    var id: String { user_id }
}

struct FriendRequest: Decodable {
    let id: Int64
    let user_id: String
    let friend_id: String
    let status: String
    let created_at: String
}

struct AsyncProfileImage: View {
    let userId: String
    let supabaseClient: SupabaseClient
    @State private var image: Image? = nil
    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundColor(.blue)
            }
        }
        .onAppear {
            Task {
                image = await fetchProfileImage(forUserId: userId, supabaseClient: supabaseClient)
            }
        }
    }
} 
