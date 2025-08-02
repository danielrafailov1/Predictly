//
//  CreatePartyView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-06-06.
//

import Foundation
import SwiftUI
import Supabase

struct CreatePartyView: View {
    @Binding var navPath: NavigationPath
    let party_code: String
    let betType: BetType
    let userEmail: String
    @State private var showCopiedMessage = false
    @State private var selectedGame: BaseballGame? = nil
    @State private var userId: String? = nil
    @State private var partyId: Int64? = nil
    @State private var refreshCount = 0
    @State private var selectedEvents: Set<Int> = []
    @State private var canProceed = false
    @State private var errorMessage: String? = nil
    @State private var showBetsGeneratedConfirmation = false
    @State private var showHostBetGeneration = false
    @State private var pendingBets: [String] = []
    @State private var confirmedBets: [String]? = nil
    @State private var partyName: String = ""
    @State private var privacyOption: String = "Public"
    @State private var maxMembers: Int = 10
    @State private var betQuantity: Int = 15
    @State private var potBalance: Int = 0
    @Environment(\.supabaseClient) private var supabaseClient

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

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Party Details")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Share your party code with friends")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 32)
                
                // Party Code Card
                VStack(spacing: 16) {
                    Text("Your Party Code")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    HStack(spacing: 12) {
                        Text(party_code)
                            .font(.system(size: 24, weight: .bold))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .foregroundColor(.white)
                        
                        Button(action: {
                            UIPasteboard.general.string = party_code
                            withAnimation {
                                showCopiedMessage = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showCopiedMessage = false
                                }
                            }
                        }) {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    
                    if showCopiedMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Copied to clipboard!")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(24)
                .background(Color.white.opacity(0.05))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        showHostBetGeneration = true
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                            Text(confirmedBets == nil ? (betType == .draftTeam ? "Draft Players" : "Generate Bets") : "Edit Bets")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.purple,
                                    Color.purple.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    if let bets = confirmedBets {
                        Text("\(bets.count) bets confirmed!")
                            .foregroundColor(.green)
                            .font(.system(size: 16, weight: .medium))
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 24)
                .sheet(isPresented: $showHostBetGeneration) {
                    if let game = selectedGame {
                        HostBetGenerationView(
                            game: game,
                            onConfirm: { bets in
                                confirmedBets = bets
                                showHostBetGeneration = false
                            },
                            betType: betType
                        )
                    }
                }
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
                
                // Leave Party Button
                Button(action: {
                    // Leave party logic
                }) {
                    HStack {
                        Image(systemName: "arrow.right.square.fill")
                            .font(.system(size: 16))
                        Text("Leave Party")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.bottom, 32)

                VStack(spacing: 16) {
                    TextField("Party Name", text: $partyName)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                    Picker("Privacy", selection: $privacyOption) {
                        Text("Public").tag("Public")
                        Text("Private").tag("Private")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    Stepper(value: $maxMembers, in: 2...50) {
                        Text("Max Members: \(maxMembers)")
                            .foregroundColor(.white)
                    }
                    Stepper(value: $betQuantity, in: 5...25) {
                        Text("Bet Quantity: \(betQuantity)")
                            .foregroundColor(.white)
                    }
                    TextField("Pot Balance (optional)", value: $potBalance, formatter: NumberFormatter())
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)

                Button(action: {
                    Task {
                        guard let game = selectedGame, let bets = confirmedBets else {
                            errorMessage = "Please select a game and confirm bets."
                            return
                        }
                        let newParty = NewParty(
                            party_code: party_code,
                            game_id: Int64(game.id),
                            created_by: userId ?? userEmail,
                            party_name: partyName,
                            privacy_option: privacyOption,
                            max_members: Int64(maxMembers),
                            bet_quantity: Int64(betQuantity),
                            bet_type: betType.rawValue,
                            events: bets
                        )
                        let result = await createParty(newParty)
                        if result.success {
                            // Add host as a member
                            var hostUserId: String? = userId
                            if hostUserId == nil {
                                hostUserId = await fetchUserId(for: userEmail)
                            }
                            if let userId = hostUserId {
                                if let partyId = await fetchPartyId(for: party_code), let game = selectedGame {
                                    let now = ISO8601DateFormatter().string(from: Date())
                                    let newMember = NewPartyMember(party_id: partyId, user_id: userId, joined_at: now, created_at: now)
                                    do {
                                        _ = try await supabaseClient
                                            .from("Party Members")
                                            .insert(newMember)
                                            .execute()
                                    } catch {
                                        print("Error adding host as party member: \(error)")
                                    }
                                    // Navigate to GameEventView
                                    navPath.append(BetFlowPath.gameEvent(
                                        game: game,
                                        partyId: partyId,
                                        userId: userId,
                                        betType: betType,
                                        party_code: party_code,
                                        userEmail: userEmail
                                    ))
                                }
                            }
                        } else {
                            errorMessage = result.error
                        }
                    }
                }) {
                    Text("Create Party")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background((confirmedBets != nil && partyName != "") ? Color.green : Color.gray)
                        .cornerRadius(16)
                        .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(confirmedBets == nil || partyName == "")
            }
        }
    }

    private func fetchGameAndUserIdAndGenerateBets() async {
        do {
            let partyResponse = try await supabaseClient
                .from("Parties")
                .select("id, game_id")
                .eq("party_code", value: party_code)
                .limit(1)
                .execute()
            struct PartyResult: Codable { let id: Int64; let game_id: Int64 }
            let decoder = JSONDecoder()
            print("DEBUG: RAW partyResponse.data: \(String(data: partyResponse.data, encoding: .utf8) ?? "nil")")
            do {
                let parties = try decoder.decode([PartyResult].self, from: partyResponse.data)
                guard let party = parties.first else {
                    self.errorMessage = "No party found for this code."
                    return
                }
                self.partyId = party.id
                // Fetch game info
                let gameResponse = try await supabaseClient
                    .from("Game")
                    .select("id, home_team, away_team, date")
                    .eq("id", value: Int(party.game_id))
                    .limit(1)
                    .execute()
                print("DEBUG: RAW gameResponse.data: \(String(data: gameResponse.data, encoding: .utf8) ?? "nil")")
                struct GameRow: Codable {
                    let id: Int
                    let home_team: String
                    let away_team: String
                    let date: String
                }
                let gameRows = try decoder.decode([GameRow].self, from: gameResponse.data)
                guard let gameRow = gameRows.first else {
                    self.errorMessage = "No game found for this party."
                    return
                }
                self.selectedGame = BaseballGame(
                    id: gameRow.id,
                    home_team_name: gameRow.home_team,
                    away_team_name: gameRow.away_team,
                    date: gameRow.date
                )
                // Fetch userId for the signed-in user's email
                self.userId = await fetchUserId(for: userEmail)
                // Generate bets
                let bets = await generateBingoCardWithGemini(for: self.selectedGame!)
                // Save bets to Parties table (events column)
                let saveSuccess = await savePartyEventsToPartiesTable(partyId: party.id, bets: bets)
                if saveSuccess {
                    await MainActor.run {
                        showBetsGeneratedConfirmation = true
                    }
                } else {
                    self.errorMessage = "Failed to save bets to party."
                }
            } catch {
                print("DEBUG: Decoding error for partyResponse or gameResponse: \(error)")
                print("DEBUG: RAW partyResponse.data (on error): \(String(data: partyResponse.data, encoding: .utf8) ?? "nil")")
            }
        } catch {
            self.errorMessage = "Failed to fetch party/game info: \(error.localizedDescription)"
        }
    }

    private func savePartyEventsToPartiesTable(partyId: Int64, bets: [String]) async -> Bool {
        struct UpdatePayload: Encodable {
            let events: [String]
        }
        do {
            let updatePayload = UpdatePayload(events: bets)
            _ = try await supabaseClient
                .from("Parties")
                .update(updatePayload)
                .eq("id", value: Int(partyId))
                .execute()
            return true
        } catch {
            print("Error saving events to Parties table: \(error)")
            return false
        }
    }

    private func fetchUserId(for email: String) async -> String? {
        do {
            let response = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .limit(1)
                .execute()
            struct UserIdRow: Decodable { let user_id: String }
            let decoder = JSONDecoder()
            let userIds = try decoder.decode([UserIdRow].self, from: response.data)
            return userIds.first?.user_id
        } catch {
            print("Error fetching user_id for email \(email): \(error)")
            return nil
        }
    }
    
    private func generateBingoCardWithGemini(for game: BaseballGame) async -> [String] {
        let isDraftTeam = betType == .draftTeam
        print("[DEBUG] generateBingoCardWithGemini called. betType: \(betType.rawValue), isDraftTeam: \(isDraftTeam)")
        let prompt: String
        if isDraftTeam {
            prompt = """
            List all starting players for both the \(game.home_team_name) and \(game.away_team_name) in today's baseball game. Format: 'Player Name (Team)'. Return as a numbered list, no explanations, 18-22 players total.
            """
            print("[DEBUG] Using draft team prompt: \(prompt)")
        } else {
            prompt = """
            Generate 25 fun and creative bet events for a baseball game between the \(game.home_team_name) and the \(game.away_team_name). Each should be a short, unique, and entertaining phrase describing a possible event or stat in the game. Return as a numbered list from 1 to 25, no explanations.
            """
            print("[DEBUG] Using normal bet prompt: \(prompt)")
        }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyAunbuh_N_W_mkRpvKIosu-TDajJvJO8Q8") else {
            return []
        }
        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        var prompts: [String] = []
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("[DEBUG] Gemini API response: \(responseJSON)")
                if let candidates = responseJSON["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    let lines = text.split(separator: "\n")
                    prompts = lines.compactMap {
                        if let range = $0.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                            return String($0[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                        }
                        return nil
                    }
                }
            }
        } catch {
            print("Gemini error: \(error)")
        }
        print("[DEBUG] Final prompts: \(prompts)")
        if isDraftTeam {
            // Fallback: 20 generic player names
            let fallbackPlayers = (1...20).map { "Player \($0) (Team)" }
            if prompts.count < 18 {
                prompts += fallbackPlayers.prefix(18 - prompts.count)
            }
            if prompts.count > 22 {
                prompts = Array(prompts.prefix(22))
            }
        } else {
            // Fallback/hardcoded
            let hardcoded = [
                "Player hits a home run", "Game goes to extra innings", "Pitcher gets 10+ strikeouts",
                "First batter gets hit by pitch", "Stolen base in the 1st inning", "Manager gets ejected",
                "Back-to-back home runs", "Triple play", "Grand slam", "Pitcher throws 100+ pitches",
                "Catcher picks off runner", "Outfielder robs a home run", "Pinch hitter gets a hit",
                "Bullpen meltdown", "Walk-off win", "Bunt single", "Wild pitch scores a run",
                "Bases loaded walk", "Hit for the cycle", "No errors in the game", "First pitch is a strike",
                "Leadoff double", "Game ends on a strikeout", "Home team wins by 1 run", "Rain delay"
            ]
            if prompts.count < 25 {
                prompts += hardcoded.prefix(25 - prompts.count)
            }
            if prompts.count > 25 {
                prompts = Array(prompts.prefix(25))
            }
        }
        print("[DEBUG] Prompts after fallback: \(prompts)")
        return prompts
    }

    private func createParty(_ newParty: NewParty) async -> (success: Bool, error: String?) {
        do {
            _ = try await supabaseClient
                .from("Parties")
                .insert(newParty)
                .execute()
            return (true, nil)
        } catch {
            print("Error creating party: \(error)")
            return (false, error.localizedDescription)
        }
    }

    private func fetchPartyId(for code: String) async -> Int64? {
        do {
            let response = try await supabaseClient
                .from("Parties")
                .select("id")
                .eq("party_code", value: code)
                .limit(1)
                .execute()
            struct PartyIdRow: Decodable { let id: Int64 }
            let decoder = JSONDecoder()
            let ids = try decoder.decode([PartyIdRow].self, from: response.data)
            return ids.first?.id
        } catch {
            print("Error fetching party id for code \(code): \(error)")
            return nil
        }
    }
}

#Preview {
    CreatePartyView(navPath: .constant(NavigationPath()), party_code: String(UUID().uuidString.prefix(6)).uppercased(), betType: .predefined, userEmail: "example@example.com")
        .environment(\.supabaseClient, .development)
}
