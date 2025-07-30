import SwiftUI
import Supabase

struct ConfirmBetOutcomeView: View {
    let partyId: Int64
    let partyName: String
    let betOptions: [String]
    let betPrompt: String
    
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedWinningOptions: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var aiVerificationResult: String = ""
    @State private var showConfirmation = false
    @State private var betDate: Date?
    @State private var isAIVerifying = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - extend to cover entire screen including safe areas
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(.all) // This ensures the gradient covers everything
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 12) {
                                Text("Confirm Bet Outcome")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text(partyName)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                
                                // Display bet date if available
                                if let betDate = betDate {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.blue)
                                        Text("Bet Date: \(betDate, style: .date)")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
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
                            
                            // AI Verification Status
                            if isAIVerifying {
                                VStack(spacing: 12) {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                            .scaleEffect(0.8)
                                        Text("AI is verifying bet outcome...")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                    .padding(.horizontal, 24)
                                }
                            }
                            
                            // AI Verification Result
                            if !aiVerificationResult.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "brain.head.profile")
                                            .foregroundColor(.yellow)
                                        Text("AI Verification Result:")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.yellow)
                                    }
                                    
                                    Text(aiVerificationResult)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                        .padding()
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(10)
                                    
                                    Text("AI has automatically selected the recommended options. Review and modify if needed.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .italic()
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            // Options Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select the correct answer(s):")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                
                                ForEach(betOptions, id: \.self) { option in
                                    Button(action: {
                                        if selectedWinningOptions.contains(option) {
                                            selectedWinningOptions.remove(option)
                                        } else {
                                            selectedWinningOptions.insert(option)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: selectedWinningOptions.contains(option) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedWinningOptions.contains(option) ? .green : .white.opacity(0.6))
                                                .font(.system(size: 20))
                                            
                                            Text(option)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.leading)
                                            
                                            Spacer()
                                        }
                                        .padding()
                                        .background(
                                            selectedWinningOptions.contains(option)
                                            ? Color.green.opacity(0.2)
                                            : Color.white.opacity(0.1)
                                        )
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    selectedWinningOptions.contains(option)
                                                    ? Color.green
                                                    : Color.white.opacity(0.2),
                                                    lineWidth: selectedWinningOptions.contains(option) ? 2 : 1
                                                )
                                        )
                                    }
                                    .padding(.horizontal, 24)
                                    .disabled(isAIVerifying)
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
                            
                            // Confirm Outcome Button
                            Button(action: {
                                showConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Confirm Bet Outcome")
                                }
                                .font(.system(size: 20, weight: .bold))
                                .padding(.vertical, 14)
                                .padding(.horizontal, 32)
                                .background(selectedWinningOptions.isEmpty || isAIVerifying ? Color.gray : Color.green.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                            }
                            .disabled(selectedWinningOptions.isEmpty || isAIVerifying)
                            .padding(.top, 20)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar) // Hide the navigation bar background
        }
        .onAppear {
            // Load bet date and automatically trigger AI verification
            Task {
                await loadBetDate()
                await askAIForVerification()
            }
            
            // Set navigation bar appearance
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        .alert("Confirm Outcome", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                Task {
                    await confirmBetOutcome()
                }
            }
        } message: {
            Text("Are you sure these are the correct winning options? This action cannot be undone.")
        }
    }
    
    // Load bet date from database
    private func loadBetDate() async {
        do {
            let response = try await supabaseClient
                .from("Parties")
                .select("bet_date")
                .eq("id", value: Int(partyId))
                .single()
                .execute()
            
            struct PartyDateResponse: Codable {
                let bet_date: String
            }
            
            let partyDateResponse = try JSONDecoder().decode(PartyDateResponse.self, from: response.data)
            
            // Parse the date string
            let dateFormatter = ISO8601DateFormatter()
            if let parsedDate = dateFormatter.date(from: partyDateResponse.bet_date) {
                await MainActor.run {
                    self.betDate = parsedDate
                }
            }
        } catch {
            print("Error loading bet date: \(error)")
        }
    }
    
    // Updated askAIForVerification function that runs automatically
    private func askAIForVerification() async {
        await MainActor.run {
            isAIVerifying = true
            errorMessage = nil
        }
        
        do {
            // Get the bet date from the database first
            let partyResponse = try await supabaseClient
                .from("Parties")
                .select("bet_date")
                .eq("id", value: Int(partyId))
                .single()
                .execute()
            
            struct PartyDate: Codable {
                let bet_date: String
            }
            
            let partyDate = try JSONDecoder().decode(PartyDate.self, from: partyResponse.data)
            
            // Create a comprehensive prompt for bet outcome verification with date context
            let prompt = """
            You are a sports betting outcome analyzer with access to real-time sports data. Analyze the following bet for the specific date and determine which option(s) are correct.

            Bet Date: \(partyDate.bet_date)
            Bet Question: \(betPrompt)
            Available Options: \(betOptions.joined(separator: ", "))

            IMPORTANT: Only analyze games and events that occurred on \(partyDate.bet_date). Do not use data from other dates.

            Please research the game results and statistics specifically for \(partyDate.bet_date). Then provide your analysis in the following format:

            ANALYSIS:
            [Your detailed analysis of why certain options are correct based on events from \(partyDate.bet_date)]

            CORRECT OPTIONS:
            [List the correct option(s) from the available options based on \(partyDate.bet_date) results]

            CONFIDENCE:
            [High/Medium/Low confidence level with reasoning]

            DATE VERIFICATION:
            [Confirm that your analysis is based on events from \(partyDate.bet_date) specifically]

            Note: Only select options that are definitely correct based on verified game data from the specified date. If you cannot verify the results for that specific date, please state that clearly.
            """

            // Use your existing AIServices to get the analysis
            let aiResponse = try await AIServices.shared.sendPrompt(
                prompt,
                model: "gemini-2.5-flash",
                temperature: 0.1, // Low temperature for factual analysis
                maxTokens: 1200
            )

            // Parse the AI response to extract suggested winners
            let suggestedWinners = parseAIResponse(aiResponse)

            await MainActor.run {
                self.aiVerificationResult = aiResponse
                
                // Auto-select the AI's suggested winners if any were found
                if !suggestedWinners.isEmpty {
                    self.selectedWinningOptions = Set(suggestedWinners)
                }
                
                self.isAIVerifying = false
            }

        } catch {
            await MainActor.run {
                let errorMsg = "AI Verification Error: \(error.localizedDescription)"
                self.aiVerificationResult = errorMsg
                self.errorMessage = errorMsg
                self.isAIVerifying = false
            }
        }
    }

    // Helper function to parse AI response and extract suggested winners
    private func parseAIResponse(_ response: String) -> [String] {
        var suggestedWinners: [String] = []
        
        // Look for the "CORRECT OPTIONS:" section
        let lines = response.components(separatedBy: .newlines)
        var inCorrectOptionsSection = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.uppercased().contains("CORRECT OPTION") {
                inCorrectOptionsSection = true
                continue
            }
            
            if inCorrectOptionsSection {
                // Stop if we hit another section
                if trimmedLine.uppercased().contains("CONFIDENCE:") ||
                   trimmedLine.uppercased().contains("ANALYSIS:") ||
                   trimmedLine.uppercased().contains("DATE VERIFICATION:") {
                    break
                }
                
                // Check if any of our bet options are mentioned in this line
                for option in betOptions {
                    // Clean the option for comparison
                    let cleanOption = option.trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanLine = trimmedLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Look for exact matches or close matches
                    if cleanLine.lowercased().contains(cleanOption.lowercased()) &&
                       !suggestedWinners.contains(cleanOption) {
                        suggestedWinners.append(cleanOption)
                        print("🔍 AI suggested winner: '\(cleanOption)' from line: '\(cleanLine)'")
                    }
                }
            }
        }
        
        // Fallback: scan the entire response for bet options
        if suggestedWinners.isEmpty {
            for option in betOptions {
                let cleanOption = option.trimmingCharacters(in: .whitespacesAndNewlines)
                let responseLower = response.lowercased()
                let optionLower = cleanOption.lowercased()
                
                // Look for the option mentioned with positive indicators
                if responseLower.contains(optionLower) &&
                   (responseLower.contains("correct") ||
                    responseLower.contains("winner") ||
                    responseLower.contains("true") ||
                    responseLower.contains("yes")) {
                    suggestedWinners.append(cleanOption)
                    print("🔍 AI fallback suggested winner: '\(cleanOption)'")
                }
            }
        }
        
        print("🔍 Final AI suggested winners: \(suggestedWinners)")
        return suggestedWinners
    }
    
    private func confirmBetOutcome() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let winningOptionsArray = Array(selectedWinningOptions)
            
            // Alternative approach: Use a struct for the update
            struct PartyUpdate: Codable {
                let winning_options: [String]
                let game_status: String
            }
            
            let updateData = PartyUpdate(
                winning_options: winningOptionsArray,
                game_status: "ended"
            )
            
            // 1. Update the party with the winning options and game status
            _ = try await supabaseClient
                .from("Parties")
                .update(updateData)
                .eq("id", value: Int(partyId))
                .execute()
            
            // 2. Calculate and update bet results
            await calculateBetResults(winningOptions: winningOptionsArray)
            
            await MainActor.run {
                self.isLoading = false
            }
            
            dismiss()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to confirm outcome: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func calculateBetResults(winningOptions: [String]) async {
        print("🔍 Starting bet results calculation with winning options: \(winningOptions)")
        
        do {
            // Fetch all user bets for this party
            let userBetsResponse = try await supabaseClient
                .from("User Bets")
                .select("id, user_id, bet_selection")
                .eq("party_id", value: Int(partyId))
                .execute()
            
            struct UserBetResult: Codable {
                let id: Int64
                let user_id: String
                let bet_selection: String // This is stored as text (comma-separated)
            }
            
            let userBets = try JSONDecoder().decode([UserBetResult].self, from: userBetsResponse.data)
            print("🔍 Found \(userBets.count) user bets to evaluate")
            
            // Calculate results for each user
            for userBet in userBets {
                // Parse the user's selection from comma-separated text
                let userSelectionArray = userBet.bet_selection.components(separatedBy: ", ").filter { !$0.isEmpty }
                let isWinner = calculateIfWinner(userSelection: userSelectionArray, winningOptions: winningOptions)
                
                print("🔍 User \(userBet.user_id) selected: \(userSelectionArray)")
                print("🔍 User \(userBet.user_id) is winner: \(isWinner)")
                
                // Update the bet with the result
                _ = try await supabaseClient
                    .from("User Bets")
                    .update(["is_winner": isWinner])
                    .eq("id", value: Int(userBet.id))
                    .execute()
                
                print("✅ Updated bet \(userBet.id) for user \(userBet.user_id): winner = \(isWinner)")
            }
            
            print("✅ Successfully calculated bet results for \(userBets.count) bets")
            
        } catch {
            print("❌ Error calculating bet results: \(error)")
            // Don't throw here to avoid disrupting the main flow
        }
    }
    
    private func calculateIfWinner(userSelection: [String], winningOptions: [String]) -> Bool {
        // Clean and normalize both user selections and winning options
        let cleanUserSelection = Set(userSelection.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        })
        
        let cleanWinningOptions = Set(winningOptions.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        })
        
        print("🔍 Comparing user selection: \(cleanUserSelection)")
        print("🔍 Against winning options: \(cleanWinningOptions)")
        
        // Check if user's selection contains any of the winning options
        let hasMatch = !cleanUserSelection.intersection(cleanWinningOptions).isEmpty
        print("🔍 Match found: \(hasMatch)")
        
        return hasMatch
    }
}
