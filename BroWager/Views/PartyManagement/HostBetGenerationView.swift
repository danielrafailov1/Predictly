import SwiftUI
import Supabase

// Minimal replacement for deleted BaseballGame model
struct BaseballGame {
    let home_team_name: String
    let away_team_name: String
    let date: String
}

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
                ProgressView("Generating Bets...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding()
                if isLoading {
                    ProgressView("Generating Bets...")
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
                                Text("\(idx + 1). \(bets[idx])")
                                    .foregroundColor(.white)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                    .padding(.horizontal, 8)
                            }
                        }
                        .padding(.vertical)
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
                        onConfirm(bets)
                        dismiss()
                    }) {
                        Text("Use These Bets")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .disabled(bets.count != 25)
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
        let prompt = "Generate 25 fun and creative bet events for a game. Each should be a short, unique, and entertaining phrase describing a possible event or stat. Return as a numbered list from 1 to 25, no explanations."
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
                bets = prompts.count == 25 ? prompts : Array(prompts.prefix(25))
            } else {
                error = "Failed to parse response."
            }
        } catch {
            self.error = "Gemini error: \(error)"
        }
        isLoading = false
    }
} 