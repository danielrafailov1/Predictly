//
//  LeaderBoardView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-16.
//

import Foundation
import SwiftUI
import Supabase

struct LeaderBoardView: View {
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var leaderboardData: [LeaderboardEntry] = []
    @State private var selectedScope: LeaderboardScope = .friends
    @State private var currentUserId: String = ""
    
    @Environment(\.supabaseClient) private var supabaseClient
    @EnvironmentObject var sessionManager: SessionManager
    
    enum LeaderboardScope: String, CaseIterable {
        case friends = "Friends"
        case global = "Global"
    }
    
    // Future enhancement: Bet type categorization
    enum BetType: String, CaseIterable {
        case all = "All"
        case sports = "Sports"
        case custom = "Custom"
        case challenge = "Challenge"
    }
    
    struct LeaderboardEntry: Identifiable, Codable {
        let id = UUID()
        let user_id: String
        let username: String
        let wins: Int
        let rank: Int
        let isCurrentUser: Bool
        let betCount: Int // Track number of bets made
        
        init(user_id: String, username: String, wins: Int, rank: Int = 0, isCurrentUser: Bool = false, betCount: Int = 0) {
            self.user_id = user_id
            self.username = username
            self.wins = wins
            self.rank = rank
            self.isCurrentUser = isCurrentUser
            self.betCount = betCount
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Leaderboard")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(getSubtitleText())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // Scope Selector
                    HStack(spacing: 0) {
                        ForEach(LeaderboardScope.allCases, id: \.self) { scope in
                            Button(action: {
                                selectedScope = scope
                                Task {
                                    await fetchLeaderboardData()
                                }
                            }) {
                                Text(scope.rawValue)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(selectedScope == scope ? .white : .white.opacity(0.6))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(
                                        selectedScope == scope ?
                                        Color.blue.opacity(0.8) :
                                        Color.clear
                                    )
                            }
                        }
                    }
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task {
                                await fetchLeaderboardData()
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    Spacer()
                } else if leaderboardData.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("No rankings yet")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(getEmptyStateText())
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    // Leaderboard Content
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(leaderboardData.enumerated()), id: \.element.id) { index, entry in
                                LeaderboardRow(
                                    entry: entry,
                                    position: index + 1
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 100) // Account for tab bar
                    }
                }
            }
        }
        .onAppear {
            Task {
                if let userEmail = sessionManager.userEmail {
                    profileImage = await fetchProfileImage(for: userEmail, supabaseClient: supabaseClient)
                    await getCurrentUserId()
                    await fetchLeaderboardData()
                }
            }
        }
    }
    
    private func getSubtitleText() -> String {
        switch selectedScope {
        case .friends:
            return "Friends with 2+ challenges compete"
        case .global:
            return "Global rankings (3+ challenges required)"
        }
    }
    
    private func getEmptyStateText() -> String {
        switch selectedScope {
        case .friends:
            return "Add friends and make at least 2 bets each to see rankings"
        case .global:
            return "Make at least 3 challenges to join the global competition"
        }
    }
    
    private func getCurrentUserId() async {
        guard let userEmail = sessionManager.userEmail else { return }
        
        do {
            let response = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: userEmail)
                .limit(1)
                .execute()
            
            struct UserIdResult: Codable {
                let user_id: String
            }
            
            let results = try JSONDecoder().decode([UserIdResult].self, from: response.data)
            if let result = results.first {
                await MainActor.run {
                    self.currentUserId = result.user_id
                }
            }
        } catch {
            print("❌ Error fetching current user ID: \(error)")
        }
    }
    
    private func fetchLeaderboardData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            var leaderboardEntries: [LeaderboardEntry] = []
            
            if selectedScope == .friends {
                // Fetch friends leaderboard (minimum 2 bets required)
                leaderboardEntries = try await fetchFriendsLeaderboard()
            } else {
                // Fetch global leaderboard (minimum 3 bets required)
                leaderboardEntries = try await fetchGlobalLeaderboard()
            }
            
            // Sort the leaderboard
            let sortedEntries = sortLeaderboard(leaderboardEntries)
            
            await MainActor.run {
                self.leaderboardData = sortedEntries
                self.isLoading = false
            }
            
        } catch {
            print("❌ Error fetching leaderboard: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func fetchUserBetCounts(for userIds: [String]) async throws -> [String: Int] {
        guard !userIds.isEmpty else { return [:] }
        
        // Convert String userIds to UUID format for querying
        let uuidUserIds = userIds.compactMap { UUID(uuidString: $0) }
        
        // Fetch bet counts from partybets table
        let partyBetsResponse = try await supabaseClient
            .from("partybets")
            .select("user_id")
            .in("user_id", values: uuidUserIds)
            .execute()
        
        // Also fetch from User Bets table (note: user_id is text type here)
        let userBetsResponse = try await supabaseClient
            .from("User Bets")
            .select("user_id")
            .in("user_id", values: userIds)
            .execute()
        
        struct PartyBetResult: Codable {
            let user_id: UUID
        }
        
        struct UserBetResult: Codable {
            let user_id: String
        }
        
        let partyBets = try JSONDecoder().decode([PartyBetResult].self, from: partyBetsResponse.data)
        let userBets = try JSONDecoder().decode([UserBetResult].self, from: userBetsResponse.data)
        
        // Count bets for each user
        var betCounts: [String: Int] = [:]
        
        // Count bets from partybets table
        for bet in partyBets {
            let userIdString = bet.user_id.uuidString
            betCounts[userIdString, default: 0] += 1
        }
        
        // Count bets from User Bets table
        for bet in userBets {
            betCounts[bet.user_id, default: 0] += 1
        }
        
        print("🔍 Bet counts calculated: \(betCounts)")
        return betCounts
    }
    
    private func fetchFriendsLeaderboard() async throws -> [LeaderboardEntry] {
        guard !currentUserId.isEmpty else {
            throw NSError(domain: "LeaderboardError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Current user ID not found"])
        }
        
        print("🔍 Fetching friends for user_id: \(currentUserId)")
        
        // First, get the current user's friends where status is "accepted"
        let friendsResponse = try await supabaseClient
            .from("Friends")
            .select("friend_id")
            .eq("user_id", value: currentUserId)
            .eq("status", value: "accepted")
            .execute()
        
        print("🔍 Friends response (current user as user_id): \(String(data: friendsResponse.data, encoding: .utf8) ?? "nil")")
        
        struct FriendResult: Codable {
            let friend_id: String
        }
        
        let friendResults = try JSONDecoder().decode([FriendResult].self, from: friendsResponse.data)
        let friendIds = friendResults.map { $0.friend_id }
        
        print("🔍 Friend IDs found (current user as user_id): \(friendIds)")
        
        // Second, do reverse check - get users who have current user as their friend with "accepted" status
        let reverseFriendsResponse = try await supabaseClient
            .from("Friends")
            .select("user_id")
            .eq("friend_id", value: currentUserId)
            .eq("status", value: "accepted")
            .execute()
        
        print("🔍 Reverse friends response (current user as friend_id): \(String(data: reverseFriendsResponse.data, encoding: .utf8) ?? "nil")")
        
        struct ReverseFriendResult: Codable {
            let user_id: String
        }
        
        let reverseFriendResults = try JSONDecoder().decode([ReverseFriendResult].self, from: reverseFriendsResponse.data)
        let reverseFriendIds = reverseFriendResults.map { $0.user_id }
        
        print("🔍 Reverse friend IDs found (current user as friend_id): \(reverseFriendIds)")
        
        // Combine both friend lists and remove duplicates
        var allFriendIds = Set(friendIds)
        allFriendIds.formUnion(reverseFriendIds)
        let uniqueFriendIds = Array(allFriendIds)
        
        print("🔍 Combined unique friend IDs: \(uniqueFriendIds)")
        
        // Include current user in the list
        var allUserIds = uniqueFriendIds
        allUserIds.append(currentUserId)
        
        print("🔍 All user IDs (friends + current): \(allUserIds)")
        
        guard !allUserIds.isEmpty else {
            return []
        }
        
        // Fetch bet counts for all users
        let betCounts = try await fetchUserBetCounts(for: allUserIds)
        print("🔍 Friends bet counts: \(betCounts)")
        
        // Filter users with minimum 2 bets
        let qualifiedUserIds = allUserIds.filter { userId in
            let betCount = betCounts[userId] ?? 0
            return betCount >= 2
        }
        
        print("🔍 Qualified friends (2+ bets): \(qualifiedUserIds)")
        
        guard !qualifiedUserIds.isEmpty else {
            return []
        }
        
        // Fetch user data for qualified users
        let usersResponse = try await supabaseClient
            .from("Login Information")
            .select("user_id, wins")
            .in("user_id", values: qualifiedUserIds)
            .execute()
        
        print("🔍 Friends Login Information response: \(String(data: usersResponse.data, encoding: .utf8) ?? "nil")")
        
        struct UserWinsResult: Codable {
            let user_id: String
            let wins: Int?
        }
        
        let userWinsResults = try JSONDecoder().decode([UserWinsResult].self, from: usersResponse.data)
        
        print("🔍 Friends user wins results: \(userWinsResults)")
        
        // Fetch usernames
        let usernamesResponse = try await supabaseClient
            .from("Username")
            .select("user_id, username")
            .in("user_id", values: qualifiedUserIds)
            .execute()
        
        print("🔍 Friends Username response: \(String(data: usernamesResponse.data, encoding: .utf8) ?? "nil")")
        
        struct UsernameResult: Codable {
            let user_id: String
            let username: String
        }
        
        let usernameResults = try JSONDecoder().decode([UsernameResult].self, from: usernamesResponse.data)
        let userIdToUsername = Dictionary(uniqueKeysWithValues: usernameResults.map { ($0.user_id, $0.username) })
        
        print("🔍 Friends username mapping: \(userIdToUsername)")
        
        // Combine data
        var entries: [LeaderboardEntry] = []
        for userWins in userWinsResults {
            let username = userIdToUsername[userWins.user_id] ?? "Unknown User"
            let wins = userWins.wins ?? 0
            let isCurrentUser = userWins.user_id == currentUserId
            let betCount = betCounts[userWins.user_id] ?? 0
            
            print("🔍 Friends entry: \(username) - \(wins) wins, \(betCount) bets, isCurrentUser: \(isCurrentUser)")
            
            entries.append(LeaderboardEntry(
                user_id: userWins.user_id,
                username: username,
                wins: wins,
                isCurrentUser: isCurrentUser,
                betCount: betCount
            ))
        }
        
        print("🔍 Total friends entries created: \(entries.count)")
        return entries
    }
    
    private func fetchGlobalLeaderboard() async throws -> [LeaderboardEntry] {
        print("🔍 Fetching global leaderboard")
        
        // Fetch all users
        let usersResponse = try await supabaseClient
            .from("Login Information")
            .select("user_id, wins")
            .execute()
        
        print("🔍 Global Login Information response: \(String(data: usersResponse.data, encoding: .utf8) ?? "nil")")
        
        struct UserWinsResult: Codable {
            let user_id: String
            let wins: Int?
        }
        
        let userWinsResults = try JSONDecoder().decode([UserWinsResult].self, from: usersResponse.data)
        let userIds = userWinsResults.map { $0.user_id }
        
        print("🔍 Found \(userIds.count) total users")
        
        // Fetch bet counts for all users
        let betCounts = try await fetchUserBetCounts(for: userIds)
        print("🔍 Global bet counts: \(betCounts)")
        
        // Filter users with minimum 3 bets
        let qualifiedUserIds = userIds.filter { userId in
            let betCount = betCounts[userId] ?? 0
            return betCount >= 3
        }
        
        print("🔍 Qualified global users (3+ bets): \(qualifiedUserIds)")
        
        guard !qualifiedUserIds.isEmpty else {
            return []
        }
        
        // Filter user wins results to only include qualified users
        let qualifiedUserWinsResults = userWinsResults.filter { qualifiedUserIds.contains($0.user_id) }
        
        // Fetch usernames for qualified users
        let usernamesResponse = try await supabaseClient
            .from("Username")
            .select("user_id, username")
            .in("user_id", values: qualifiedUserIds)
            .execute()
        
        print("🔍 Global Username response: \(String(data: usernamesResponse.data, encoding: .utf8) ?? "nil")")
        
        struct UsernameResult: Codable {
            let user_id: String
            let username: String
        }
        
        let usernameResults = try JSONDecoder().decode([UsernameResult].self, from: usernamesResponse.data)
        let userIdToUsername = Dictionary(uniqueKeysWithValues: usernameResults.map { ($0.user_id, $0.username) })
        
        print("🔍 Global username mapping: \(userIdToUsername)")
        
        // Combine data - only qualified users
        var entries: [LeaderboardEntry] = []
        for userWins in qualifiedUserWinsResults {
            let username = userIdToUsername[userWins.user_id] ?? "Unknown User"
            let wins = userWins.wins ?? 0
            let isCurrentUser = userWins.user_id == currentUserId
            let betCount = betCounts[userWins.user_id] ?? 0
            
            print("🔍 Global entry: \(username) - \(wins) wins, \(betCount) bets, isCurrentUser: \(isCurrentUser)")
            
            entries.append(LeaderboardEntry(
                user_id: userWins.user_id,
                username: username,
                wins: wins,
                isCurrentUser: isCurrentUser,
                betCount: betCount
            ))
        }
        
        print("🔍 Total global entries created: \(entries.count)")
        return entries
    }
    
    private func sortLeaderboard(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        return entries.sorted { entry1, entry2 in
            // First, sort by wins (descending)
            if entry1.wins != entry2.wins {
                return entry1.wins > entry2.wins
            }
            
            // If wins are tied, sort by bet count (descending) - more active users ranked higher
            if entry1.betCount != entry2.betCount {
                return entry1.betCount > entry2.betCount
            }
            
            // If wins and bet counts are tied, sort alphabetically by username
            if entry1.username != entry2.username {
                return entry1.username < entry2.username
            }
            
            // If usernames are also tied, sort by user_id (unique identifier)
            return entry1.user_id < entry2.user_id
        }
    }
}

