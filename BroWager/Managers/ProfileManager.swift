//
//  ProfileManager.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-26.
//

import Foundation
import Supabase
import UIKit

struct Profile: Codable {
    let profile_image_url: String?
}

struct ProfileImageRow: Codable {
    let created_at: String
    let user_id: String
    let profile_image_url: String
}

class ProfileManager {
    
    private let supabaseClient: SupabaseClient
    
    init(supabaseClient: SupabaseClient) {
        self.supabaseClient = supabaseClient
    }

    func uploadProfileImage(for userId: String, image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.badURL)
        }

        let fileName = "\(userId).jpg"
        let bucket = supabaseClient.storage.from("profile-images")

        try await bucket.upload(fileName, data: imageData)

        let url = try bucket.getPublicURL(path: fileName)
        return url.absoluteString
    }

    func saveProfileImageURL(for userId: String, url: String) async throws {
        try await supabaseClient.database
            .from("profiles")
            .update(["profile_image_url": url])
            .eq("id", value: userId)
            .execute()
    }

    func uploadProfileImageAndSaveURL(for userId: String, image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.badURL)
        }
        let fileName = "\(userId).jpg"
        let bucket = supabaseClient.storage.from("profile-images")
        // Upload image to storage
        try await bucket.upload(fileName, data: imageData, options: FileOptions(upsert: true))
        // Get public URL
        let url = try bucket.getPublicURL(path: fileName).absoluteString
        // Save URL to Profile Images table
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let profileImageRow = ProfileImageRow(
            created_at: timestamp,
            user_id: userId,
            profile_image_url: url
        )
        _ = try await supabaseClient
            .from("Profile Images")
            .upsert(profileImageRow, onConflict: "user_id")
            .execute()
        return url
    }

    func fetchProfileImageURL(for userId: String) async throws -> String? {
        let response = try await supabaseClient
            .from("Profile Images")
            .select("profile_image_url, created_at")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(5)
            .execute()
        let data = response.data
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            print("[ProfileManager] Profile Images rows for userId: \(userId):")
            for row in jsonArray {
                let createdAt = row["created_at"] ?? "nil"
                let url = row["profile_image_url"] ?? "nil"
                print("  - created_at: \(createdAt), url: \(url)")
            }
            if let first = jsonArray.first, let url = first["profile_image_url"] as? String {
                return url
            }
        }
        return nil
    }

    func loadProfileImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Failed to load image: \(error.localizedDescription)")
            return nil
        }
    }
}
