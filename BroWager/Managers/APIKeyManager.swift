//
//  APIKeyManager.swift
//  BroWager
//
//  Created by Daniel Rafailov on August 2nd, 2025
//

import Foundation

public class APIKeyManager {
    public static let shared = APIKeyManager()
    
    private var apiKeys: [String] = []
    private var currentKeyIndex = 0
    private var keyUsageCounts: [String: Int] = [:]
    private var blockedKeys: Set<String> = []
    private let maxRequestsPerKey = 1000 // Adjust based on your API limits
    
    private init() {
        loadAPIKeys()
    }
    
    private func loadAPIKeys() {
        // Load from Info.plist
        if let keys = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEYS") as? [String] {
            apiKeys = keys.filter { !$0.isEmpty }
        }
        
        // Fallback: Load individual keys if batch not available
        if apiKeys.isEmpty {
            if let singleKey = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String, !singleKey.isEmpty {
                apiKeys = [singleKey]
            }
        }
        
        // Initialize usage counts
        for key in apiKeys {
            keyUsageCounts[key] = 0
        }
        
        print("📋 Loaded \(apiKeys.count) API keys")
    }
    
    public func getCurrentAPIKey() -> String? {
        guard !apiKeys.isEmpty else {
            print("❌ No API keys available")
            return nil
        }
        
        // Find next available key
        let availableKeys = apiKeys.filter { key in
            !blockedKeys.contains(key) && (keyUsageCounts[key] ?? 0) < maxRequestsPerKey
        }
        
        guard !availableKeys.isEmpty else {
            print("❌ All API keys are exhausted or blocked")
            return nil
        }
        
        // Use round-robin selection among available keys
        currentKeyIndex = currentKeyIndex % availableKeys.count
        let selectedKey = availableKeys[currentKeyIndex]
        
        print("🔑 Using API key #\(apiKeys.firstIndex(of: selectedKey) ?? 0 + 1)")
        return selectedKey
    }
    
    public func incrementUsage(for key: String) {
        keyUsageCounts[key] = (keyUsageCounts[key] ?? 0) + 1
        
        if let usage = keyUsageCounts[key] {
            print("📊 Key usage: \(usage)/\(maxRequestsPerKey)")
            
            if usage >= maxRequestsPerKey {
                print("⚠️ Key reached usage limit, switching to next key")
                moveToNextKey()
            }
        }
    }
    
    public func blockKey(_ key: String, reason: String) {
        blockedKeys.insert(key)
        print("🚫 Blocked API key due to: \(reason)")
        moveToNextKey()
    }
    
    public func resetKeyUsage() {
        keyUsageCounts = [:]
        for key in apiKeys {
            keyUsageCounts[key] = 0
        }
        blockedKeys.removeAll()
        print("🔄 Reset all key usage counts")
    }
    
    private func moveToNextKey() {
        currentKeyIndex = (currentKeyIndex + 1) % apiKeys.count
    }
    
    public func getKeyStatus() -> [(key: String, usage: Int, blocked: Bool)] {
        return apiKeys.enumerated().map { index, key in
            let maskedKey = String(key.prefix(8)) + "..." + String(key.suffix(4))
            return (
                key: "Key #\(index + 1): \(maskedKey)",
                usage: keyUsageCounts[key] ?? 0,
                blocked: blockedKeys.contains(key)
            )
        }
    }
}
