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
    @State private var showAIVerification = false
    @State private var aiVerificationResult: String = ""
    @State private var showConfirmation = false
    
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
                                Text("Confirm Bet Outcome")
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
                                }
                            }
                            
                            // AI Verification Section
                            VStack(spacing: 16) {
                                Button(action: {
                                    Task {
                                        await askAIForVerification()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "brain.head.profile")
                                        Text("Ask AI to Verify")
                                    }
                                    .font(.system(size: 18, weight: .semibold))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    .background(Color.blue.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                
                                if !aiVerificationResult.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("AI Verification Result:")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.yellow)
                                        
                                        Text(aiVerificationResult)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))
                                            .padding()
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(10)
                                        
                                        Text("Review the AI result and make any necessary changes above.")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                            .italic()
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
                                .background(selectedWinningOptions.isEmpty ? Color.gray : Color.green.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                            }
                            .disabled(selectedWinningOptions.isEmpty)
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
    
    // Replace your askAIForVerification() function with this updated version

    private func askAIForVerification() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Create a comprehensive prompt for bet outcome verification
            let prompt = """
            You are a sports betting outcome analyzer. Analyze the following bet and determine which option(s) are correct based on current game data.

            Bet Question: \(betPrompt)
            Available Options: \(betOptions.joined(separator: ", "))

            Please research the latest game results and statistics for this bet. Then provide your analysis in the following format:

            ANALYSIS:
            [Your detailed analysis of why certain options are correct]

            CORRECT OPTIONS:
            [List the correct option(s) from the available options]

            CONFIDENCE:
            [High/Medium/Low confidence level with reasoning]

            Note: Only select options that are definitely correct based on verified game data. If you cannot verify the results, please state that clearly.
            """

            // Use your existing AIServices to get the analysis
            let aiResponse = try await AIServices.shared.sendPrompt(
                prompt,
                model: "gemini-2.5-flash",
                temperature: 0.1, // Low temperature for factual analysis
                maxTokens: 1000
            )

            // Parse the AI response to extract suggested winners
            let suggestedWinners = parseAIResponse(aiResponse)

            await MainActor.run {
                self.aiVerificationResult = aiResponse
                
                // Auto-select the AI's suggested winners if any were found
                if !suggestedWinners.isEmpty {
                    self.selectedWinningOptions = Set(suggestedWinners)
                }
                
                self.isLoading = false
            }

        } catch {
            await MainActor.run {
                let errorMsg = "AI Verification Error: \(error.localizedDescription)"
                self.aiVerificationResult = errorMsg
                self.errorMessage = errorMsg
                self.isLoading = false
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
                   trimmedLine.uppercased().contains("ANALYSIS:") {
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

    // Enhanced version with specific game data (if you have game info available)
    private func askAIForVerificationWithGameData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // You can enhance this by including specific game data if available
            let prompt = """
            You are a professional sports betting outcome analyzer with access to real-time sports data.

            BETTING DETAILS:
            Question: \(betPrompt)
            Available Options: \(betOptions.joined(separator: " | "))

            INSTRUCTIONS:
            1. Research the latest verified sports data for this specific bet
            2. Analyze each option against the actual game results
            3. Only mark options as correct if you have confirmed data
            4. If you cannot verify the results, clearly state this

            RESPONSE FORMAT:
            ANALYSIS:
            [Your detailed research and reasoning]

            VERIFIED CORRECT OPTIONS:
            [Only list options that are definitively correct based on verified data]

            CONFIDENCE LEVEL:
            [High/Medium/Low] - [Explain your confidence level]

            DATA SOURCES:
            [Mention what data you used for verification]

            Remember: Accuracy is critical. If uncertain, state that verification is not possible rather than guessing.
            """

            let aiResponse = try await AIServices.shared.sendPrompt(
                prompt,
                model: "gemini-2.5-flash",
                temperature: 0.05, // Very low temperature for maximum accuracy
                maxTokens: 1500
            )

            let suggestedWinners = parseAIResponse(aiResponse)

            await MainActor.run {
                self.aiVerificationResult = aiResponse
                
                // Only auto-select if AI expressed high confidence
                if aiResponse.lowercased().contains("high") &&
                   aiResponse.lowercased().contains("confidence") &&
                   !suggestedWinners.isEmpty {
                    self.selectedWinningOptions = Set(suggestedWinners)
                }
                
                self.isLoading = false
            }

        } catch let aiError as AIServiceError {
            await MainActor.run {
                self.aiVerificationResult = "AI Service Error: \(aiError.errorDescription ?? "Unknown error")"
                self.errorMessage = aiError.errorDescription
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.aiVerificationResult = "Verification Error: \(error.localizedDescription)"
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // Alternative function for JSON-structured response
    private func askAIForStructuredVerification() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let prompt = """
            Analyze this sports bet and return a JSON response with the verification results.

            Bet Question: \(betPrompt)
            Options: \(betOptions)

            Return JSON format:
            {
                "analysis": "Your detailed analysis",
                "correct_options": ["option1", "option2"],
                "confidence": "High/Medium/Low",
                "reasoning": "Why these options are correct",
                "data_verified": true/false
            }

            Only include options in correct_options that are definitively correct based on verified sports data.
            """

            let aiResponse = try await AIServices.shared.sendPrompt(
                prompt,
                model: "gemini-2.5-flash",
                temperature: 0.1,
                maxTokens: 800
            )

            // Try to parse JSON response
            if let jsonData = extractJSON(from: aiResponse),
               let verificationResult = try? JSONDecoder().decode(AIVerificationResult.self, from: jsonData) {
                
                await MainActor.run {
                    self.aiVerificationResult = """
                    ANALYSIS: \(verificationResult.analysis)
                    
                    CONFIDENCE: \(verificationResult.confidence)
                    
                    REASONING: \(verificationResult.reasoning)
                    
                    DATA VERIFIED: \(verificationResult.data_verified ? "Yes" : "No")
                    """
                    
                    if verificationResult.data_verified &&
                       verificationResult.confidence.lowercased() == "high" {
                        self.selectedWinningOptions = Set(verificationResult.correct_options)
                    }
                    
                    self.isLoading = false
                }
            } else {
                // Fallback to text parsing
                await MainActor.run {
                    self.aiVerificationResult = aiResponse
                    self.isLoading = false
                }
            }

        } catch {
            await MainActor.run {
                self.aiVerificationResult = "Error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    // Helper struct for JSON parsing
    private struct AIVerificationResult: Codable {
        let analysis: String
        let correct_options: [String]
        let confidence: String
        let reasoning: String
        let data_verified: Bool
    }

    // Helper function to extract JSON from AI response
    private func extractJSON(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return nil
        }
        
        let jsonString = String(text[start...end])
        return jsonString.data(using: .utf8)
    }
    
    private func generateMockAIResponse() -> String {
        // This is a mock response - replace with actual AI integration
        let responses = [
            "Based on game data analysis, the selected options appear to be correct.",
            "I recommend reviewing the final game statistics to confirm the outcome.",
            "The selected winning conditions match the expected results based on the game's final state.",
            "Please verify the game's final score and statistics to ensure accuracy."
        ]
        return responses.randomElement() ?? responses[0]
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

#Preview {
    ConfirmBetOutcomeView(
        partyId: 1,
        partyName: "Test Party",
        betOptions: ["Option A", "Option B", "Option C"],
        betPrompt: "Which team will win the game?"
    )
    .environmentObject(SessionManager(supabaseClient: SupabaseClient(
        supabaseURL: URL(string: "https://example.supabase.co")!,
        supabaseKey: "public-anon-key"
    )))
}
