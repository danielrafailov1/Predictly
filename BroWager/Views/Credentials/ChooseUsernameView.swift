import SwiftUI

struct ChooseUsernameView: View {
    let userId: String
    let email: String
    let password: String
    let onComplete: (String, String) -> Void
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    // List of banned/inappropriate words
    private let bannedWords: [String] = [
        "admin", "mod", "staff", "support", "fuck", "shit", "bitch", "asshole", "cunt", "nigger", "fag", "dick", "cock", "pussy", "slut", "whore", "rape", "cum", "sex", "porn", "nazi", "hitler", "kike", "spic", "chink", "gook", "coon", "retard", "faggot", "nigga", "twat", "wank", "wanker", "bastard", "douche", "douchebag", "fucker", "motherfucker", "suck", "sucker", "jerk", "prick", "arse", "arsehole", "bollocks", "bugger", "crap", "damn", "git", "knob", "minger", "munter", "pillock", "plonker", "slag", "tosser", "twit", "twunt", "twit", "vagina", "anus", "butt", "boob", "boobs", "tit", "tits", "testicle", "testicles", "scrotum", "penis", "vulva", "clit", "clitoris", "erection", "ejaculate", "masturbate", "masturbation", "orgasm", "sperm", "semen", "prostitute", "hooker", "escort", "john", "blowjob", "handjob", "rimjob", "69", "420", "666"
    ]
    // Computed property to check for inappropriate username
    private var isUsernameInappropriate: Bool {
        let lowercased = username.lowercased()
        return bannedWords.contains { lowercased.contains($0) }
    }
    
    var body: some View {
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
            VStack(spacing: 32) {
                Text("Choose a Username")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 32)
                TextField("Enter username", text: $username)
                    .font(.system(size: 18))
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                if isUsernameInappropriate {
                    Text("This username is not allowed.")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                Button(action: {
                    Task { await submitUsername() }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue,
                                        Color.blue.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || isUsernameInappropriate)
                .padding(.horizontal, 24)
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            print("[ChooseUsernameView] Sheet is being presented for userId: \(userId), email: \(email)")
        }
    }
    
    private func submitUsername() async {
        isLoading = true
        errorMessage = nil
        let maxAttempts = 5
        for _ in 0..<maxAttempts {
            let randomId = String(format: "%04d", Int.random(in: 0...9999))
            let newUsername = NewUsername(user_id: userId, username: username, identifier: randomId)
            do {
                try await supabaseClient
                    .from("Username")
                    .insert(newUsername)
                    .execute()
                await MainActor.run {
                    isLoading = false
                    onComplete(email, password)
                }
                return
            } catch {
                let errorString = error.localizedDescription
                if errorString.contains("23505") || errorString.contains("duplicate key value") {
                    // Try again with a new identifier
                    continue
                } else {
                    isLoading = false
                    errorMessage = "Failed to set username: \(errorString)"
                    return
                }
            }
        }
        isLoading = false
        errorMessage = "Could not assign a unique identifier for this username. Please try a different username."
    }
}

struct NewUsername: Codable {
    let user_id: String
    let username: String
    let identifier: String
} 