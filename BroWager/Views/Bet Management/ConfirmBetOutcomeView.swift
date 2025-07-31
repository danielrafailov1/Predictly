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
    
    // New AI verification states
    @State private var aiVerificationStatus: [String: AIVerificationStatus] = [:]
    @State private var showAIOverrideWarning = false
    
    enum AIVerificationStatus {
        case correct      // Green checkmark ✓
        case incorrect    // Red X ✗
        case uncertain    // Orange dash –
        case notVerified  // No indicator
        
        var color: Color {
            switch self {
            case .correct: return .green
            case .incorrect: return .red
            case .uncertain: return .orange
            case .notVerified: return .clear
            }
        }
        
        var icon: String {
            switch self {
            case .correct: return "checkmark"
            case .incorrect: return "xmark"
            case .uncertain: return "minus"
            case .notVerified: return ""
            }
        }
    }
    
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
                .ignoresSafeArea(.all)
                
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
                                        Text("AI is analyzing bet outcome...")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                    .padding(.horizontal, 24)
                                }
                            }
                            
                            // AI Verification Summary
                            if !aiVerificationResult.isEmpty && !isAIVerifying {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "brain.head.profile")
                                            .foregroundColor(.yellow)
                                        Text("AI Analysis Complete")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.yellow)
                                    }
                                    
                                    // AI Verification Legend
                                    HStack(spacing: 20) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                                .font(.system(size: 12, weight: .bold))
                                            Text("Correct")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.green)
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "minus")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 12, weight: .bold))
                                            Text("Uncertain")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.orange)
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "xmark")
                                                .foregroundColor(.red)
                                                .font(.system(size: 12, weight: .bold))
                                            Text("Incorrect")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.red)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    
                                    Text("Review AI suggestions below and modify your selection if needed.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .italic()
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal, 24)
                            }
                            
                            // Options Selection with AI Indicators
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select the correct answer(s):")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                
                                ForEach(betOptions, id: \.self) { option in
                                    Button(action: {
                                        toggleOption(option)
                                    }) {
                                        HStack(spacing: 12) {
                                            // User selection indicator
                                            Image(systemName: selectedWinningOptions.contains(option) ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(selectedWinningOptions.contains(option) ? .blue : .white.opacity(0.6))
                                                .font(.system(size: 20))
                                            
                                            // Option text
                                            Text(option)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.leading)
                                            
                                            Spacer()
                                            
                                            // AI verification indicator
                                            if let status = aiVerificationStatus[option], status != .notVerified {
                                                VStack(spacing: 2) {
                                                    Image(systemName: status.icon)
                                                        .foregroundColor(status.color)
                                                        .font(.system(size: 14, weight: .bold))
                                                    
                                                    Text("AI")
                                                        .font(.system(size: 8, weight: .bold))
                                                        .foregroundColor(status.color)
                                                }
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 4)
                                                .background(status.color.opacity(0.2))
                                                .cornerRadius(6)
                                            }
                                        }
                                        .padding()
                                        .background(
                                            selectedWinningOptions.contains(option)
                                            ? Color.blue.opacity(0.2)
                                            : Color.white.opacity(0.1)
                                        )
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    selectedWinningOptions.contains(option)
                                                    ? Color.blue
                                                    : Color.white.opacity(0.2),
                                                    lineWidth: selectedWinningOptions.contains(option) ? 2 : 1
                                                )
                                        )
                                    }
                                    .padding(.horizontal, 24)
                                    .disabled(isAIVerifying)
                                }
                            }
                            
                            // User Override Warning
                            if hasUserOverride() {
                                VStack(spacing: 8) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("Manual Override Detected")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Text("Your selection differs from AI recommendations. Please double-check before confirming.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(10)
                                .padding(.horizontal, 24)
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
                            
                            // Action Buttons
                            VStack(spacing: 12) {
                                // Rerun AI Verification Button
                                if !aiVerificationResult.isEmpty {
                                    Button(action: {
                                        Task {
                                            await askAIForVerification()
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Re-run AI Analysis")
                                        }
                                        .font(.system(size: 16, weight: .semibold))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 24)
                                        .background(Color.blue.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                    .disabled(isAIVerifying)
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
                            }
                            .padding(.top, 20)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            Task {
                await loadBetDate()
                await askAIForVerification()
            }
            
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
            let overrideText = hasUserOverride() ? " Note: Your selection differs from AI recommendations." : ""
            Text("Are you sure these are the correct winning options? This action cannot be undone.\(overrideText)")
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleOption(_ option: String) {
        if selectedWinningOptions.contains(option) {
            selectedWinningOptions.remove(option)
        } else {
            selectedWinningOptions.insert(option)
        }
    }
    
    private func hasUserOverride() -> Bool {
        // Check if user's selection differs from AI recommendations
        let aiCorrectOptions = aiVerificationStatus.compactMap { key, value in
            value == .correct ? key : nil
        }
        
        let aiCorrectSet = Set(aiCorrectOptions)
        return !aiCorrectSet.isEmpty && selectedWinningOptions != aiCorrectSet
    }
    
    // MARK: - Data Loading
    
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
    
    // MARK: - AI Verification
    
    private func askAIForVerification() async {
        print("\n🔍 === STARTING AI VERIFICATION ===")
        
        await MainActor.run {
            isAIVerifying = true
            errorMessage = nil
            aiVerificationStatus = [:]
        }
        
        do {
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
            
            print("🔍 Bet Date: \(partyDate.bet_date)")
            print("🔍 Bet Prompt: \(betPrompt)")
            print("🔍 Bet Options: \(betOptions)")
            
            let prompt = """
            You are a sports betting outcome analyzer with access to real-time sports data. Analyze the following bet for the specific date and determine the status of each option.

            Bet Date: \(partyDate.bet_date)
            Bet Question: \(betPrompt)
            Available Options: \(betOptions.numbered())

            IMPORTANT: Only analyze games and events that occurred on \(partyDate.bet_date). Do not use data from other dates.

            Please research the game results and statistics specifically for \(partyDate.bet_date). Then provide your analysis in the following format:

            ANALYSIS:
            [Your detailed analysis of the game/event results from \(partyDate.bet_date)]

            OPTION VERIFICATION:
            For each option, classify as CORRECT, INCORRECT, or UNCERTAIN:
            \(betOptions.enumerated().map { "Option \($0.offset + 1): \($0.element) - [CORRECT/INCORRECT/UNCERTAIN]" }.joined(separator: "\n"))

            EXPLANATION:
            [Explain your reasoning for each option's classification]

            CONFIDENCE:
            [High/Medium/Low confidence level with reasoning]

            DATE VERIFICATION:
            [Confirm that your analysis is based on events from \(partyDate.bet_date) specifically]

            Note: 
            - CORRECT: The option is definitely true based on verified results
            - INCORRECT: The option is definitely false based on verified results  
            - UNCERTAIN: Cannot verify with confidence due to insufficient data or ambiguity
            """

            print("\n🔍 === SENDING PROMPT TO AI ===")
            print("🔍 Prompt: \(prompt)")
            print("\n🔍 === WAITING FOR AI RESPONSE ===")

            let aiResponse = try await AIServices.shared.sendPrompt(
                prompt,
                model: "gemini-2.5-flash",
                temperature: 0.1,
                maxTokens: 1500
            )

            print("\n🔍 === AI RESPONSE RECEIVED ===")
            print("🔍 Full AI Response: \(aiResponse)")
            print("🔍 Response Length: \(aiResponse.count) characters")

            let (verificationStatus, autoSelections) = parseAIVerificationResponse(aiResponse)

            print("\n🔍 === PARSING RESULTS ===")
            print("🔍 Final Verification Status: \(verificationStatus)")
            print("🔍 Auto-selections from AI: \(autoSelections)")

            await MainActor.run {
                self.aiVerificationResult = aiResponse
                self.aiVerificationStatus = verificationStatus
                
                // Auto-select AI's correct options
                self.selectedWinningOptions = Set(autoSelections)
                self.isAIVerifying = false
            }

        } catch {
            print("❌ AI Verification Error: \(error)")
            await MainActor.run {
                let errorMsg = "AI Verification Error: \(error.localizedDescription)"
                self.aiVerificationResult = errorMsg
                self.errorMessage = errorMsg
                self.isAIVerifying = false
            }
        }
        
        print("🔍 === AI VERIFICATION COMPLETE ===\n")
    }
    
    private func parseAIVerificationResponse(_ response: String) -> ([String: AIVerificationStatus], [String]) {
        print("\n🔍 === PARSING AI RESPONSE ===")
        
        var verificationStatus: [String: AIVerificationStatus] = [:]
        var autoSelections: [String] = []
        
        let lines = response.components(separatedBy: .newlines)
        var inVerificationSection = false
        
        print("🔍 Total lines in response: \(lines.count)")
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("🔍 Line \(lineIndex): '\(trimmedLine)'")
            
            if trimmedLine.uppercased().contains("OPTION VERIFICATION") {
                print("🟢 Found OPTION VERIFICATION section at line \(lineIndex)")
                inVerificationSection = true
                continue
            }
            
            if inVerificationSection {
                if trimmedLine.uppercased().contains("EXPLANATION:") ||
                   trimmedLine.uppercased().contains("CONFIDENCE:") ||
                   trimmedLine.uppercased().contains("DATE VERIFICATION:") {
                    print("🟡 Exiting verification section at line \(lineIndex) due to: \(trimmedLine)")
                    break
                }
                
                // Parse option verification lines
                for (index, option) in betOptions.enumerated() {
                    let optionPattern = "Option \\(index + 1):"
                    
                    print("🔍 Checking line for option \(index + 1) (\(option)): '\(trimmedLine)'")
                    print("🔍 Looking for pattern: \(optionPattern)")
                    
                    if trimmedLine.range(of: optionPattern, options: .regularExpression) != nil {
                        print("🟢 Found match for Option \(index + 1)")
                        
                        if trimmedLine.uppercased().contains("CORRECT") {
                            verificationStatus[option] = .correct
                            autoSelections.append(option)
                            print("✅ AI marked as CORRECT: \(option)")
                        } else if trimmedLine.uppercased().contains("INCORRECT") {
                            verificationStatus[option] = .incorrect
                            print("❌ AI marked as INCORRECT: \(option)")
                        } else if trimmedLine.uppercased().contains("UNCERTAIN") {
                            verificationStatus[option] = .uncertain
                            print("🟡 AI marked as UNCERTAIN: \(option)")
                        } else {
                            print("⚠️ No classification found in line: '\(trimmedLine)'")
                        }
                        break
                    }
                }
            }
        }
        
        print("\n🔍 === AFTER STRUCTURED PARSING ===")
        print("🔍 Verification Status: \(verificationStatus)")
        print("🔍 Auto-selections: \(autoSelections)")
        
        // Fallback parsing if structured format wasn't found
        if verificationStatus.isEmpty {
            print("\n🔍 === ATTEMPTING FALLBACK PARSING ===")
            
            for (index, option) in betOptions.enumerated() {
                let optionLower = option.lowercased()
                let responseLower = response.lowercased()
                
                print("🔍 Fallback check for option \(index + 1): '\(option)'")
                print("🔍 Option lowercase: '\(optionLower)'")
                
                // Check if the option appears in the response
                if responseLower.contains(optionLower) {
                    print("🟢 Option found in response")
                    
                    // Look for classification words near the option
                    let optionRange = responseLower.range(of: optionLower)!
                    let contextStart = max(optionRange.lowerBound.utf16Offset(in: responseLower) - 100, 0)
                    let contextEnd = min(optionRange.upperBound.utf16Offset(in: responseLower) + 100, responseLower.count)
                    
                    let startIndex = responseLower.index(responseLower.startIndex, offsetBy: contextStart)
                    let endIndex = responseLower.index(responseLower.startIndex, offsetBy: contextEnd)
                    let context = String(responseLower[startIndex..<endIndex])
                    
                    print("🔍 Context around option: '\(context)'")
                    
                    if context.contains("correct") {
                        verificationStatus[option] = .correct
                        autoSelections.append(option)
                        print("✅ Fallback: AI marked as CORRECT: \(option)")
                    } else if context.contains("incorrect") {
                        verificationStatus[option] = .incorrect
                        print("❌ Fallback: AI marked as INCORRECT: \(option)")
                    } else if context.contains("uncertain") {
                        verificationStatus[option] = .uncertain
                        print("🟡 Fallback: AI marked as UNCERTAIN: \(option)")
                    } else {
                        verificationStatus[option] = .uncertain
                        print("⚠️ Fallback: No clear classification, defaulting to UNCERTAIN: \(option)")
                    }
                } else {
                    print("❌ Option not found in response, marking as UNCERTAIN: \(option)")
                    verificationStatus[option] = .uncertain
                }
            }
        }
        
        // Set any unverified options to notVerified
        for option in betOptions {
            if verificationStatus[option] == nil {
                print("⚠️ Option not processed, setting to notVerified: \(option)")
                verificationStatus[option] = .notVerified
            }
        }
        
        print("\n🔍 === FINAL PARSING RESULTS ===")
        print("🔍 Final Verification Status: \(verificationStatus)")
        print("🔍 Final Auto-selections: \(autoSelections)")
        
        // Additional debug: Check if we have any correct options
        let correctCount = verificationStatus.values.filter { $0 == .correct }.count
        let incorrectCount = verificationStatus.values.filter { $0 == .incorrect }.count
        let uncertainCount = verificationStatus.values.filter { $0 == .uncertain }.count
        let notVerifiedCount = verificationStatus.values.filter { $0 == .notVerified }.count
        
        print("🔍 Classification Summary:")
        print("  - Correct: \(correctCount)")
        print("  - Incorrect: \(incorrectCount)")
        print("  - Uncertain: \(uncertainCount)")
        print("  - Not Verified: \(notVerifiedCount)")
        
        return (verificationStatus, autoSelections)
    }
    
    // MARK: - Bet Confirmation
    
    private func confirmBetOutcome() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let winningOptionsArray = Array(selectedWinningOptions)
            
            struct PartyUpdate: Codable {
                let winning_options: [String]
                let game_status: String
            }
            
            let updateData = PartyUpdate(
                winning_options: winningOptionsArray,
                game_status: "ended"
            )
            
            _ = try await supabaseClient
                .from("Parties")
                .update(updateData)
                .eq("id", value: Int(partyId))
                .execute()
            
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
            let userBetsResponse = try await supabaseClient
                .from("User Bets")
                .select("id, user_id, bet_selection")
                .eq("party_id", value: Int(partyId))
                .execute()
            
            struct UserBetResult: Codable {
                let id: Int64
                let user_id: String
                let bet_selection: String
            }
            
            let userBets = try JSONDecoder().decode([UserBetResult].self, from: userBetsResponse.data)
            print("🔍 Found \(userBets.count) user bets to evaluate")
            
            for userBet in userBets {
                let userSelectionArray = userBet.bet_selection.components(separatedBy: ", ").filter { !$0.isEmpty }
                let isWinner = calculateIfWinner(userSelection: userSelectionArray, winningOptions: winningOptions)
                
                print("🔍 User \(userBet.user_id) selected: \(userSelectionArray)")
                print("🔍 User \(userBet.user_id) is winner: \(isWinner)")
                
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
        }
    }
    
    private func calculateIfWinner(userSelection: [String], winningOptions: [String]) -> Bool {
        let cleanUserSelection = Set(userSelection.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        
        let cleanWinningOptions = Set(winningOptions.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        
        print("🔍 Comparing user selection: \(cleanUserSelection)")
        print("🔍 Against winning options: \(cleanWinningOptions)")
        
        let hasMatch = !cleanUserSelection.intersection(cleanWinningOptions).isEmpty
        print("🔍 Match found: \(hasMatch)")
        
        return hasMatch
    }
}

// MARK: - Extensions

extension Array where Element == String {
    func numbered() -> String {
        return self.enumerated().map { "Option \($0.offset + 1): \($0.element)" }.joined(separator: "\n")
    }
}
