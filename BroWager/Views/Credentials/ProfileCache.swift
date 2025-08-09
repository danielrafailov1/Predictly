//
//  ProfileCache.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-08-08.
//
import Foundation
import SwiftUI

// Cache model for profile data
struct CachedProfile {
    let userId: String
    let username: String
    let identifier: String
    let email: String
    let profileImage: UIImage?
    let profileImageSwiftUI: Image?
    let authProvider: String
    let friendsWithImages: [FriendWithImage]
    let timestamp: Date
    
    // Check if cache is still valid (5 minutes)
    var isValid: Bool {
        Date().timeIntervalSince(timestamp) < 300
    }
}

class ProfileCache: ObservableObject {
    static let shared = ProfileCache()
    
    @Published private var cache: [String: CachedProfile] = [:]
    
    private init() {}
    
    func getCachedProfile(for key: String) -> CachedProfile? {
        guard let cached = cache[key], cached.isValid else {
            cache.removeValue(forKey: key)
            return nil
        }
        return cached
    }
    
    func setCachedProfile(_ profile: CachedProfile, for key: String) {
        cache[key] = profile
    }
    
    func clearCache(for key: String) {
        cache.removeValue(forKey: key)
    }
    
    func clearAllCache() {
        cache.removeAll()
    }
    
    // Update specific parts of cache without full reload
    func updateProfileImage(_ image: UIImage?, swiftUIImage: Image?, for key: String) {
        guard var cached = cache[key] else { return }
        let updated = CachedProfile(
            userId: cached.userId,
            username: cached.username,
            identifier: cached.identifier,
            email: cached.email,
            profileImage: image,
            profileImageSwiftUI: swiftUIImage,
            authProvider: cached.authProvider,
            friendsWithImages: cached.friendsWithImages,
            timestamp: Date()
        )
        cache[key] = updated
    }
    
    func updateUsername(_ username: String, for key: String) {
        guard var cached = cache[key] else { return }
        let updated = CachedProfile(
            userId: cached.userId,
            username: username,
            identifier: cached.identifier,
            email: cached.email,
            profileImage: cached.profileImage,
            profileImageSwiftUI: cached.profileImageSwiftUI,
            authProvider: cached.authProvider,
            friendsWithImages: cached.friendsWithImages,
            timestamp: Date()
        )
        cache[key] = updated
    }
    
    func updateEmail(_ email: String, for key: String) {
        guard var cached = cache[key] else { return }
        let updated = CachedProfile(
            userId: cached.userId,
            username: cached.username,
            identifier: cached.identifier,
            email: email,
            profileImage: cached.profileImage,
            profileImageSwiftUI: cached.profileImageSwiftUI,
            authProvider: cached.authProvider,
            friendsWithImages: cached.friendsWithImages,
            timestamp: Date()
        )
        cache[key] = updated
    }
}
