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
    
    struct UserResult: Codable, Identifiable {
        let id = UUID()
        let user_id: String
        let username: String
        let bet_selection: [String] // This will be parsed from the text field
        let is_winner: Bool
        
        enum CodingKeys: String, CodingKey {
            case user_id, username, bet_selection, is_winner
        }
        
        // Custom initializer to handle the parsing
        init(user_id: String, username: String, bet_selection_text: String, is_winner: Bool) {
            self.user_id = user_id
            self.username = username
            self.bet_selection = bet_selection_text.components(separatedBy: ", ").filter { !$0.isEmpty }
            self.is_winner = is_winner
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
                                        Text("Congratulations! 🎉")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.green)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 24)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(winners) { winner in
                                                WinnerCard(userResult: winner)
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
                                            ForEach(losers) { loser in
                                                LoserCard(userResult: loser)
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

        }
        .onAppear {
            Task {
                await fetchGameResults()
            }
        }
    }
    
    private func fetchGameResults() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Debug: Print raw response data
            print("🔍 Fetching party details for party ID: \(partyId)")
            
            // Fetch party details including winning options, bet prompt, AND game status
            let partyResponse = try await supabaseClient
                .from("Parties")
                .select("winning_options, bet, game_status")
                .eq("id", value: Int(partyId))
                .limit(1)
                .execute()
            
            // Debug: Print raw party response
            if let rawData = String(data: partyResponse.data, encoding: .utf8) {
                print("🔍 Raw party response: \(rawData)")
            }
            
            // Try flexible decoding for party data
            struct PartyResult: Codable {
                let winning_options: [String]?
                let bet: String?
                let game_status: String?
            }
            
            let partyResults: [PartyResult]
            do {
                partyResults = try JSONDecoder().decode([PartyResult].self, from: partyResponse.data)
            } catch {
                print("❌ Error decoding party data: \(error)")
                // Try alternative decoding where winning_options might be stored differently
                struct AlternativePartyResult: Codable {
                    let winning_options: String? // Maybe it's stored as a string?
                    let bet: String?
                    let game_status: String?
                }
                
                let altResults = try JSONDecoder().decode([AlternativePartyResult].self, from: partyResponse.data)
                partyResults = altResults.map { altResult in
                    let winningOptionsArray: [String]
                    if let winningOptionsString = altResult.winning_options {
                        // Try to parse as comma-separated string
                        winningOptionsArray = winningOptionsString.components(separatedBy: ", ").filter { !$0.isEmpty }
                    } else {
                        winningOptionsArray = []
                    }
                    
                    return PartyResult(
                        winning_options: winningOptionsArray,
                        bet: altResult.bet,
                        game_status: altResult.game_status
                    )
                }
            }
            
            guard let partyResult = partyResults.first else {
                await MainActor.run {
                    self.errorMessage = "Party not found"
                    self.isLoading = false
                }
                return
            }
            
            // CHECK 1: Verify the game has ended before showing results
            let gameStatus = partyResult.game_status ?? ""
            if gameStatus != "ended" {
                await MainActor.run {
                    self.errorMessage = "Game results are not available yet. The host is still determining the outcome."
                    self.isLoading = false
                }
                return
            }
            
            // CHECK 2: Ensure there are winning options
            guard let winningOptions = partyResult.winning_options, !winningOptions.isEmpty else {
                await MainActor.run {
                    self.errorMessage = "Game results are not available yet. No winning options have been set."
                    self.isLoading = false
                }
                return
            }
            
            await MainActor.run {
                self.winningOptions = winningOptions
                self.betPrompt = partyResult.bet ?? ""
            }
            
            print("🔍 Game status: \(gameStatus)")
            print("🔍 Winning options: \(winningOptions)")
            print("🔍 Fetching user bets for party ID: \(partyId)")
            
            // Fetch user bet results with proper data type handling
            let userBetsResponse = try await supabaseClient
                .from("User Bets")
                .select("user_id, bet_selection, is_winner")
                .eq("party_id", value: Int(partyId))
                .execute()
            
            // Debug: Print raw user bets response
            if let rawData = String(data: userBetsResponse.data, encoding: .utf8) {
                print("🔍 Raw user bets response: \(rawData)")
            }
            
            struct UserBetData: Codable {
                let user_id: String
                let bet_selection: String // This is text in the database
                let is_winner: Bool?
            }
            
            let userBetsData: [UserBetData]
            do {
                userBetsData = try JSONDecoder().decode([UserBetData].self, from: userBetsResponse.data)
                print("✅ Successfully decoded \(userBetsData.count) user bets")
            } catch {
                print("❌ Error decoding user bets: \(error)")
                throw error
            }
            
            // Skip username fetching if no user bets
            guard !userBetsData.isEmpty else {
                await MainActor.run {
                    self.winners = []
                    self.losers = []
                    self.isLoading = false
                }
                return
            }
            
            // Fetch usernames for all users
            let userIds = userBetsData.map { $0.user_id }
            print("🔍 Fetching usernames for user IDs: \(userIds)")
            
            let usernamesResponse = try await supabaseClient
                .from("Username")
                .select("user_id, username")
                .in("user_id", values: userIds)
                .execute()
            
            // Debug: Print raw usernames response
            if let rawData = String(data: usernamesResponse.data, encoding: .utf8) {
                print("🔍 Raw usernames response: \(rawData)")
            }
            
            struct UsernameData: Codable {
                let user_id: String
                let username: String
            }
            
            let usernamesData: [UsernameData]
            do {
                usernamesData = try JSONDecoder().decode([UsernameData].self, from: usernamesResponse.data)
                print("✅ Successfully decoded \(usernamesData.count) usernames")
            } catch {
                print("❌ Error decoding usernames: \(error)")
                // Continue with user IDs as fallback
                usernamesData = []
            }
            
            let userIdToUsername = Dictionary(uniqueKeysWithValues: usernamesData.map { ($0.user_id, $0.username) })
            
            // Combine data and separate winners and losers
            var winnersArray: [UserResult] = []
            var losersArray: [UserResult] = []
            
            for userBet in userBetsData {
                let username = userIdToUsername[userBet.user_id] ?? userBet.user_id
                let userResult = UserResult(
                    user_id: userBet.user_id,
                    username: username,
                    bet_selection_text: userBet.bet_selection, // Pass the text to be parsed
                    is_winner: userBet.is_winner ?? false
                )
                
                print("🔍 User \(username) selected: \(userBet.bet_selection), is_winner: \(userBet.is_winner ?? false)")
                
                if userBet.is_winner == true {
                    winnersArray.append(userResult)
                } else {
                    losersArray.append(userResult)
                }
            }
            
            print("✅ Final results: \(winnersArray.count) winners, \(losersArray.count) losers")
            
            // Update wins count for winners if not already done
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
            print("❌ Complete error details: \(error)")
            await MainActor.run {
                self.errorMessage = "Error loading results: \(error.localizedDescription)"
                self.isLoading = false
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

struct WinnerCard: View {
    let userResult: GameResultsView.UserResult
    
    var body: some View {
        VStack(spacing: 8) {
            // Winner icon
            Image(systemName: "crown.fill")
                .font(.system(size: 24))
                .foregroundColor(.yellow)
            
            // Username
            Text(userResult.username)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Their bet selection
            VStack(spacing: 4) {
                Text("Selected:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                ForEach(userResult.bet_selection, id: \.self) { selection in
                    Text(selection)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.3))
                        .cornerRadius(6)
                }
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
    }
}

struct LoserCard: View {
    let userResult: GameResultsView.UserResult
    
    var body: some View {
        VStack(spacing: 8) {
            // Loser icon
            Image(systemName: "hand.thumbsup.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            // Username
            Text(userResult.username)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Their bet selection
            VStack(spacing: 4) {
                Text("Selected:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                ForEach(userResult.bet_selection, id: \.self) { selection in
                    Text(selection)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(6)
                }
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
    }
}

#Preview {
    GameResultsView(partyId: 1, partyName: "Test Party")
        .environmentObject(SessionManager(supabaseClient: SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "public-anon-key"
        )))
}
