//
//  GameResultsView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-07-27.
//
import SwiftUI
import Supabase

struct GameResultsView: View {
    let partyId: Int64
    let partyName: String
    
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var winningOptions: [String] = []
    @State private var winners: [UserResult] = []
    @State private var losers: [UserResult] = []
    @State private var betPrompt: String = ""
    @State private var hasUpdatedWins = false // Track if wins have been updated
    @State private var highestScore = 0 // Track the highest score achieved
    
    // New state for user selection detail modal
    @State private var selectedUser: UserResult?
    @State private var showingUserDetail = false
    
    struct UserResult: Codable, Identifiable {
        let id = UUID()
        let user_id: String
        let username: String
        let bet_selection: [String] // This will be parsed from the text field
        let is_winner: Bool
        let score: Int // Number of correct options
        
        enum CodingKeys: String, CodingKey {
            case user_id, username, bet_selection, is_winner, score
        }
        
        // Custom initializer to handle the parsing and scoring
        init(user_id: String, username: String, bet_selection_text: String, winningOptions: [String], isWinnerFromDB: Bool? = nil) {
            self.user_id = user_id
            self.username = username
            self.bet_selection = bet_selection_text.components(separatedBy: ", ").filter { !$0.isEmpty }
            
            // Calculate score based on how many winning options they selected
            self.score = self.bet_selection.filter { selection in
                winningOptions.contains { winningOption in
                    selection.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
                    winningOption.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                }
            }.count
            
            // Use database value if provided, otherwise will be determined later based on highest score
            self.is_winner = isWinnerFromDB ?? false
        }
    }

    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else if let error = errorMessage {
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
                                await fetchGameResults()
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 12) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.yellow)
                                
                                Text("Game Results")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text(partyName)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                // Show highest score achieved
                                if highestScore > 0 {
                                    Text("Winning Score: \(highestScore)/\(winningOptions.count)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.yellow)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.yellow.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.top, 20)
                            
                            // Bet Question
                            if !betPrompt.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Bet Question:")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text(betPrompt)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            // Winning Options
                            if !winningOptions.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Correct Answer(s):")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                    
                                    ForEach(winningOptions, id: \.self) { option in
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 20))
                                            
                                            Text(option)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.green, lineWidth: 1)
                                        )
                                        .padding(.horizontal, 24)
                                    }
                                }
                            }
                            
                            // Winners Section
                            if !winners.isEmpty {
                                VStack(spacing: 16) {
                                    HStack {
                                        Image(systemName: "party.popper.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 24))
                                        Text("🎉 Winners! (Score: \(highestScore))")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.green)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 24)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(winners) { winner in
                                                WinnerCard(
                                                    userResult: winner,
                                                    onTap: {
                                                        selectedUser = winner
                                                        showingUserDetail = true
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                }
                            }
                            
                            // Losers Section
                            if !losers.isEmpty {
                                VStack(spacing: 16) {
                                    HStack {
                                        Image(systemName: "hand.wave.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 24))
                                        Text("Better Luck Next Time")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.orange)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 24)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(losers.sorted { $0.score > $1.score }) { loser in
                                                LoserCard(
                                                    userResult: loser,
                                                    onTap: {
                                                        selectedUser = loser
                                                        showingUserDetail = true
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                }
                            }
                            
                            // Play Again Button (placeholder for future feature)
                            Button(action: {
                                // Future: Navigate to create new party or similar
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                    Text("Back to Party")
                                }
                                .font(.system(size: 18, weight: .semibold))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.top, 20)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingUserDetail) {
                if let user = selectedUser {
                    UserSelectionDetailView(
                        userResult: user,
                        winningOptions: winningOptions,
                        betPrompt: betPrompt
                    )
                }
            }
        }
        .onAppear {
            Task {
                await fetchGameResults()
            }
        }
    }
    
    // Helper function to clean winning options from array format
    private func cleanWinningOptions(_ options: [String]) -> [String] {
        return options.map { option in
            // Remove quotes, brackets, and extra whitespace
            option
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
    }
    
    private func fetchGameResults() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            print("🔍 Fetching party details for party ID: \(partyId)")
            
            // Fetch party details including winning options, bet prompt, game status, and bet type
            let partyResponse = try await supabaseClient
                .from("Parties")
                .select("winning_options, bet, game_status, bet_type")
                .eq("id", value: Int(partyId))
                .limit(1)
                .execute()
            
            if let rawData = String(data: partyResponse.data, encoding: .utf8) {
                print("🔍 Raw party response: \(rawData)")
            }
            
            struct PartyResult: Codable {
                let winning_options: [String]?
                let bet: String?
                let game_status: String
                let bet_type: String
            }
            
            let partyResults: [PartyResult] = try JSONDecoder().decode([PartyResult].self, from: partyResponse.data)
            
            guard let partyResult = partyResults.first else {
                await MainActor.run {
                    self.errorMessage = "Party not found"
                    self.isLoading = false
                }
                return
            }
            
            let lowerBetType = partyResult.bet_type.lowercased()
            
            // CHECK 1: Verify the game has ended before showing results
            let gameStatus = partyResult.game_status
            if gameStatus != "ended" {
                await MainActor.run {
                    self.errorMessage = "Game results are not available yet. The host is still determining the outcome."
                    self.isLoading = false
                }
                return
            }
            
            // CHECK 2: Only enforce winning options for non-timed/contest bets
            if lowerBetType != "timed" && lowerBetType != "contest" {
                guard let rawWinningOptions = partyResult.winning_options, !rawWinningOptions.isEmpty else {
                    await MainActor.run {
                        self.errorMessage = "Game results are not available yet. No winning options have been set."
                        self.isLoading = false
                    }
                    return
                }
            }
            
            // Clean the winning options to remove any formatting artifacts
            let cleanedWinningOptions = cleanWinningOptions(partyResult.winning_options ?? [])
            
            await MainActor.run {
                self.winningOptions = cleanedWinningOptions
                self.betPrompt = partyResult.bet ?? ""
            }
            
            print("🔍 Game status: \(gameStatus)")
            print("🔍 Raw winning options: \(partyResult.winning_options ?? [])")
            print("🔍 Cleaned winning options: \(cleanedWinningOptions)")
            print("🔍 Fetching user bets for party ID: \(partyId)")
            
            // Fetch user bet results
            let userBetsResponse = try await supabaseClient
                .from("User Bets")
                .select("user_id, bet_selection, is_winner")
                .eq("party_id", value: Int(partyId))
                .execute()
            
            if let rawData = String(data: userBetsResponse.data, encoding: .utf8) {
                print("🔍 Raw user bets response: \(rawData)")
            }
            
            struct UserBetData: Codable {
                let user_id: String
                let bet_selection: String
                let is_winner: Bool? // Add this field
            }
            
            let userBetsData: [UserBetData] = try JSONDecoder().decode([UserBetData].self, from: userBetsResponse.data)
            guard !userBetsData.isEmpty else {
                await MainActor.run {
                    self.winners = []
                    self.losers = []
                    self.isLoading = false
                }
                return
            }
            
            let userIds = userBetsData.map { $0.user_id }
            
            // Fetch usernames
            let usernamesResponse = try await supabaseClient
                .from("Username")
                .select("user_id, username")
                .in("user_id", values: userIds)
                .execute()
            
            if let rawData = String(data: usernamesResponse.data, encoding: .utf8) {
                print("🔍 Raw usernames response: \(rawData)")
            }
            
            struct UsernameData: Codable {
                let user_id: String
                let username: String
            }
            
            let usernamesData: [UsernameData] = try JSONDecoder().decode([UsernameData].self, from: usernamesResponse.data)
            let userIdToUsername = Dictionary(uniqueKeysWithValues: usernamesData.map { ($0.user_id, $0.username) })
            
            // Build results
            var allResults: [UserResult] = []
            for userBet in userBetsData {
                let username = userIdToUsername[userBet.user_id] ?? userBet.user_id
                let userResult = UserResult(
                    user_id: userBet.user_id,
                    username: username,
                    bet_selection_text: userBet.bet_selection,
                    winningOptions: cleanedWinningOptions,
                    isWinnerFromDB: userBet.is_winner
                )
                allResults.append(userResult)
            }
            
            let maxScore = allResults.map { $0.score }.max() ?? 0
            var winnersArray: [UserResult] = []
            var losersArray: [UserResult] = []

            if lowerBetType == "timed" || lowerBetType == "contest" {
                // For timed/contest bets, use the is_winner field from database
                winnersArray = allResults.filter { result in
                    return result.is_winner == true
                }
                losersArray = allResults.filter { result in
                    return result.is_winner != true
                }
            } else {
                // For normal bets, use scoring logic and update is_winner accordingly
                for result in allResults {
                    var updatedResult = result
                    if result.score == maxScore && maxScore > 0 {
                        // Create a new UserResult with updated is_winner status
                        let newResult = UserResult(
                            user_id: result.user_id,
                            username: result.username,
                            bet_selection_text: result.bet_selection.joined(separator: ", "),
                            winningOptions: cleanedWinningOptions,
                            isWinnerFromDB: true
                        )
                        winnersArray.append(newResult)
                    } else {
                        // Create a new UserResult with updated is_winner status
                        let newResult = UserResult(
                            user_id: result.user_id,
                            username: result.username,
                            bet_selection_text: result.bet_selection.joined(separator: ", "),
                            winningOptions: cleanedWinningOptions,
                            isWinnerFromDB: false
                        )
                        losersArray.append(newResult)
                    }
                }
            }
            
            print("✅ Final results: \(winnersArray.count) winners, \(losersArray.count) losers")
            
            // Only update winner status in database for non-timed/contest bets
            if lowerBetType != "timed" && lowerBetType != "contest" {
                await updateWinnerStatusInDatabase(winners: winnersArray, losers: losersArray)
            }
            
            if !winnersArray.isEmpty && !hasUpdatedWins {
                await updateWinsForWinners(winnersArray)
                await MainActor.run {
                    self.hasUpdatedWins = true
                }
            }
            
            await MainActor.run {
                self.winners = winnersArray
                self.losers = losersArray
                self.highestScore = maxScore
                self.isLoading = false
            }
            
        } catch {
            print("❌ Complete error details: \(error)")
            await MainActor.run {
                self.errorMessage = "Error loading results: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    
    private func updateWinnerStatusInDatabase(winners: [UserResult], losers: [UserResult]) async {
        print("📝 Updating winner status in database")
        
        // Update winners
        for winner in winners {
            do {
                let _ = try await supabaseClient
                    .from("User Bets")
                    .update(["is_winner": true])
                    .eq("party_id", value: Int(partyId))
                    .eq("user_id", value: winner.user_id)
                    .execute()
                
                print("✅ Updated winner status for user: \(winner.username)")
            } catch {
                print("❌ Failed to update winner status for user \(winner.username): \(error)")
            }
        }
        
        // Update losers
        for loser in losers {
            do {
                let _ = try await supabaseClient
                    .from("User Bets")
                    .update(["is_winner": false])
                    .eq("party_id", value: Int(partyId))
                    .eq("user_id", value: loser.user_id)
                    .execute()
                
                print("✅ Updated loser status for user: \(loser.username)")
            } catch {
                print("❌ Failed to update loser status for user \(loser.username): \(error)")
            }
        }
    }
    
    private func updateWinsForWinners(_ winners: [UserResult]) async {
        print("🏆 Updating wins count for \(winners.count) winners")
        
        for winner in winners {
            do {
                // Use PostgreSQL function to increment wins atomically
                let _ = try await supabaseClient
                    .rpc("increment_user_wins", params: ["user_id_param": winner.user_id])
                    .execute()
                
                print("✅ Successfully incremented wins for user: \(winner.username)")
            } catch {
                print("❌ Failed to increment wins for user \(winner.username): \(error)")
                // Continue with other users even if one fails
            }
        }
    }
}

// MARK: - User Selection Detail View
struct UserSelectionDetailView: View {
    let userResult: GameResultsView.UserResult
    let winningOptions: [String]
    let betPrompt: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // User Header
                        VStack(spacing: 12) {
                            // User icon based on winner/loser status
                            Image(systemName: userResult.is_winner || userResult.score > 0 ? "person.circle.fill" : "person.circle")
                                .font(.system(size: 60))
                                .foregroundColor(userResult.is_winner ? .green : .orange)
                            
                            Text(userResult.username)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            // Score badge
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("Score: \(userResult.score)/\(winningOptions.count)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(20)
                        }
                        .padding(.top, 20)
                        
                        // Bet Question
                        if !betPrompt.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Question:")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(betPrompt)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        // User's Selections
                        VStack(alignment: .leading, spacing: 16) {
                            Text("\(userResult.username)'s Selections:")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                            
                            ForEach(userResult.bet_selection, id: \.self) { selection in
                                let isCorrect = winningOptions.contains { winningOption in
                                    selection.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
                                    winningOption.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                }
                                
                                HStack {
                                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(isCorrect ? .green : .red)
                                        .font(.system(size: 20))
                                    
                                    Text(selection)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if isCorrect {
                                        Text("✓ Correct")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.green.opacity(0.2))
                                            .cornerRadius(8)
                                    }
                                }
                                .padding()
                                .background(isCorrect ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isCorrect ? Color.green : Color.red, lineWidth: 1)
                                )
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        // Correct Answers Section
                        if !winningOptions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Correct Answers:")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                
                                ForEach(winningOptions, id: \.self) { option in
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                            .font(.system(size: 16))
                                        
                                        Text(option)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.yellow.opacity(0.2))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.yellow, lineWidth: 1)
                                    )
                                    .padding(.horizontal, 24)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

struct WinnerCard: View {
    let userResult: GameResultsView.UserResult
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Winner icon
            Image(systemName: "crown.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)
            
            // Score badge
            Text("\(userResult.score) pts")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.yellow)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(10)
            
            // Username - tappable
            Button(action: onTap) {
                Text(userResult.username)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Their bet selection preview
            VStack(spacing: 4) {
                Text("Selected:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                // Show only first 2 selections with "..." if more
                ForEach(Array(userResult.bet_selection.prefix(2)), id: \.self) { selection in
                    Text(selection)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.3))
                        .cornerRadius(6)
                        .lineLimit(1)
                }
                
                if userResult.bet_selection.count > 2 {
                    Text("...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Text("Tap to view all")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(Color.green.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green, lineWidth: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
}

struct LoserCard: View {
    let userResult: GameResultsView.UserResult
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Loser icon
            Image(systemName: "hand.thumbsup.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            // Score badge
            Text("\(userResult.score) pts")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(10)
            
            // Username - tappable
            Button(action: onTap) {
                Text(userResult.username)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Their bet selection preview
            VStack(spacing: 4) {
                Text("Selected:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                // Show only first 2 selections with "..." if more
                ForEach(Array(userResult.bet_selection.prefix(2)), id: \.self) { selection in
                    Text(selection)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(6)
                        .lineLimit(1)
                }
                
                if userResult.bet_selection.count > 2 {
                    Text("...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Text("Tap to view all")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(Color.red.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red, lineWidth: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    GameResultsView(partyId: 1, partyName: "Test Party")
        .environmentObject(SessionManager(supabaseClient: SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "public-anon-key"
        )))
}
