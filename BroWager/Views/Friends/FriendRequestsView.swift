import SwiftUI
import Supabase

struct FriendRequestsView: View {
    let email: String
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var userId: String = ""
    @State private var requests: [FriendRequestRow] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Friend Requests")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 16)
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let error = errorMessage {
                    Text(error).foregroundColor(.red)
                } else if requests.isEmpty {
                    Text("No pending requests.").foregroundColor(.white.opacity(0.7))
                } else {
                    List(requests, id: \.id) { req in
                        HStack {
                            Text(req.username).foregroundColor(.white)
                            Spacer()
                            Button("Accept") { Task { await accept(req) } }
                                .foregroundColor(.green)
                                .buttonStyle(PlainButtonStyle())
                            Button("Reject") { Task { await reject(req) } }
                                .foregroundColor(.red)
                                .buttonStyle(PlainButtonStyle())
                        }
                        .listRowBackground(Color.clear)
                    }
                    .background(Color.clear)
                }
                Spacer()
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()
            )
            .navigationTitle("Requests")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } } }
        }
        .task { await loadRequests() }
    }
    
    private func loadRequests() async {
        isLoading = true
        do {
            let userResp = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .limit(1)
                .execute()
            struct UserIdRow: Decodable { let user_id: String }
            let userIdRows = try JSONDecoder().decode([UserIdRow].self, from: userResp.data)
            guard let userIdRow = userIdRows.first else {
                await MainActor.run {
                    self.errorMessage = "User not found"
                    self.isLoading = false
                }
                return
            }
            userId = userIdRow.user_id
            // Get pending requests where friend_id == userId and status == "pending"
            let reqResp = try await supabaseClient
                .from("Friends")
                .select("id, user_id, status, created_at")
                .eq("friend_id", value: userId)
                .eq("status", value: "pending")
                .execute()
            let arr = try JSONDecoder().decode([FriendRequestRowRaw].self, from: reqResp.data)
            // Fetch usernames for each sender
            var localRequests: [FriendRequestRow] = []
            for req in arr {
                let userResp = try await supabaseClient
                    .from("Username")
                    .select("username")
                    .eq("user_id", value: req.user_id)
                    .limit(1)
                    .execute()
                struct UsernameRow: Decodable { let username: String }
                let usernameRows = try JSONDecoder().decode([UsernameRow].self, from: userResp.data)
                let username = usernameRows.first?.username ?? req.user_id
                localRequests.append(FriendRequestRow(id: req.id, user_id: req.user_id, username: username))
            }
            let requestsCopy = localRequests
            await MainActor.run {
                self.requests = requestsCopy
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load requests: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func accept(_ req: FriendRequestRow) async {
        print("[FriendRequestsView] Accept called for id: \(req.id)")
        isLoading = true
        do {
            let response = try await supabaseClient
                .from("Friends")
                .update(["status": "accepted"])
                .eq("id", value: Int(req.id))
                .execute()
            print("[FriendRequestsView] Update response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            await loadRequests()
        } catch {
            print("[FriendRequestsView] Update error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to accept: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    private func reject(_ req: FriendRequestRow) async {
        print("[FriendRequestsView] Reject called for id: \(req.id)")
        isLoading = true
        do {
            _ = try await supabaseClient
                .from("Friends")
                .delete()
                .eq("id", value: Int(req.id))
                .execute()
            await loadRequests()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to reject: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

struct FriendRequestRowRaw: Decodable {
    let id: Int64
    let user_id: String
    let status: String
    let created_at: String
}
struct FriendRequestRow: Identifiable {
    let id: Int64
    let user_id: String
    let username: String
} 