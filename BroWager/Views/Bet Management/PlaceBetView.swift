import SwiftUI
import Supabase

struct PlaceBetView: View {
    let partyId: Int64
    let userId: String
    let partyName: String
    let betPrompt: String
    let betOptions: [String]
    let betTerms: String
    let isEditing: Bool // New parameter to determine if editing
    
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedOptions: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var existingBetId: Int64? = nil
    
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
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 12) {
                                Text(isEditing ? "Edit Your Bet" : "Make Your Bet")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text(partyName)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 20)
                            
                            // Bet Prompt
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
                            
                            // Bet Terms (if available)
                            if !betTerms.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Terms & Conditions:")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.yellow)
                                    
                                    Text(betTerms)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding()
                                        .background(Color.yellow.opacity(0.1))
                                        .cornerRadius(10)
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            // Options Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose your answer(s):")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                
                                ForEach(betOptions, id: \.self) { option in
                                    Button(action: {
                                        if selectedOptions.contains(option) {
                                            selectedOptions.remove(option)
                                        } else {
                                            selectedOptions.insert(option)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: selectedOptions.contains(option) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedOptions.contains(option) ? .blue : .white.opacity(0.6))
                                                .font(.system(size: 20))
                                            
                                            Text(option)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.leading)
                                            
                                            Spacer()
                                        }
                                        .padding()
                                        .background(
                                            selectedOptions.contains(option)
                                            ? Color.blue.opacity(0.2)
                                            : Color.white.opacity(0.1)
                                        )
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    selectedOptions.contains(option)
                                                    ? Color.blue
                                                    : Color.white.opacity(0.2),
                                                    lineWidth: selectedOptions.contains(option) ? 2 : 1
                                                )
                                        )
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                            
                            // Error Message
                            if let error = errorMessage {
                                Text(error)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                    .padding(.horizontal, 24)
                            }
                            
                            // Submit Button
                            Button(action: {
                                Task {
                                    if isEditing {
                                        await updateBet()
                                    } else {
                                        await placeBet()
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                                    Text(isEditing ? "Update Bet" : "Place Bet")
                                }
                                .font(.system(size: 20, weight: .bold))
                                .padding(.vertical, 14)
                                .padding(.horizontal, 32)
                                .background(selectedOptions.isEmpty ? Color.gray : Color.orange.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                            }
                            .disabled(selectedOptions.isEmpty)
                            .padding(.top, 20)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            if isEditing {
                Task {
                    await loadExistingBet()
                }
            }
        }
    }

    private func loadExistingBet() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await supabaseClient
                .from("User Bets") // Use consistent table name
                .select("id, bet_selection")
                .eq("user_id", value: userId)
                .eq("party_id", value: Int(partyId))
                .limit(1)
                .execute()
            
            struct ExistingBet: Codable {
                let id: Int64
                let bet_selection: String // Keep as String since it's stored as text
            }
            
            let existingBets = try JSONDecoder().decode([ExistingBet].self, from: response.data)
            
            if let existingBet = existingBets.first {
                // Parse the bet_selection back into an array
                let optionsArray = existingBet.bet_selection.components(separatedBy: ", ")
                
                await MainActor.run {
                    self.existingBetId = existingBet.id
                    self.selectedOptions = Set(optionsArray)
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Could not load existing bet"
                    self.isLoading = false
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Error loading existing bet: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func placeBet() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let selectedOptionsArray = Array(selectedOptions)
            
            // Decide which table to use consistently
            // Option 1: Use "User Bets" table (recommended)
            struct BetInsert: Codable {
                let party_id: Int64
                let user_id: String  // Keep as String since User Bets table has user_id as text
                let bet_selection: String // Store as comma-separated string
                let is_winner: Bool? // Optional, will be set when outcome is confirmed
            }
            
            let selectedOptionText = selectedOptionsArray.joined(separator: ", ")
            
            let betData = BetInsert(
                party_id: partyId,
                user_id: userId,
                bet_selection: selectedOptionText,
                is_winner: nil // Will be set later when outcome is confirmed
            )
            
            _ = try await supabaseClient
                .from("User Bets") // Use consistent table name
                .insert(betData)
                .execute()
            
            await MainActor.run {
                self.isLoading = false
            }
            
            dismiss()
            
        } catch {
            print("❌ Error placing bet: \(error)")
            
            let errorDescription: String
            if error.localizedDescription.contains("404") {
                errorDescription = "Table 'User Bets' not found. Please check your database setup."
            } else if error.localizedDescription.contains("status code") {
                errorDescription = "Database connection error. Please try again."
            } else {
                errorDescription = error.localizedDescription
            }
            
            await MainActor.run {
                self.errorMessage = "Failed to place bet: \(errorDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func updateBet() async {
        guard let betId = existingBetId else {
            await MainActor.run {
                self.errorMessage = "Cannot update bet: missing bet ID"
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let selectedOptionsArray = Array(selectedOptions)
            let selectedOptionText = selectedOptionsArray.joined(separator: ", ")
            
            _ = try await supabaseClient
                .from("User Bets") // Use consistent table name
                .update(["bet_selection": selectedOptionText])
                .eq("id", value: Int(betId))
                .execute()
            
            await MainActor.run {
                self.isLoading = false
            }
            
            dismiss()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update bet: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

#Preview {
    PlaceBetView(
        partyId: 1,
        userId: "user123",
        partyName: "Test Party",
        betPrompt: "Who will win the game?",
        betOptions: ["Team A", "Team B", "Tie"],
        betTerms: "Winner takes all",
        isEditing: false
    )
    .environmentObject(SessionManager(supabaseClient: SupabaseClient(
        supabaseURL: URL(string: "https://example.supabase.co")!,
        supabaseKey: "public-anon-key"
    )))
}
