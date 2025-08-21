import SwiftUI
import Supabase

struct AddFriendView: View {
    let email: String
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var results: [UserSearchResult] = []
    @State private var isLoading = false
    @State private var userId: String = ""
    @State private var errorMessage: String? = nil
    @State private var sentRequestTo: String? = nil
    
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
                .ignoresSafeArea(.all)
                
                VStack(spacing: 16) {
                    TextField("Search by username", text: $searchText)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .colorScheme(.dark)
                        .onSubmit {
                            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Task { await search() }
                            }
                        }
                        
                    Button("Search") {
                        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Task { await search() }
                        }
                    }
                    .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                    .cornerRadius(8)
                    .font(.system(size: 16, weight: .semibold))
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .colorScheme(.dark)
                    } else if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.body)
                    } else {
                        List(results, id: \.user_id) { user in
                            HStack {
                                Text("\(user.username)#\(user.identifier)")
                                    .foregroundColor(.white)
                                    .font(.body)
                                Spacer()
                                if sentRequestTo == user.user_id {
                                    Text("Request Sent")
                                        .foregroundColor(.green)
                                        .font(.system(size: 14, weight: .medium))
                                } else {
                                    Button("Add") {
                                        Task { await sendRequest(to: user.user_id) }
                                    }
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .colorScheme(.dark)
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
        .task { await getUserId() }
    }
    
    private func getUserId() async {
        do {
            let userResp = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .limit(1)
                .execute()
            struct UserIdRow: Decodable { let user_id: String }
            let userIdRows = try JSONDecoder().decode([UserIdRow].self, from: userResp.data)
            if let first = userIdRows.first {
                userId = first.user_id
                print("[AddFriendView] Current user ID: \(userId)")
            } else {
                errorMessage = "User not found"
            }
        } catch {
            print("[AddFriendView] getUserId error: \(error)")
            errorMessage = "Failed to get user id: \(error.localizedDescription)"
        }
    }
    
    private func search() async {
        // Trim whitespace and check if search text is valid
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else {
            await MainActor.run {
                self.errorMessage = "Please enter a username to search"
            }
            return
        }
        
        // Ensure we have a valid user ID
        guard !userId.isEmpty else {
            await MainActor.run {
                self.errorMessage = "User ID not found. Please try again."
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.results = []
        }
        
        do {
            print("[AddFriendView] Searching for: '\(trimmedSearchText)' excluding user: \(userId)")
            
            // Let's see ALL users in the database to find Test1
            let allUsersResp = try await supabaseClient
                .from("Username")
                .select("user_id, username, identifier")
                .execute() // No limit - get all users
            print("[AddFriendView] ALL users in DB: \(String(data: allUsersResp.data, encoding: .utf8) ?? "nil")")
            
            // Check if Test1 exists with exact match
            let test1Check = try await supabaseClient
                .from("Username")
                .select("user_id, username, identifier")
                .eq("username", value: "Test1")
                .execute()
            print("[AddFriendView] Test1 exact search: \(String(data: test1Check.data, encoding: .utf8) ?? "nil")")
            
            // Check if Test1 has the same user_id as current user
            if let test1Data = try? JSONDecoder().decode([UserSearchResult].self, from: test1Check.data),
               let test1User = test1Data.first {
                print("[AddFriendView] Test1 user_id: \(test1User.user_id)")
                print("[AddFriendView] Current user_id: \(userId)")
                print("[AddFriendView] Are they the same? \(test1User.user_id == userId)")
            }
            
            // Now perform the actual search
            let resp = try await supabaseClient
                .from("Username")
                .select("user_id, username, identifier")
                .ilike("username", pattern: "%\(trimmedSearchText)%")
                .neq("user_id", value: userId)
                .execute()
            
            print("[AddFriendView] Search response: \(String(data: resp.data, encoding: .utf8) ?? "nil")")
            
            let searchResults = try JSONDecoder().decode([UserSearchResult].self, from: resp.data)
            print("[AddFriendView] Found \(searchResults.count) results")
            
            await MainActor.run {
                self.results = searchResults
                self.isLoading = false
                
                if searchResults.isEmpty {
                    self.errorMessage = "No users found matching '\(trimmedSearchText)'"
                }
            }
            
        } catch {
            print("[AddFriendView] Search error: \(error)")
            await MainActor.run {
                self.errorMessage = "Search failed: \(error.localizedDescription)"
                self.isLoading = false
                self.results = []
            }
        }
    }
    
    private func sendRequest(to friendId: String) async {
        guard !userId.isEmpty else {
            await MainActor.run {
                self.errorMessage = "User ID not found"
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // Check if a friendship already exists (in either direction)
            let existingFriendship = try await supabaseClient
                .from("Friends")
                .select("id, status")
                .or("and(user_id.eq.\(userId),friend_id.eq.\(friendId)),and(user_id.eq.\(friendId),friend_id.eq.\(userId))")
                .limit(1)
                .execute()
            
            let existingFriendships = try JSONDecoder().decode([ExistingFriendship].self, from: existingFriendship.data)
            
            if !existingFriendships.isEmpty {
                await MainActor.run {
                    self.errorMessage = "Friend request already exists or you're already friends"
                    self.isLoading = false
                }
                return
            }
            
            // Create new friend request
            let newRequest = [
                "user_id": userId,
                "friend_id": friendId,
                "status": "pending",
                "created_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            let response = try await supabaseClient
                .from("Friends")
                .insert(newRequest)
                .select()
                .execute()
            
            print("[AddFriendView] Insert response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            
            await MainActor.run {
                self.sentRequestTo = friendId
                self.isLoading = false
            }
            
        } catch {
            print("[AddFriendView] Send request error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to send request: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

struct UserSearchResult: Decodable {
    let user_id: String
    let username: String
    let identifier: String
}

struct ExistingFriendship: Decodable {
    let id: Int64
    let status: String
}
