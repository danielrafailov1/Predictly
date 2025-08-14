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
    
    // Enhanced AI verification states
    @State private var aiVerificationStatus: [String: AIVerificationStatus] = [:]
    @State private var showAIOverrideWarning = false
    @State private var searchResults: String = ""
    @State private var searchQuery: String = ""
    @State private var showDetailedAnalysis = false
    
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
                                        Text("Challenge Date: \(betDate, style: .date)")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.top, 20)
                            
                            // Bet Prompt
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Challenge Question:")
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
                            
                            // Enhanced AI Verification Status
                            if isAIVerifying {
                                VStack(spacing: 12) {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                            .scaleEffect(0.8)
                                        Text("AI is searching and analyzing...")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    if !searchQuery.isEmpty {
                                        Text("Search: \(searchQuery)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.blue.opacity(0.8))
                                            .italic()
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal, 24)
                            }
                            
                            // Enhanced AI Analysis Display (when complete)
                            if !aiVerificationResult.isEmpty && !isAIVerifying {
                                VStack(spacing: 12) {
                                    // Quick Summary Header
                                    HStack {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.green)
                                        Text("AI Analysis Complete")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        // Status indicators
                                        let statusCounts = getStatusCounts()
                                        
                                        HStack(spacing: 8) {
                                            if statusCounts.correct > 0 {
                                                StatusBadge(count: statusCounts.correct, type: .correct)
                                            }
                                            
                                            if statusCounts.uncertain > 0 {
                                                StatusBadge(count: statusCounts.uncertain, type: .uncertain)
                                            }
                                            
                                            if statusCounts.incorrect > 0 {
                                                StatusBadge(count: statusCounts.incorrect, type: .incorrect)
                                            }
                                        }
                                    }
                                    
                                    // AI Legend
                                    HStack(spacing: 20) {
                                        LegendItem(icon: "checkmark", text: "Correct", color: .green)
                                        LegendItem(icon: "minus", text: "Uncertain", color: .orange)
                                        LegendItem(icon: "xmark", text: "Incorrect", color: .red)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    
                                    // Detailed Analysis (expandable)
                                    AIAnalysisDetailView(
                                        analysis: aiVerificationResult,
                                        searchQuery: searchQuery,
                                        isExpanded: showDetailedAnalysis,
                                        onToggle: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                showDetailedAnalysis.toggle()
                                            }
                                        }
                                    )
                                    
                                    Text("AI analyzed live search results. Review suggestions and modify if needed.")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
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
                                    
                                    Text("Your selection differs from AI recommendations based on search results. Please double-check before confirming.")
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
                                            await performSearchBasedAIVerification()
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Re-run Search & Analysis")
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
                await performSearchBasedAIVerification()
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
            let overrideText = hasUserOverride() ? " Note: Your selection differs from AI recommendations based on search data." : ""
            Text("Are you sure these are the correct winning options? This action cannot be undone.\(overrideText)")
        }
    }
    
    // MARK: - Helper Views
    struct StatusBadge: View {
        let count: Int
        let type: BadgeType
        
        enum BadgeType {
            case correct, incorrect, uncertain
            
            var color: Color {
                switch self {
                case .correct: return .green
                case .incorrect: return .red
                case .uncertain: return .orange
                }
            }
            
            var icon: String {
                switch self {
                case .correct: return "checkmark"
                case .incorrect: return "xmark"
                case .uncertain: return "minus"
                }
            }
        }
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                    .font(.system(size: 10, weight: .bold))
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(type.color)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(type.color.opacity(0.2))
            .cornerRadius(4)
        }
    }
    
    struct LegendItem: View {
        let icon: String
        let text: String
        let color: Color
        
        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12, weight: .bold))
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
            }
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
    
    private func getStatusCounts() -> (correct: Int, incorrect: Int, uncertain: Int) {
        var correct = 0
        var incorrect = 0
        var uncertain = 0
        
        for (_, status) in aiVerificationStatus {
            switch status {
            case .correct:
                correct += 1
            case .incorrect:
                incorrect += 1
            case .uncertain:
                uncertain += 1
            case .notVerified:
                break
            }
        }
        
        return (correct, incorrect, uncertain)
    }
    
    // MARK: - Data Loading
    
    private func loadBetDate() async {
        do {
            let response = try await supabaseClient
                .from("Parties")
                .select("bet_date, created_at") // Also fetch created_at as fallback
                .eq("id", value: Int(partyId))
                .single()
                .execute()
            
            struct PartyDateResponse: Codable {
                let bet_date: String?  // Made optional
                let created_at: String? // Fallback option
            }
            
            let partyDateResponse = try JSONDecoder().decode(PartyDateResponse.self, from: response.data)
            
            let dateFormatter = ISO8601DateFormatter()
            
            // Try bet_date first, then created_at as fallback
            var parsedDate: Date?
            
            if let betDateString = partyDateResponse.bet_date {
                parsedDate = dateFormatter.date(from: betDateString)
            } else if let createdAtString = partyDateResponse.created_at {
                parsedDate = dateFormatter.date(from: createdAtString)
                print("⚠️ Using created_at as fallback for bet_date")
            }
            
            await MainActor.run {
                self.betDate = parsedDate
            }
            
            if parsedDate == nil {
                print("⚠️ Could not parse any date from bet_date or created_at")
            }
            
        } catch {
            print("Error loading bet date: \(error)")
            // Set to current date as ultimate fallback
            await MainActor.run {
                self.betDate = Date()
            }
        }
    }
    
    // MARK: - Enhanced Search-Based AI Verification
    
    private func performSearchBasedAIVerification() async {
        print("\n🔍 === STARTING ENHANCED SEARCH-BASED AI VERIFICATION ===")
        
        await MainActor.run {
            isAIVerifying = true
            errorMessage = nil
            aiVerificationStatus = [:]
            searchResults = ""
            searchQuery = ""
        }
        
        do {
            // Get bet date with better validation and fallback options
            let partyResponse = try await supabaseClient
                .from("Parties")
                .select("bet_date, created_at, bet")
                .eq("id", value: Int(partyId))
                .single()
                .execute()
            
            struct PartyInfo: Codable {
                let bet_date: String?
                let created_at: String?
                let bet: String?
            }
            
            let partyInfo = try JSONDecoder().decode(PartyInfo.self, from: partyResponse.data)
            
            // Determine which date to use
            var effectiveDate: Date
            var dateSource: String
            
            let dateFormatter = ISO8601DateFormatter()
            
            if let betDateString = partyInfo.bet_date,
               let betDate = dateFormatter.date(from: betDateString) {
                effectiveDate = betDate
                dateSource = "bet_date"
                print("✅ Using bet_date: \(betDateString)")
            } else if let createdAtString = partyInfo.created_at,
                      let createdAtDate = dateFormatter.date(from: createdAtString) {
                effectiveDate = createdAtDate
                dateSource = "created_at (fallback)"
                print("⚠️ bet_date is null, using created_at: \(createdAtString)")
            } else {
                effectiveDate = Date()
                dateSource = "current date (ultimate fallback)"
                print("⚠️ Both bet_date and created_at are null or invalid, using current date")
            }
            
            print("🔍 Effective date: \(effectiveDate), Source: \(dateSource)")
            
            // Enhanced date checking with timezone consideration
            let now = Date()
            let calendar = Calendar.current
            
            // Check if bet date is today or in the past (more lenient)
            let betDateComponents = calendar.dateComponents([.year, .month, .day], from: effectiveDate)
            let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)
            
            if let betDateOnly = calendar.date(from: betDateComponents),
               let currentDateOnly = calendar.date(from: nowComponents) {
                
                if betDateOnly > currentDateOnly {
                    print("⚠️ Effective date is in the future: \(effectiveDate)")
                    
                    await MainActor.run {
                        self.aiVerificationResult = "This bet is for a future date (\(effectiveDate.formatted(date: .abbreviated, time: .omitted))). Game results are not yet available."
                        for option in self.betOptions {
                            self.aiVerificationStatus[option] = .uncertain
                        }
                        self.isAIVerifying = false
                    }
                    return
                } else if betDateOnly == currentDateOnly {
                    print("✅ Effective date is today - results may be available")
                } else {
                    print("✅ Effective date is in the past - results should be available")
                }
            }
            
            // Enhanced search with multiple strategies
            var searchResults = ""
            var finalSearchQuery = ""
            var searchAttempts = 0
            let maxAttempts = 3
            
            let effectiveDateString = dateFormatter.string(from: effectiveDate)
            let searchStrategies = generateMultipleSearchStrategies(betPrompt: betPrompt, betDate: effectiveDateString)
            
            for strategy in searchStrategies {
                searchAttempts += 1
                print("🔍 Search attempt \(searchAttempts): \(strategy)")
                
                await MainActor.run {
                    self.searchQuery = strategy
                }
                
                do {
                    let results = try await AIServices.shared.performGoogleCustomSearch(
                        query: strategy,
                        numResults: 8 // Increased for better results
                    )
                    
                    // Check if results are relevant
                    if isSearchResultRelevant(results, for: betPrompt, date: effectiveDateString) {
                        searchResults = results
                        finalSearchQuery = strategy
                        print("✅ Found relevant results with strategy \(searchAttempts)")
                        break
                    } else {
                        print("⚠️ Strategy \(searchAttempts) returned irrelevant results")
                    }
                    
                } catch {
                    print("❌ Search strategy \(searchAttempts) failed: \(error)")
                    continue
                }
                
                if searchAttempts >= maxAttempts {
                    break
                }
            }
            
            await MainActor.run {
                self.searchResults = searchResults
                self.searchQuery = finalSearchQuery
            }
            
            // Enhanced AI analysis prompt
            let analysisPrompt = createEnhancedAnalysisPrompt(
                betPrompt: betPrompt,
                betOptions: betOptions,
                betDate: effectiveDateString,
                searchResults: searchResults,
                searchQuery: finalSearchQuery
            )
            
            print("\n🔍 === SENDING ENHANCED PROMPT TO AI ===")
            print("🔍 Prompt length: \(analysisPrompt.count) characters")
            
            let aiResponse = try await AIServices.shared.sendPrompt(
                analysisPrompt,
                model: "gemini-2.5-flash",
                temperature: 0.1,
                maxTokens: 2000
            )
            
            print("\n🔍 === AI ANALYSIS RESPONSE RECEIVED ===")
            print("🔍 Response: \(aiResponse)")
            
            let (verificationStatus, autoSelections) = parseAIVerificationResponse(aiResponse)
            
            await MainActor.run {
                self.aiVerificationResult = aiResponse
                self.aiVerificationStatus = verificationStatus
                self.selectedWinningOptions = Set(autoSelections)
                self.isAIVerifying = false
            }
            
        } catch {
            print("❌ Enhanced AI Verification Error: \(error)")
            
            // Provide more specific error information
            let errorDescription: String
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .valueNotFound(let type, let context):
                    errorDescription = "Missing field '\(context.codingPath.first?.stringValue ?? "unknown")' in database. This field might be null or not exist."
                case .keyNotFound(let key, _):
                    errorDescription = "Database field '\(key.stringValue)' not found in table."
                default:
                    errorDescription = "Database structure mismatch: \(decodingError.localizedDescription)"
                }
            } else {
                errorDescription = error.localizedDescription
            }
            
            await MainActor.run {
                let errorMsg = "AI Verification temporarily unavailable: \(errorDescription)"
                self.aiVerificationResult = "AI verification could not complete due to missing bet date information. You can still manually select the winning options below."
                self.errorMessage = errorMsg
                self.isAIVerifying = false
                
                // Set all options to uncertain since we can't verify
                for option in self.betOptions {
                    self.aiVerificationStatus[option] = .uncertain
                }
            }
        }
        
        print("🔍 === ENHANCED AI VERIFICATION COMPLETE ===\n")
    }
    
    // MARK: - Multiple Search Strategies
    private func generateMultipleSearchStrategies(betPrompt: String, betDate: String) -> [String] {
        let dateFormatter = ISO8601DateFormatter()
        var strategies: [String] = []
        
        // Parse date for day context
        var dayDescription = ""
        var monthDay = ""
        
        if let date = dateFormatter.date(from: betDate) {
            let calendar = Calendar.current
            let now = Date()
            
            // Determine relative day description
            if calendar.isDate(date, inSameDayAs: now) {
                dayDescription = "today"
            } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
                dayDescription = "yesterday"
            } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now) ?? now) {
                dayDescription = "tomorrow"
            }
            
            let monthDayFormatter = DateFormatter()
            monthDayFormatter.dateFormat = "MMMM d"
            monthDay = monthDayFormatter.string(from: date)
        }
        
        // Strategy 1: Use the bet prompt exactly as is
        strategies.append(betPrompt)
        
        // Strategy 2: Add "result" or "score" to the bet prompt
        strategies.append("\(betPrompt) result")
        strategies.append("\(betPrompt) score")
        
        // Strategy 3: Add date context if available
        if !dayDescription.isEmpty {
            strategies.append("\(betPrompt) \(dayDescription)")
        }
        if !monthDay.isEmpty {
            strategies.append("\(betPrompt) \(monthDay)")
        }
        
        // Strategy 4: Add "final score" for games
        if betPrompt.lowercased().contains("game") {
            strategies.append("\(betPrompt) final score")
        }
        
        return strategies.filter { !$0.isEmpty }
    }
    
    // MARK: - Search Result Relevance Check
    private func isSearchResultRelevant(_ results: String, for betPrompt: String, date: String) -> Bool {
        let resultsLower = results.lowercased()
        let promptLower = betPrompt.lowercased()
        
        // Check for irrelevant content
        let irrelevantTerms = [
            "sitemap", "fbi.gov", "privacy policy", "terms of service",
            "404 error", "page not found", "coming soon", "under construction"
        ]
        for term in irrelevantTerms {
            if resultsLower.contains(term) {
                return false
            }
        }
        
        // Combine whitespaces and punctuation characters to split on
        let delimiters = CharacterSet.whitespaces.union(CharacterSet.punctuationCharacters)
        
        // Extract key terms from the bet prompt
        let promptWords = promptLower.components(separatedBy: delimiters)
            .filter { $0.count > 2 } // Filter out short words like "vs", "who", etc.
        
        // Check if search results contain key terms from the bet prompt
        var keyTermsFound = 0
        for word in promptWords {
            if resultsLower.contains(word) {
                keyTermsFound += 1
            }
        }
        
        // Require at least half the key terms to be present
        let relevanceThreshold = max(1, promptWords.count / 2)
        let isRelevant = keyTermsFound >= relevanceThreshold
        
        print("🔍 Relevance check:")
        print("🔍 Key terms from prompt: \(promptWords)")
        print("🔍 Terms found in results: \(keyTermsFound)/\(promptWords.count)")
        print("🔍 Threshold: \(relevanceThreshold)")
        print("🔍 Is relevant: \(isRelevant)")
        
        return isRelevant && results.count > 100 // Also require substantial content
    }

    // MARK: - Enhanced Analysis Prompt
    private func createEnhancedAnalysisPrompt(betPrompt: String, betOptions: [String], betDate: String, searchResults: String, searchQuery: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        var readableDate = betDate
        var dayContext = ""
        
        if let date = dateFormatter.date(from: betDate) {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            readableDate = formatter.string(from: date)
            
            // Add day context
            let calendar = Calendar.current
            let now = Date()
            
            if calendar.isDate(date, inSameDayAs: now) {
                dayContext = " (TODAY'S GAME)"
            } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
                dayContext = " (YESTERDAY'S GAME)"
            } else if date < now {
                dayContext = " (PAST GAME)"
            } else {
                dayContext = " (FUTURE GAME - may not have results yet)"
            }
        }
        
        return """
        You are a professional sports outcome verifier analyzing search results for a specific bet. Your job is to find the EXACT outcome of this game and determine which option won.

        BET DETAILS:
        - Date: \(readableDate)\(dayContext)
        - Question: \(betPrompt)
        - Options: \(betOptions.enumerated().map { "Option \($0.offset + 1): \($0.element)" }.joined(separator: " | "))

        SEARCH QUERY: "\(searchQuery)"

        LIVE SEARCH RESULTS:
        \(searchResults)

        ANALYSIS INSTRUCTIONS:
        1. Look for SPECIFIC final scores, game results, or match outcomes
        2. Check for phrases like "final score", "won", "victory", "defeated", "beat", "game recap"
        3. Pay attention to score formats like "9-8", "Team A 5, Team B 3", "W 9-8", etc.
        4. ESPN results are highly reliable - trust clear ESPN game recaps and scores
        5. Only mark as CORRECT if you find clear evidence of that team/option winning
        6. Mark as INCORRECT if evidence shows the other option won
        7. Use UNCERTAIN only if genuinely no outcome information is available

        IMPORTANT: Be decisive when you find clear game results. Don't be overly cautious.

        REQUIRED RESPONSE FORMAT:

        SEARCH ANALYSIS:
        [What specific game information did you find? Quote exact scores or results.]

        OPTION VERIFICATION:
        \(betOptions.enumerated().map { "Option \($0.offset + 1): \($0.element) - [CORRECT/INCORRECT/UNCERTAIN]" }.joined(separator: "\n"))

        EVIDENCE FROM SEARCH:
        [Quote the specific text that shows the winner, including the source]

        CONFIDENCE:
        [High/Medium/Low] - [Why this confidence level?]
        """
    }
    
    private func parseAIVerificationResponse(_ response: String) -> ([String: AIVerificationStatus], [String]) {
        print("\n🔍 === PARSING SEARCH-BASED AI RESPONSE ===")
        
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
                if trimmedLine.uppercased().contains("EVIDENCE FROM SEARCH:") ||
                   trimmedLine.uppercased().contains("CONFIDENCE:") ||
                   trimmedLine.uppercased().contains("SEARCH QUERY USED:") {
                    print("🟡 Exiting verification section at line \(lineIndex) due to: \(trimmedLine)")
                    break
                }
                
                // Parse option verification lines - FIXED PATTERN
                for (index, option) in betOptions.enumerated() {
                    let optionNumber = index + 1
                    let optionPattern = "Option \(optionNumber):"
                    
                    print("🔍 Checking line for option \(optionNumber) (\(option)): '\(trimmedLine)'")
                    print("🔍 Looking for pattern: \(optionPattern)")
                    
                    // Use contains instead of regex for more reliable matching
                    if trimmedLine.contains(optionPattern) {
                        print("🟢 Found match for Option \(optionNumber)")
                        
                        let lineUpper = trimmedLine.uppercased()
                        if lineUpper.contains("CORRECT") && !lineUpper.contains("INCORRECT") {
                            verificationStatus[option] = .correct
                            autoSelections.append(option)
                            print("✅ AI marked as CORRECT: \(option)")
                        } else if lineUpper.contains("INCORRECT") {
                            verificationStatus[option] = .incorrect
                            print("❌ AI marked as INCORRECT: \(option)")
                        } else if lineUpper.contains("UNCERTAIN") {
                            verificationStatus[option] = .uncertain
                            print("🟡 AI marked as UNCERTAIN: \(option)")
                        } else {
                            print("⚠️ No classification found in line: '\(trimmedLine)'")
                            verificationStatus[option] = .uncertain
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
                
                if responseLower.contains(optionLower) {
                    print("🟢 Option found in response")
                    
                    let optionRange = responseLower.range(of: optionLower)!
                    let contextStart = max(optionRange.lowerBound.utf16Offset(in: responseLower) - 100, 0)
                    let contextEnd = min(optionRange.upperBound.utf16Offset(in: responseLower) + 100, responseLower.count)
                    
                    let startIndex = responseLower.index(responseLower.startIndex, offsetBy: contextStart)
                    let endIndex = responseLower.index(responseLower.startIndex, offsetBy: contextEnd)
                    let context = String(responseLower[startIndex..<endIndex])
                    
                    print("🔍 Context around option: '\(context)'")
                    
                    if context.contains("correct") && !context.contains("incorrect") {
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
        
        // Set any unverified options to uncertain
        for option in betOptions {
            if verificationStatus[option] == nil {
                print("⚠️ Option not processed, setting to uncertain: \(option)")
                verificationStatus[option] = .uncertain
            }
        }
        
        print("\n🔍 === FINAL SEARCH-BASED PARSING RESULTS ===")
        print("🔍 Final Verification Status: \(verificationStatus)")
        print("🔍 Final Auto-selections: \(autoSelections)")
        
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
