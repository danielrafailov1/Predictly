import SwiftUI
import Supabase

class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String? = nil
    @Published var needsUsername: Bool = false {
        didSet {
            print("[SessionManager] needsUsername set to \(needsUsername)")
        }
    }
    @Published var newUserId: String? = nil

    private var supabaseClient: SupabaseClient

    init(supabaseClient: SupabaseClient) {
        self.supabaseClient = supabaseClient
        Task {
            await self.refreshSession()
        }
    }
    
    func clearProfileCache() {
        ProfileCache.shared.clearAllCache()
    }

    func refreshSession() async {
        print("refreshSession: called on instance: \(Unmanaged.passUnretained(self).toOpaque())")
        do {
            let session = try await supabaseClient.auth.session
            let user = session.user
            print("refreshSession: Got session for user \(user.email ?? "nil")")
            // Ensure Login Information row exists for this user
            do {
                let loginInfoResp = try await supabaseClient
                    .from("Login Information")
                    .select("user_id")
                    .eq("user_id", value: user.id.uuidString)
                    .limit(1)
                    .execute()
                struct LoginInfoRow: Decodable { let user_id: String }
                let loginInfoRows = try JSONDecoder().decode([LoginInfoRow].self, from: loginInfoResp.data)
                if loginInfoRows.isEmpty {
                    let timestamp = ISO8601DateFormatter().string(from: Date())
                    let newLoginInfo = LoginInfo(
                        created_at: timestamp,
                        email: user.email ?? "",
                        user_id: user.id.uuidString,
                        music_on: false,
                        wins: 0
                    )
                    print("[SessionManager] Inserting Login Information row for user_id: \(user.id.uuidString)")
                    _ = try await supabaseClient
                        .from("Login Information")
                        .insert(newLoginInfo)
                        .execute()
                    print("[SessionManager] Inserted Login Information row for user_id: \(user.id.uuidString)")
                } else {
                    print("[SessionManager] Login Information row already exists for user_id: \(user.id.uuidString)")
                }
            } catch {
                print("[SessionManager] Error ensuring Login Information row: \(error)")
            }
            // Check if user has a username
            do {
                let usernameResp = try await supabaseClient
                    .from("Username")
                    .select("username")
                    .eq("user_id", value: user.id.uuidString)
                    .limit(1)
                    .execute()
                struct UsernameRow: Decodable { let username: String }
                let usernameRows = try JSONDecoder().decode([UsernameRow].self, from: usernameResp.data)
                print("[SessionManager] usernameRows for user_id \(user.id.uuidString): \(usernameRows)")
                await MainActor.run {
                    if usernameRows.isEmpty {
                        print("[SessionManager] No username found for user_id: \(user.id.uuidString)")
                        self.needsUsername = true
                        self.newUserId = user.id.uuidString
                    } else {
                        print("[SessionManager] Username exists for user_id: \(user.id.uuidString)")
                        self.needsUsername = false
                        self.newUserId = nil
                    }
                }
            } catch {
                print("[SessionManager] Error checking username: \(error)")
            }
            await MainActor.run {
                print("refreshSession: MainActor.run setting isLoggedIn = true, userEmail = \(user.email ?? "nil")")
                self.isLoggedIn = true
                self.userEmail = user.email
            }
        } catch {
            print("refreshSession: No session or error: \(error)")
            await MainActor.run {
                print("refreshSession: MainActor.run setting isLoggedIn = false, userEmail = nil")
                self.isLoggedIn = false
                self.userEmail = nil
                self.needsUsername = false
                self.newUserId = nil
            }
        }
    }

    func signOut() async {
        do {
            try await supabaseClient.auth.signOut()
            clearProfileCache() // Add this line
            await MainActor.run {
                self.isLoggedIn = false
                self.userEmail = nil
            }
        } catch {
            print("Sign out failed: \(error)")
        }
    }
}
