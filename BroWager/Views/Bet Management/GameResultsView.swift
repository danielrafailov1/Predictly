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
    @State private var hasUpdatedWins = false
    @State private var highestScore = 0
    @State private var betType: String = "" // NEW: Track bet type
    
    @State private var selectedUser: UserResult?
    @State private var showingUserDetail = false
    
    struct UserResult: Codable, Identifiable {
        let id = UUID()
        let user_id: String
        let username: String
        let bet_selection: [String]
        let is_winner: Bool
        let score: Int
        let elapsed_time: Int? // NEW: For contest timing
        let completed_in_time: Bool? // NEW: For contest/timer completion status
        let final_score: Int? // NEW: For contest final score
        
        enum CodingKeys: String, CodingKey {
            case user_id, username, bet_selection, is_winner, score, elapsed_time, completed_in_time, final_score
        }
        
        init(user_id: String, username: String, bet_selection_text: String, winningOptions: [String], isWinnerFromDB: Bool? = nil, elapsed_time: Int? = nil, completed_in_time: Bool? = nil, final_score: Int? = nil, betType: String) {
            self.user_id = user_id
            self.username = username
            self.elapsed_time = elapsed_time
            self.completed_in_time = completed_in_time
            self.final_score = final_score
            
            if betType.lowercased() == "contest" || betType.lowercased() == "timed" {
                // For contest/timer bets, bet_selection is a description, not options to parse
                self.bet_selection = [bet_selection_text]
                self.score = final_score ?? 0
            } else {
                // For normal bets, parse selections and calculate score
                self.bet_selection = bet_selection_text.components(separatedBy: ", ").filter { !$0.isEmpty }
                self.score = self.bet_selection.filter { selection in
                    winningOptions.contains { winningOption in
                        selection.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
                        winningOption.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    }
                }.count
            }
            
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
                                
                                // Show different scoring info based on bet type
                                if betType.lowercased() == "contest" {
                                    if let fastestWinner = winners.first {
                                        Text("Winner completed target in \(formatTime(fastestWinner.elapsed_time ?? 0))")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.yellow)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(Color.yellow.opacity(0.2))
                                            .cornerRadius(8)
                                    }
                                } else if betType.lowercased() != "timed" && highestScore > 0 {
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
                            
                            // Winning Options (only for normal bets)
                            if !winningOptions.isEmpty && betType.lowercased() == "normal" {
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
                                        Text(getWinnersTitle())
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
                                                    betType: betType,
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
                                            ForEach(getSortedLosers()) { loser in
                                                LoserCard(
                                                    userResult: loser,
                                                    betType: betType,
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
                            
                            // Back Button
                            Button(action: {
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
                        betPrompt: betPrompt,
                        betType: betType
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
    
    private func getWinnersTitle() -> String {
        switch betType.lowercased() {
        case "contest":
            return "🎉 Winners! (Fastest to Target)"
        case "timed":
            return "🎉 Winners! (Completed in Time)"
        default:
            return "🎉 Winners! (Score: \(highestScore))"
        }
    }
    
    private func getSortedLosers() -> [UserResult] {
        switch betType.lowercased() {
        case "contest":
            // Sort by final score descending, then by time ascending
            return losers.sorted { first, second in
                if let firstScore = first.final_score, let secondScore = second.final_score {
                    if firstScore != secondScore {
                        return firstScore > secondScore
                    }
                }
                // If scores are equal or nil, sort by time
                let firstTime = first.elapsed_time ?? Int.max
                let secondTime = second.elapsed_time ?? Int.max
                return firstTime < secondTime
            }
        default:
            return losers.sorted { $0.score > $1.score }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func cleanWinningOptions(_ options: [String]) -> [String] {
        return options.map { option in
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
            
            // Fetch party details
            let partyResponse = try await supabaseClient
                .from("Parties")
                .select("winning_options, bet, game_status, bet_type")
                .eq("id", value: Int(partyId))
                .limit(1)
                .execute()
            
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
            
            // Store bet type
            await MainActor.run {
                self.betType = partyResult.bet_type
            }
            
            // Verify the game has ended
            let gameStatus = partyResult.game_status
            if gameStatus != "ended" {
                await MainActor.run {
                    self.errorMessage = "Game results are not available yet. The host is still determining the outcome."
                    self.isLoading = false
                }
                return
            }
            
            // Only enforce winning options for normal bets
            if lowerBetType != "timed" && lowerBetType != "contest" {
                guard let rawWinningOptions = partyResult.winning_options, !rawWinningOptions.isEmpty else {
                    await MainActor.run {
                        self.errorMessage = "Game results are not available yet. No winning options have been set."
                        self.isLoading = false
                    }
                    return
                }
            }
            
            let cleanedWinningOptions = cleanWinningOptions(partyResult.winning_options ?? [])
            
            await MainActor.run {
                self.winningOptions = cleanedWinningOptions
                self.betPrompt = partyResult.bet ?? ""
            }
            
            print("🔍 Game status: \(gameStatus)")
            print("🔍 Bet type: \(lowerBetType)")
            
            // Fetch user bet results with additional fields for contest/timer bets
            let userBetsResponse = try await supabaseClient
                .from("User Bets")
                .select("user_id, bet_selection, is_winner, elapsed_time, completed_in_time, final_score")
                .eq("party_id", value: Int(partyId))
                .execute()
            
            struct UserBetData: Codable {
                let user_id: String
                let bet_selection: String
                let is_winner: Bool?
                let elapsed_time: Int?
                let completed_in_time: Bool?
                let final_score: Int?
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
            
            struct UsernameData: Codable {
                let user_id: String
                let username: String
            }
            
            let usernamesData: [UsernameData] = try JSONDecoder().decode([UsernameData].self, from: usernamesResponse.data)
            let userIdToUsername = Dictionary(uniqueKeysWithValues: usernamesData.map { ($0.user_id, $0.username) })
            
            // Build results based on bet type
            var allResults: [UserResult] = []
            for userBet in userBetsData {
                let username = userIdToUsername[userBet.user_id] ?? userBet.user_id
                let userResult = UserResult(
                    user_id: userBet.user_id,
                    username: username,
                    bet_selection_text: userBet.bet_selection,
                    winningOptions: cleanedWinningOptions,
                    isWinnerFromDB: userBet.is_winner,
                    elapsed_time: userBet.elapsed_time,
                    completed_in_time: userBet.completed_in_time,
                    final_score: userBet.final_score,
                    betType: partyResult.bet_type
                )
                allResults.append(userResult)
            }
            
            var winnersArray: [UserResult] = []
            var losersArray: [UserResult] = []
            
            if lowerBetType == "contest" {
                // For contest bets: winners are those who completed target in fastest time
                let completedTargetUsers = allResults.filter { result in
                    (result.completed_in_time == true) && (result.final_score ?? 0) >= 0
                }
                
                if !completedTargetUsers.isEmpty {
                    // Find the fastest time among those who completed the target
                    let fastestTime = completedTargetUsers.compactMap { $0.elapsed_time }.min() ?? Int.max
                    
                    // All users who completed in the fastest time are winners
                    let fastestUsers = completedTargetUsers.filter { ($0.elapsed_time ?? Int.max) == fastestTime }
                    
                    winnersArray = fastestUsers
                    losersArray = allResults.filter { result in
                        !fastestUsers.contains { $0.user_id == result.user_id }
                    }
                    
                    // Update winner status in database for contest bets
                    await updateContestWinnerStatus(winners: winnersArray, losers: losersArray)
                } else {
                    // No one completed the target
                    losersArray = allResults
                }
                
            } else if lowerBetType == "timed" {
                // For timed bets: use the existing is_winner field from database
                winnersArray = allResults.filter { $0.is_winner == true }
                losersArray = allResults.filter { $0.is_winner != true }
                
            } else {
                // For normal bets: use scoring logic
                let maxScore = allResults.map { $0.score }.max() ?? 0
                
                winnersArray = allResults.filter { $0.score == maxScore && maxScore > 0 }
                losersArray = allResults.filter { $0.score != maxScore || maxScore == 0 }
                
                // Update winner status in database for normal bets
                await updateNormalBetWinnerStatus(winners: winnersArray, losers: losersArray)
                
                await MainActor.run {
                    self.highestScore = maxScore
                }
            }
            
            print("✅ Final results: \(winnersArray.count) winners, \(losersArray.count) losers")
            
            // Update wins count for winners (only once)
            if !winnersArray.isEmpty && !hasUpdatedWins {
                await updateWinsForWinners(winnersArray)
                await MainActor.run {
                    self.hasUpdatedWins = true
                }
            }
            
            await MainActor.run {
                self.winners = winnersArray
                self.losers = losersArray
                self.isLoading = false
            }
            
        } catch {
            print("❌ Error fetching results: \(error)")
            await MainActor.run {
                self.errorMessage = "Error loading results: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func updateContestWinnerStatus(winners: [UserResult], losers: [UserResult]) async {
        print("📝 Updating contest winner status in database")
        
        // Update winners
        for winner in winners {
            do {
                _ = try await supabaseClient
                    .from("User Bets")
                    .update(["is_winner": true])
                    .eq("party_id", value: Int(partyId))
                    .eq("user_id", value: winner.user_id)
                    .execute()
                
                print("✅ Updated contest winner status for user: \(winner.username)")
            } catch {
                print("❌ Failed to update contest winner status for user \(winner.username): \(error)")
            }
        }
        
        // Update losers
        for loser in losers {
            do {
                _ = try await supabaseClient
                    .from("User Bets")
                    .update(["is_winner": false])
                    .eq("party_id", value: Int(partyId))
                    .eq("user_id", value: loser.user_id)
                    .execute()
                
                print("✅ Updated contest loser status for user: \(loser.username)")
            } catch {
                print("❌ Failed to update contest loser status for user \(loser.username): \(error)")
            }
        }
    }
    
    private func updateNormalBetWinnerStatus(winners: [UserResult], losers: [UserResult]) async {
        print("📝 Updating normal bet winner status in database")
        
        // Update winners
        for winner in winners {
            do {
                _ = try await supabaseClient
                    .from("User Bets")
                    .update(["is_winner": true])
                    .eq("party_id", value: Int(partyId))
                    .eq("user_id", value: winner.user_id)
                    .execute()
                
                print("✅ Updated normal bet winner status for user: \(winner.username)")
            } catch {
                print("❌ Failed to update normal bet winner status for user \(winner.username): \(error)")
            }
        }
        
        // Update losers
        for loser in losers {
            do {
                _ = try await supabaseClient
                    .from("User Bets")
                    .update(["is_winner": false])
                    .eq("party_id", value: Int(partyId))
                    .eq("user_id", value: loser.user_id)
                    .execute()
                
                print("✅ Updated normal bet loser status for user: \(loser.username)")
            } catch {
                print("❌ Failed to update normal bet loser status for user \(loser.username): \(error)")
            }
        }
    }
    
    private func updateWinsForWinners(_ winners: [UserResult]) async {
        print("🏆 Updating wins count for \(winners.count) winners")
        
        for winner in winners {
            do {
                _ = try await supabaseClient
                    .rpc("increment_user_wins", params: ["user_id_param": winner.user_id])
                    .execute()
                
                print("✅ Successfully incremented wins for user: \(winner.username)")
            } catch {
                print("❌ Failed to increment wins for user \(winner.username): \(error)")
            }
        }
    }
}

// MARK: - User Selection Detail View
struct UserSelectionDetailView: View {
    let userResult: GameResultsView.UserResult
    let winningOptions: [String]
    let betPrompt: String
    let betType: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
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
                            Image(systemName: userResult.is_winner ? "person.circle.fill" : "person.circle")
                                .font(.system(size: 60))
                                .foregroundColor(userResult.is_winner ? .green : .orange)
                            
                            Text(userResult.username)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            // Show different info based on bet type
                            if betType.lowercased() == "contest" {
                                VStack(spacing: 8) {
                                    if let finalScore = userResult.final_score {
                                        HStack {
                                            Image(systemName: "target")
                                                .foregroundColor(.blue)
                                            Text("Final Score: \(finalScore)")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    
                                    if let elapsedTime = userResult.elapsed_time {
                                        HStack {
                                            Image(systemName: "timer")
                                                .foregroundColor(.orange)
                                            Text("Time: \(formatTime(elapsedTime))")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    
                                    if let completed = userResult.completed_in_time {
                                        HStack {
                                            Image(systemName: completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundColor(completed ? .green : .red)
                                            Text(completed ? "Target Achieved" : "Target Not Reached")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(completed ? .green : .red)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                
                            } else if betType.lowercased() == "timed" {
                                VStack(spacing: 8) {
                                    if let elapsedTime = userResult.elapsed_time {
                                        HStack {
                                            Image(systemName: "timer")
                                                .foregroundColor(.orange)
                                            Text("Time: \(formatTime(elapsedTime))")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    
                                    if let completed = userResult.completed_in_time {
                                        HStack {
                                            Image(systemName: completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundColor(completed ? .green : .red)
                                            Text(completed ? "Completed in Time" : "Time Expired")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(completed ? .green : .red)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                
                            } else {
                                // Normal bet - show score
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
                        
                        // User's Response/Selections
                        VStack(alignment: .leading, spacing: 16) {
                            Text("\(userResult.username)'s Response:")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                            
                            if betType.lowercased() == "contest" || betType.lowercased() == "timed" {
                                // For contest/timer bets, show the description
                                ForEach(userResult.bet_selection, id: \.self) { response in
                                    HStack {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 20))
                                        
                                        Text(response)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                                    .padding(.horizontal, 24)
                                }
                            } else {
                                // For normal bets, show selections with correct/incorrect indicators
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
                        }
                        
                        // Correct Answers Section (only for normal bets)
                        if !winningOptions.isEmpty && betType.lowercased() == "normal" {
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
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

struct WinnerCard: View {
    let userResult: GameResultsView.UserResult
    let betType: String
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Winner icon
            Image(systemName: "crown.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)
            
            // Score/info badge based on bet type
            if betType.lowercased() == "contest" {
                if let elapsedTime = userResult.elapsed_time {
                    Text("\(formatTime(elapsedTime))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(10)
                }
            } else if betType.lowercased() == "timed" {
                Text("✓ Done")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(10)
            } else {
                Text("\(userResult.score) pts")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(10)
            }
            
            // Username - tappable
            Button(action: onTap) {
                Text(userResult.username)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Response preview
            VStack(spacing: 4) {
                Text("Response:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                if betType.lowercased() == "contest" || betType.lowercased() == "timed" {
                    Text(userResult.bet_selection.first ?? "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.3))
                        .cornerRadius(6)
                        .lineLimit(2)
                } else {
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
                }
                
                Text("Tap to view details")
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
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct LoserCard: View {
    let userResult: GameResultsView.UserResult
    let betType: String
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Loser icon
            Image(systemName: "hand.thumbsup.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            // Score/info badge based on bet type
            if betType.lowercased() == "contest" {
                VStack(spacing: 2) {
                    if let finalScore = userResult.final_score {
                        Text("\(finalScore) pts")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    if let elapsedTime = userResult.elapsed_time {
                        Text("\(formatTime(elapsedTime))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(10)
            } else if betType.lowercased() == "timed" {
                Text("X Failed")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(10)
            } else {
                Text("\(userResult.score) pts")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(10)
            }
            
            // Username - tappable
            Button(action: onTap) {
                Text(userResult.username)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Response preview
            VStack(spacing: 4) {
                Text("Response:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                if betType.lowercased() == "contest" || betType.lowercased() == "timed" {
                    Text(userResult.bet_selection.first ?? "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(6)
                        .lineLimit(2)
                } else {
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
                }
                
                Text("Tap to view details")
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
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