struct LeaderboardRow: View {
    let entry: LeaderBoardView.LeaderboardEntry
    let position: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Position and Medal
            HStack(spacing: 8) {
                if position <= 3 {
                    medalIcon(for: position)
                        .font(.system(size: 24))
                } else {
                    Text("\(position)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32)
                }
            }
            
            // Username with bet count indicator
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.system(size: 18, weight: entry.isCurrentUser ? .bold : .semibold))
                    .foregroundColor(entry.isCurrentUser ? .yellow : .white)
                    .lineLimit(1)
                
                Text("\(entry.betCount) challenges")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Wins count
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow.opacity(0.8))
                
                Text("\(entry.wins)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(entry.isCurrentUser ?
                      Color.yellow.opacity(0.15) :
                      Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(entry.isCurrentUser ?
                                Color.yellow.opacity(0.3) :
                                Color.clear, lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private func medalIcon(for position: Int) -> some View {
        switch position {
        case 1:
            Image(systemName: "medal.fill")
                .foregroundColor(.yellow)
        case 2:
            Image(systemName: "medal.fill")
                .foregroundColor(.gray)
        case 3:
            Image(systemName: "medal.fill")
                .foregroundColor(Color(red: 0.8, green: 0.5, blue: 0.2)) // Bronze color
        default:
            EmptyView()
        }
    }
}

#Preview {
    LeaderBoardView()
        .environment(\.supabaseClient, .development)
}
