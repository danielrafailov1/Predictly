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
                .ignoresSafeArea(.all) // Changed to .all
                
                VStack(spacing: 16) {
                    TextField("Search by username", text: $searchText)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white) // Force white text
                        .colorScheme(.dark) // Force dark color scheme
                        .onSubmit { Task { await search() } }
                        
                    Button("Search") {
                        Task { await search() }
                    }
                    .foregroundColor(.white) // Force white
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                    .font(.system(size: 16, weight: .semibold))
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .colorScheme(.dark) // Force dark
                    } else if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.body)
                    } else {
                        List(results, id: \.user_id) { user in
                            HStack {
                                Text("\(user.username)#\(user.identifier)")
                                    .foregroundColor(.white) // Force white
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
                        .listStyle(PlainListStyle()) // Add this
                        .scrollContentBackground(.hidden) // Add this for iOS 16+
                        .background(Color.clear)
                        .colorScheme(.dark) // Force dark color scheme
                    }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Friend")
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
        .task { await getUserId() }
    }
    
    // Rest of your functions remain the same...
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
            } else {
                errorMessage = "User not found"
            }
        } catch {
            errorMessage = "Failed to get user id"
        }
    }
    
    private func search() async {
        isLoading = true
        errorMessage = nil
        do {
            let resp = try await supabaseClient
                .from("Username")
                .select("user_id, username, identifier")
                .ilike("username", pattern: "%\(searchText)%")
                .neq("user_id", value: userId)
                .execute()
            print("[AddFriendView] Raw search response: \(String(data: resp.data, encoding: .utf8) ?? "nil")")
            do {
                let arr = try JSONDecoder().decode([UserSearchResult].self, from: resp.data)
                await MainActor.run { self.results = arr; self.isLoading = false }
            } catch {
                await MainActor.run { self.results = []; self.isLoading = false }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Search failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func sendRequest(to friendId: String) async {
        isLoading = true
        errorMessage = nil
        do {
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
            print("[AddFriendView] Insert error: \(error)")
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
