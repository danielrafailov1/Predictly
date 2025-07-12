import SwiftUI
import Supabase

func fetchUserId(for email: String, supabaseClient: SupabaseClient) async -> String? {
    struct UserIdRow: Decodable { let user_id: String }
    do {
        let response = try await supabaseClient
            .from("Login Information")
            .select("user_id")
            .eq("email", value: email)
            .limit(1)
            .execute()
        let userIdRows = try JSONDecoder().decode([UserIdRow].self, from: response.data)
        return userIdRows.first?.user_id
    } catch {
        print("Failed to fetch user_id for email \(email): \(error)")
        return nil
    }
}

func fetchProfileImage(for email: String, supabaseClient: SupabaseClient) async -> Image? {
    guard let userId = await fetchUserId(for: email, supabaseClient: supabaseClient) else { return nil }
    let manager = ProfileManager(supabaseClient: supabaseClient)
    do {
        if let urlString = try await manager.fetchProfileImageURL(for: userId),
           let url = URL(string: urlString + "?t=\(Int(Date().timeIntervalSince1970))") {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            }
        }
    } catch {
        print("Failed to fetch profile image for user_id \(userId): \(error)")
    }
    return nil
}

func fetchProfileImage(forUserId userId: String, supabaseClient: SupabaseClient) async -> Image? {
    let manager = ProfileManager(supabaseClient: supabaseClient)
    do {
        if let urlString = try await manager.fetchProfileImageURL(for: userId),
           let url = URL(string: urlString + "?t=\(Int(Date().timeIntervalSince1970))") {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            }
        }
    } catch {
        print("Failed to fetch profile image for user_id \(userId): \(error)")
    }
    return nil
} 