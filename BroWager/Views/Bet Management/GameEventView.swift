//
//  MakeBetView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-06-04.
//

import SwiftUI
import Supabase
import Foundation

struct GameEventView: View {
    // Host mode
    let partySettings: (name: String, privacy: PartyLobbyView.PrivacyOption, maxMembers: Int, betQuantity: Int, betType: BetType, game: BaseballGame)?
    let onPartyCreated: ((String) -> Void)?
    // Member mode
    let fixedEvents: [String]?
    let partyId: Int64?
    let userId: String?
    let previousBet: [String]?
    
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var events: [String] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var refreshCount = 0
    let maxRefreshes = 3
    @State private var selectedEvents: Set<Int> = []
    @State private var showSuccess = false
    @State private var selectedPlayers: [String] = []
    
    var isDraftTeam: Bool { partySettings?.betType == .draftTeam }

    var body: some View {
        VStack(spacing: 0) {
            Text(partySettings != nil ? "Review & Confirm Bets" : "Select 15/25 Bets")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
            if isLoading {
                ProgressView("Generating Bets...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding()
            } else if let error = error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            } else if isDraftTeam {
                ScrollView {
                    VStack(spacing: 12) {
                        DraftTeamSelectionView(players: events, selectedPlayers: $selectedPlayers)
                        Button("Submit Team") {
                            Task { await saveDraftTeamBet() }
                        }
                        .disabled(selectedPlayers.count != 5)
                        .padding()
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<events.count, id: \.self) { idx in
                            HStack {
                                Text("\(idx + 1). \(events[idx])")
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedEvents.contains(idx) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedEvents.contains(idx) ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                            )
                            .onTapGesture {
                                if partySettings == nil {
                                    if selectedEvents.contains(idx) {
                                        selectedEvents.remove(idx)
                                    } else if selectedEvents.count < 15 {
                                        selectedEvents.insert(idx)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                if let _ = partySettings {
                    HStack(spacing: 16) {
                        Button(action: {
                            if refreshCount < maxRefreshes {
                                refreshCount += 1
                                Task { await generateBets() }
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh (") + Text("\(maxRefreshes - refreshCount)") + Text(")")
                            }
                            .foregroundColor(refreshCount < maxRefreshes ? .blue : .gray)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .disabled(refreshCount >= maxRefreshes || isLoading)
                        Button(action: {
                            Task { await createParty() }
                        }) {
                            Text("Create Party")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Button(action: {
                        if selectedEvents.count == 15 {
                            Task { await saveUserBet() }
                        }
                    }) {
                        Text("Submit Bets")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(selectedEvents.count == 15 ? Color.green : Color.gray)
                            .cornerRadius(16)
                            .padding(.horizontal)
                            .padding(.top, 12)
                    }
                    .disabled(selectedEvents.count != 15)
                }
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            print("[GameEventView] onAppear. Mode: \(partySettings != nil ? "host" : "member")")
            if let fixed = fixedEvents {
                print("[GameEventView] Using fixedEvents, count: \(fixed.count)")
                events = fixed
                isLoading = false
            } else {
                print("[GameEventView] Generating bets via Gemini API...")
                Task { await generateBets() }
            }
            if let previousBet = previousBet, !previousBet.isEmpty, events.count == 25 {
                // Pre-select previous bet events
                let indices = previousBet.compactMap { events.firstIndex(of: $0) }
                selectedEvents = Set(indices)
            }
        }
        .alert("Success!", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text(partySettings != nil ? "Party created and bets set!" : "Your bets have been submitted. Good luck!")
        }
    }
    
    private func generateBets() async {
        print("[GameEventView] generateBets() called. Starting loading...")
        isLoading = true
        error = nil
        guard let partySettings = partySettings else { print("[GameEventView] No partySettings, aborting."); isLoading = false; return }
        let isDraftTeam = partySettings.betType == .draftTeam
        let prompt: String
        if isDraftTeam {
            prompt = """
            List all starting players for both the \(partySettings.game.home_team_name) and \(partySettings.game.away_team_name) in today's baseball game. Format: 'Player Name (Team)'. Return as a numbered list, no explanations, 18-22 players total.
            """
            print("[GameEventView] Using draft team prompt: \(prompt)")
        } else {
            prompt = """
            Generate 25 fun and creative bet events for a baseball game between the \(partySettings.game.home_team_name) and the \(partySettings.game.away_team_name). Each should be a short, unique, and entertaining phrase describing a possible event or stat in the game. Return as a numbered list from 1 to 25, no explanations.
            """
            print("[GameEventView] Using normal bet prompt: \(prompt)")
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyAunbuh_N_W_mkRpvKIosu-TDajJvJO8Q8") else {
            print("[GameEventView] Invalid Gemini API URL.")
            error = "Invalid URL"
            isLoading = false
            return
        }
        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        do {
            print("[GameEventView] Sending Gemini API request...")
            let (data, _) = try await URLSession.shared.data(for: request)
            print("[GameEventView] Gemini API response received. Data length: \(data.count)")
            if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("[GameEventView] Gemini API JSON: \(responseJSON)")
                if let candidates = responseJSON["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    let lines = text.split(separator: "\n")
                    let prompts = lines.compactMap {
                        if let range = $0.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                            return String($0[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                        }
                        return nil
                    }
                    if isDraftTeam {
                        print("[GameEventView] Gemini API returned \(prompts.count) players.")
                        events = prompts
                    } else if prompts.count == 25 {
                        print("[GameEventView] Gemini API returned 25 prompts.")
                        events = prompts
                    } else {
                        print("[GameEventView] Gemini API did not return 25 prompts. Using fallback.")
                        events = fallbackEvents()
                        error = "Could not generate 25 unique bets. Using fallback bets."
                    }
                } else {
                    print("[GameEventView] Gemini API response missing expected structure. Using fallback.")
                    events = fallbackEvents()
                    error = "Failed to parse response. Using fallback bets."
                }
            } else {
                print("[GameEventView] Gemini API response not JSON. Using fallback.")
                events = fallbackEvents()
                error = "Failed to parse response. Using fallback bets."
            }
        } catch {
            print("[GameEventView] Gemini API error: \(error). Using fallback.")
            events = fallbackEvents()
            self.error = "Gemini error: \(error). Using fallback bets."
        }
        isLoading = false
        print("[GameEventView] generateBets() finished. isLoading set to false.")
    }
    
    private func fallbackEvents() -> [String] {
        return [
            "Player hits a home run", "Game goes to extra innings", "Pitcher gets 10+ strikeouts",
            "First batter gets hit by pitch", "Stolen base in the 1st inning", "Manager gets ejected",
            "Back-to-back home runs", "Triple play", "Grand slam", "Pitcher throws 100+ pitches",
            "Catcher picks off runner", "Outfielder robs a home run", "Pinch hitter gets a hit",
            "Bullpen meltdown", "Walk-off win", "Bunt single", "Wild pitch scores a run",
            "Bases loaded walk", "Hit for the cycle", "No errors in the game", "First pitch is a strike",
            "Leadoff double", "Game ends on a strikeout", "Home team wins by 1 run", "Rain delay"
        ]
    }
    
    private func createParty() async {
        guard let partySettings = partySettings else { return }
        isLoading = true
        error = nil
        do {
            // Fetch user_id for email
            let userResponse = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: userId ?? "")
                .limit(1)
                .execute()
            struct UserIdRow: Decodable { let user_id: String }
            let decoder = JSONDecoder()
            let userIds = try decoder.decode([UserIdRow].self, from: userResponse.data)
            guard let hostUserId = userIds.first?.user_id, !hostUserId.isEmpty else {
                await MainActor.run {
                    isLoading = false
                    self.error = "Could not determine host user ID. Please log in again."
                }
                return
            }
            // Insert game if needed
            struct NewGame: Codable {
                let home_team: String
                let away_team: String
                let date: String
            }
            let newGame = NewGame(
                home_team: partySettings.game.home_team_name,
                away_team: partySettings.game.away_team_name,
                date: partySettings.game.date
            )
            let gameInsertResponse = try await supabaseClient
                .from("Game")
                .insert(newGame)
                .select("id")
                .limit(1)
                .execute()
            struct GameIDResponse: Codable { let id: Int64 }
            let gameIdResults = try decoder.decode([GameIDResponse].self, from: gameInsertResponse.data)
            let gameId = gameIdResults.first?.id ?? Int64(partySettings.game.id)
            // Generate a random 6-character party code
            let partyCode = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
            // Create new party
            let newParty = NewParty(
                party_code: partyCode,
                game_id: gameId,
                created_by: hostUserId,
                party_name: partySettings.name,
                privacy_option: partySettings.privacy.rawValue,
                max_members: Int64(partySettings.maxMembers),
                bet_quantity: Int64(partySettings.betQuantity),
                bet_type: partySettings.betType.rawValue,
                events: events
            )
            _ = try await supabaseClient
                .from("Parties")
                .insert(newParty)
                .execute()
            await MainActor.run {
                isLoading = false
                showSuccess = true
                onPartyCreated?(partyCode)
            }
        } catch {
            await MainActor.run {
                isLoading = false
                self.error = "Failed to create party: \(error.localizedDescription)"
            }
        }
    }
    
    private func saveUserBet() async {
        guard let partyId = partyId, let userId = userId else { return }
        let selectedEventStrings = selectedEvents.map { events[$0] }
        let newUserBet = NewUserBet(
            party_id: partyId,
            user_id: userId,
            bet_events: selectedEventStrings,
            score: 0
        )
        do {
            _ = try await supabaseClient
                .from("User Bets")
                .upsert(newUserBet, onConflict: "party_id, user_id")
                .execute()
            await MainActor.run {
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to save bets: \(error.localizedDescription)"
            }
        }
    }

    private func saveDraftTeamBet() async {
        guard let partyId = partyId, let userId = userId else { return }
        struct DraftTeamPayload: Encodable {
            let party_id: Int64
            let user_id: String
            let draft_team: [String]
        }
        let payload = DraftTeamPayload(party_id: partyId, user_id: userId, draft_team: selectedPlayers)
        do {
            _ = try await supabaseClient
                .from("User Bets")
                .upsert(payload, onConflict: "party_id,user_id")
                .execute()
            await MainActor.run {
                showSuccess = true
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to save draft team: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    GameEventView(partySettings: nil, onPartyCreated: nil, fixedEvents: nil, partyId: nil, userId: nil, previousBet: nil)
}

struct GameEventHostView: View {
    @Binding var navPath: NavigationPath
    let game: BaseballGame
    let partyId: Int64
    let userId: String
    let betType: BetType
    @Binding var refreshCount: Int
    let maxRefreshes: Int
    let partyCode: String
    let userEmail: String
    let fixedEvents: [String]?

    @State private var bingoSquares: [String] = []
    @State private var isLoadingBingo = true
    @State private var error: String?
    @State private var selectedEvents: Set<Int> = []
    @State private var showCreateButton = false
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var showRefreshLimitAlert = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select 15/25 Bets")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if fixedEvents == nil {
                Button(action: {
                    if refreshCount < maxRefreshes {
                        refreshCount += 1
                        Task { await generateBingoCardWithGemini(for: game) }
                        } else {
                            showRefreshLimitAlert = true
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh (") + Text("\(maxRefreshes - refreshCount)") + Text(")")
                    }
                }
                .disabled(refreshCount >= maxRefreshes || isLoadingBingo)
                .foregroundColor(refreshCount < maxRefreshes ? .blue : .gray)
                    .alert(isPresented: $showRefreshLimitAlert) {
                        Alert(
                            title: Text("Refresh Limit Reached"),
                            message: Text("You have reached the maximum number of refreshes (\(maxRefreshes)). Please proceed with the current bets."),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                }
            }
            .padding()
            if isLoadingBingo {
                ProgressView(fixedEvents == nil ? "Generating Bets..." : "Loading Bets...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding()
            } else if let error = error {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<bingoSquares.count, id: \.self) { index in
                            HStack {
                                Text("\(index + 1). \(bingoSquares[index])")
                                    .foregroundColor(.white)
                                Spacer()
                                if selectedEvents.contains(index) {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedEvents.contains(index) ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                            )
                            .onTapGesture {
                                if selectedEvents.contains(index) {
                                    selectedEvents.remove(index)
                                } else if selectedEvents.count < 15 {
                                    selectedEvents.insert(index)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                Button(action: {
                    if selectedEvents.count == 15 {
                        Task {
                            await saveUserPartyBets()
                        }
                    }
                }) {
                    Text("Submit Bets")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedEvents.count == 15 ? Color.green : Color.gray)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }
                .disabled(selectedEvents.count != 15)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            if let fixed = fixedEvents {
                bingoSquares = fixed
                isLoadingBingo = false
            } else {
            Task { await generateBingoCardWithGemini(for: game) }
            }
        }
    }

    func generateBingoCardWithGemini(for game: BaseballGame) async {
        let prompt: String
        switch betType {
        case .predefined:
            prompt = """
            Generate 25 fun and creative bet events for a baseball game between the \(game.home_team_name) and \(game.away_team_name). Each should be a short, unique, and entertaining phrase describing a possible event or stat in the game (e.g., "First player to miss a free throw", "Coach who yells first"). Return as a numbered list from 1 to 25, no explanations.
            """
        case .draftTeam:
            prompt = """
            List 10 top players from both the \(game.home_team_name) and \(game.away_team_name) for a fantasy draft. Each entry should be the player's name and team. Return as a numbered list from 1 to 10, no explanations. (Users will draft 5 players each; the team with the highest total stats wins.)
            """
        case .randomPlayer:
            prompt = """
            Generate 10 fun, random player-based challenges for a baseball game between the \(game.home_team_name) and \(game.away_team_name). Examples: "Coin toss winner", "First lefty to score", "First player with jersey number over 20 to get a hit", "First to steal a base". Return as a numbered list from 1 to 10, no explanations.
            """
        case .statBased:
            prompt = """
            Generate 10 creative stat-based bet prompts for a baseball game between the \(game.home_team_name) and \(game.away_team_name). Examples: "Odd or even final score?", "Total home runs over/under 3.5", "Top scorer prediction", "Most errors by a team". Return as a numbered list from 1 to 10, no explanations.
            """
        case .outcomeBased:
            prompt = """
            Generate 10 classic outcome-based bet prompts for a baseball game between the \(game.home_team_name) and \(game.away_team_name). Examples: "Who will win?", "Which team scores first?", "Will there be a comeback after trailing?". Return as a numbered list from 1 to 10, no explanations.
            """
        case .custom:
            prompt = """
            Generate 10 unique custom bet ideas for a baseball game between the \(game.home_team_name) and \(game.away_team_name). Each should be a creative, open-ended bet prompt. Return as a numbered list from 1 to 10, no explanations.
            """
        case .politics:
            prompt = """
            Generate 25 fun and creative bet events for a political event or election. Each should be a short, unique, and entertaining phrase describing a possible outcome or scenario (e.g., "Who will win the debate?", "Will a certain bill pass?"). Return as a numbered list from 1 to 25, no explanations.
            """
        case .food:
            prompt = """
            Generate 25 fun and creative bet events for a food challenge or eating contest. Each should be a short, unique, and entertaining phrase describing a possible outcome or scenario (e.g., "Who can eat the most hot dogs?", "Will someone try a new cuisine?"). Return as a numbered list from 1 to 25, no explanations.
            """
        case .lifeEvents:
            prompt = """
            Generate 25 fun and creative bet events for life events or personal milestones. Each should be a short, unique, and entertaining phrase describing a possible outcome or scenario (e.g., "Who will get a new job first?", "Will someone move cities this year?"). Return as a numbered list from 1 to 25, no explanations.
            """
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyAunbuh_N_W_mkRpvKIosu-TDajJvJO8Q8") else {
            self.error = "Invalid URL"
            return
        }

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        isLoadingBingo = true
        error = nil

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = responseJSON["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                let prompts = parsePrompts(from: text)
                if prompts.count == 25 {
                    bingoSquares = prompts
                    selectedEvents = []
                } else {
                    error = "Gemini returned an unexpected number of items."
                }
            } else {
                error = "Gemini response is invalid."
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoadingBingo = false
    }

    func parsePrompts(from text: String) -> [String] {
        let lines = text.split(separator: "\n")
        return lines.compactMap {
            if let range = $0.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                return String($0[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            return nil
        }
    }

    private func saveUserPartyBets() async {
        let selectedEventStrings = selectedEvents.map { bingoSquares[$0] }
        struct PartyBetsInsert: Encodable {
            let party_id: Int64
            let user_id: String
            let bets: [String]
        }
        let insertPayload = PartyBetsInsert(party_id: partyId, user_id: userId, bets: selectedEventStrings)
        do {
            _ = try await supabaseClient
                .from("PartyBets")
                .insert(insertPayload)
                .execute()
            await MainActor.run {
                // Optionally show a confirmation or navigate
                navPath.append(BetFlowPath.partyDetails(partyCode: partyCode, email: userEmail))
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to save your bets: \(error.localizedDescription)"
            }
        }
    }
}

// Subview to break up the ForEach expression and resolve compiler error
struct BetRow: View {
    let index: Int
    let bet: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            Text("\(index + 1). \(bet)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .onTapGesture { onTap() }
    }
}

struct DraftTeamSelectionView: View {
    let players: [String]
    @Binding var selectedPlayers: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick 5 players for your team:")
                .font(.headline)
                .foregroundColor(.white)
            ForEach(players, id: \.self) { player in
                Button(action: {
                    if selectedPlayers.contains(player) {
                        selectedPlayers.removeAll { $0 == player }
                    } else if selectedPlayers.count < 5 {
                        selectedPlayers.append(player)
                    }
                }) {
                    HStack {
                        Text(player)
                            .foregroundColor(.white)
                        Spacer()
                        if selectedPlayers.contains(player) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        }
                    }
                    .padding(8)
                    .background(selectedPlayers.contains(player) ? Color.blue.opacity(0.3) : Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
