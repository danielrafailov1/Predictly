import SwiftUI
import Supabase

struct HostBetGenerationView: View {
    let game: BaseballGame
    let onConfirm: ([String]) -> Void
    let betType: BetType
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var bets: [String] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var refreshCount = 0
    let maxRefreshes = 3
    @State private var selectedPlayers: Set<Int> = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text(betType == .draftTeam ? "Draft Players for Party" : "Generate Challenges for Party")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top, 16)
                if isLoading {
                    ProgressView(betType == .draftTeam ? "Loading Players..." : "Generating Challenges...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding()
                } else if let error = error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(0..<bets.count, id: \.self) { idx in
                                if betType == .draftTeam {
                                    Button(action: {
                                        if selectedPlayers.contains(idx) {
                                            selectedPlayers.remove(idx)
                                        } else if selectedPlayers.count < 5 {
                                            selectedPlayers.insert(idx)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: selectedPlayers.contains(idx) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedPlayers.contains(idx) ? .green : .gray)
                                            Text("\(idx + 1). \(bets[idx])")
                                                .foregroundColor(.white)
                                                .padding(.vertical, 4)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .background(selectedPlayers.contains(idx) ? Color.green.opacity(0.2) : Color.white.opacity(0.05))
                                        .cornerRadius(8)
                                        .padding(.horizontal, 8)
                                    }
                                    .disabled(!selectedPlayers.contains(idx) && selectedPlayers.count >= 5)
                                } else {
                                    Text("\(idx + 1). \(bets[idx])")
                                        .foregroundColor(.white)
                                        .padding(.vertical, 4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(8)
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    if betType == .draftTeam {
                        Text("Select exactly 5 players for your draft team.")
                            .foregroundColor(.yellow)
                            .font(.system(size: 15, weight: .medium))
                            .padding(.top, 4)
                    }
                }
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
                        if betType == .draftTeam {
                            let selected = selectedPlayers.sorted().map { bets[$0] }
                            onConfirm(selected)
                        } else {
                            onConfirm(bets)
                        }
                        dismiss()
                    }) {
                        Text(betType == .draftTeam ? "Confirm Draft Team" : "Use These Challenges")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                (betType == .draftTeam ? (selectedPlayers.count == 5) : (bets.count == 25)) ? Color.green : Color.gray
                            )
                            .cornerRadius(12)
                    }
                    .disabled(betType == .draftTeam ? (selectedPlayers.count != 5) : (bets.count != 25))
                }
                .padding(.horizontal)
                Spacer()
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
                Task { await generateBets() }
            }
        }
    }
    
    private func generateBets() async {
        isLoading = true
        error = nil
        
        if betType == .draftTeam {
            let prompt = """
            List all starting players for both the \(game.home_team_name) and \(game.away_team_name) in today's baseball game. Format: 'Player Name (Team)'. Return as a numbered list, no explanations, 18-22 players total.
            """
            
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyAunbuh_N_W_mkRpvKIosu-TDajJvJO8Q8") else {
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
                let (data, _) = try await URLSession.shared.data(for: request)
                if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = responseJSON["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    
                    let lines = text.split(separator: "\n")
                    let players = lines.compactMap {
                        if let range = $0.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                            return String($0[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                        }
                        return nil
                    }
                    challenges = players
                } else {
                    error = "Failed to parse player list."
                }
            } catch {
                self.error = "Gemini error: \(error)"
            }
            
            isLoading = false
            return
        }
        
        let prompt = """
        Generate 25 fun and creative challenge ideas for a baseball game between the \(game.home_team_name) and the \(game.away_team_name). Each should be a short, unique, and entertaining phrase describing a possible event, milestone, or stat in the game. Return as a numbered list from 1 to 25, no explanations.
        """
        
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyAunbuh_N_W_mkRpvKIosu-TDajJvJO8Q8") else {
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
            let (data, _) = try await URLSession.shared.data(for: request)
            if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = responseJSON["candidates"] as? [[String: Any]],
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
                challenges = prompts.count == 25 ? prompts : Array(prompts.prefix(25))
            } else {
                error = "Failed to parse response."
            }
        } catch {
            self.error = "Gemini error: \(error)"
        }
        
        isLoading = false
    }

} 
