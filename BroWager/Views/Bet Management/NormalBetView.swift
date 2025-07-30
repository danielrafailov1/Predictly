// Updated Bet Creation Flow with Date Selection

import SwiftUI

#Preview {
    NormalBetView(
        navPath: .constant(NavigationPath()),
        email: "preview@example.com",
        userId: UUID()
    )
}

struct NormalBetView: View {
    @Binding var navPath: NavigationPath
    let email: String
    let userId: UUID?

    @State private var aiSuggestions: [String] = []
    @State private var betPrompt: String = ""
    @State private var selectedDate = Date()
    @State private var isNextActive = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    
                    // AI Suggestions Header + Refresh Button (fixed position)
                    HStack {
                        Text("AI Suggestions: Click to fill")
                            .foregroundColor(.white)
                            .font(.title2)
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await refreshAISuggestions()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.white)
                                .font(.title2)
                                .padding(8)
                                .background(Color.blue.opacity(0.7))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Scrollable Suggestion Buttons (dynamic content in fixed height)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(aiSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    betPrompt = suggestion
                                }) {
                                    Text(suggestion)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.15))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 150) // Fixed height container
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Write your Bet")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(.vertical)
                        
                        TextEditor(text: $betPrompt)
                            .scrollContentBackground(.hidden)
                            .frame(height: 130)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                    }
                    .padding(.horizontal)
                    
                    // Date Picker Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose a date for your bet")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(.horizontal)
                        
                        DatePicker(
                            "Bet Date",
                            selection: $selectedDate,
                            in: Date()..., // Only allow future dates
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .accentColor(.blue)
                        .colorScheme(.dark) // Ensure dark theme for date picker
                        .padding(.horizontal)
                        .onChange(of: selectedDate) { _ in
                            // Refresh AI suggestions when date changes
                            Task {
                                await refreshAISuggestions()
                            }
                        }
                    }
                    
                    NavigationLink(
                        destination: BetOptionsView(
                            navPath: $navPath,
                            betPrompt: betPrompt,
                            selectedDate: selectedDate,
                            email: email,
                            userId: userId
                        ),
                        isActive: $isNextActive
                    ) {
                        EmptyView()
                    }
                    
                    Button("Next") {
                        isNextActive = true
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .onAppear(perform: loadAISuggestions)
            }
        }
    }

    @MainActor
    func loadAISuggestions() {
        Task {
            await refreshAISuggestions()
        }
    }

    @MainActor
    func refreshAISuggestions() async {
        do {
            print("Attempting to fetch AI suggestions for date: \(selectedDate)...")
            
            // Format the date for AI context
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .full
            let formattedDate = dateFormatter.string(from: selectedDate)
            
            let result = try await AIServices.shared.generateBetSuggestionsWithDate(
                betType: "sports",
                count: 5,
                targetDate: formattedDate
            )
            print("Raw AI Response: \(result)")
            aiSuggestions = result
        } catch {
            print("AI decoding error: \(error.localizedDescription)")
            
            // Fallback suggestions that are date-aware
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMMM d"
            let dateString = dateFormatter.string(from: selectedDate)
            
            aiSuggestions = [
                "Which game on \(dateString) will have the highest total score?",
                "What will happen first in the \(dateString) games: a touchdown, field goal, or turnover?",
                "Which team will score first in the prime time game on \(dateString)?",
                "Will any game on \(dateString) go into overtime?",
                "Which player will have the most rushing yards on \(dateString)?"
            ]
        }
    }
}

struct BetOptionsView: View {
    @Binding var navPath: NavigationPath
    let betPrompt: String
    let selectedDate: Date
    let email: String
    let userId: UUID?

    @State private var betOptions: [String] = []
    @State private var betTerms: String = ""
    @State private var isNextActive = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                // Date Display
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("Bet Date: \(selectedDate, style: .date)")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal)

                HStack {
                    Text("Options")
                        .foregroundColor(.white)
                        .font(.headline)
                    Spacer()
                    Button {
                        Task {
                            await generateOptions(betPrompt: betPrompt, date: selectedDate)
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                            .font(.system(size: 20))
                    }

                    Button { betOptions.append("") } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 22))
                    }
                }
                .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(betOptions.indices, id: \.self) { index in
                            HStack {
                                TextField("Option", text: $betOptions[index])
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                                Button {
                                    betOptions.remove(at: index)
                                } label: {
                                    Image(systemName: "x.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 22))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .frame(maxHeight: 200) // limit height for scrolling

                HStack {
                    Text("Terms (Penalties, Prizes, Rules)")
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        generateTerms(date: selectedDate)
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                            .font(.system(size: 20))
                    }
                }
                .padding(.horizontal)

                TextEditor(text: $betTerms)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .scrollContentBackground(.hidden)

                Spacer()

                NavigationLink(
                    destination: FinalizeBetView(
                        navPath: $navPath,
                        email: email,
                        betPrompt: betPrompt,
                        selectedDate: selectedDate,
                        betOptions: betOptions,
                        betTerms: betTerms,
                        betType: "normal",
                        userId: userId
                    ),
                    isActive: $isNextActive
                ) {
                    EmptyView()
                }
                
                Button("Next") {
                    isNextActive = true
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top)
        }
    }

    func generateOptions(betPrompt: String, date: Date) {
        Task {
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .full
                let formattedDate = dateFormatter.string(from: date)
                
                // Smart detection of bet type
                let isBinaryBet = detectBinaryBet(betPrompt)
                let optionCount = isBinaryBet ? 2 : 4 // Binary gets 2, others get 4
                
                let prompt: String
                
                if isBinaryBet {
                    prompt = """
                    Based on this bet: "\(betPrompt)" scheduled for \(formattedDate), generate exactly \(optionCount) simple, direct answer options.
                    
                    This appears to be a simple either/or question. Provide only the two most obvious choices.
                    For example:
                    - If it's "Who will win X vs Y", return: "Team X" and "Team Y"
                    - If it's "Will X happen", return: "Yes" and "No"
                    
                    Keep options short (1-4 words each) and direct. No complex scenarios or point spreads.
                    Return only the options, one per line, no numbering.
                    """
                } else {
                    prompt = """
                    Based on this bet: "\(betPrompt)" scheduled for \(formattedDate), generate exactly \(optionCount) realistic and specific options.
                    
                    Consider what's likely to happen on \(formattedDate) and create measurable outcomes.
                    Each option should be one clear sentence that can be definitively determined as true or false.
                    Keep options concise but specific enough to be interesting.
                    
                    Return only the options, one per line, no numbering or extra text.
                    """
                }

                let responseText = try await AIServices.shared.sendPrompt(
                    prompt,
                    model: "gemini-2.5-flash-lite",
                    temperature: 0.6, // Lower temperature for more focused responses
                    maxTokens: 200 // Reduced token limit to encourage brevity
                )

                // Clean and process the response
                let cleanedLines = responseText
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map {
                        // Remove common prefixes
                        $0.replacingOccurrences(of: #"^\s*[\d\-\•\*]+\.?\s*"#, with: "", options: .regularExpression)
                    }
                    .filter { $0.count > 2 && $0.count < 100 } // Reasonable length bounds

                betOptions = Array(cleanedLines.prefix(optionCount))

                // Fallback with smart defaults
                if betOptions.isEmpty {
                    betOptions = generateFallbackOptions(for: betPrompt, isBinary: isBinaryBet)
                }

            } catch {
                print("Failed to generate bet options: \(error)")
                betOptions = generateFallbackOptions(for: betPrompt, isBinary: detectBinaryBet(betPrompt))
            }
        }
    }

    // Helper function to detect if a bet is binary
    func detectBinaryBet(_ prompt: String) -> Bool {
        let lowercased = prompt.lowercased()
        
        // Check for binary indicators
        let binaryKeywords = [
            "who will win", "vs", " v ", "or", "will there be", "will it", "yes or no",
            "true or false", "happen or not", "over or under"
        ]
        
        let versusPatterns = [
            " vs? ",  // "vs" or "v"
            " versus ",
            "\\b\\w+ or \\w+\\b" // "team1 or team2"
        ]
        
        // Check for direct binary language
        for keyword in binaryKeywords {
            if lowercased.contains(keyword) {
                return true
            }
        }
        
        // Check for versus patterns with regex
        for pattern in versusPatterns {
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    func generateFallbackOptions(for prompt: String, isBinary: Bool) -> [String] {
        if isBinary {
            let lowercased = prompt.lowercased()
            
            // Try to extract team names or entities
            if lowercased.contains("who will win") {
                // Look for team names after common patterns
                if let vsRange = lowercased.range(of: " vs ") ?? lowercased.range(of: " v ") {
                    let afterVs = String(lowercased[vsRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let beforeVs = String(lowercased[..<vsRange.lowerBound])
                    
                    if let lastWord = beforeVs.components(separatedBy: " ").last,
                       let firstWord = afterVs.components(separatedBy: " ").first {
                        return [lastWord.capitalized, firstWord.capitalized]
                    }
                }
            }
            
            // Generic binary fallbacks
            if lowercased.contains("will") {
                return ["Yes", "No"]
            }
            
            return ["Option A", "Option B"]
        } else {
            // Multi-option fallbacks
            return [
                "Most likely outcome",
                "Second most likely",
                "Unexpected result",
                "Long shot possibility"
            ]
        }
    }

    func generateTerms(date: Date) {
        Task {
            do {
                let betDescription = betOptions.joined(separator: ", ")
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .full
                let formattedDate = dateFormatter.string(from: date)
                
                let prompt = """
                Generate concise, user-friendly terms and conditions for a sports bet scheduled for \(formattedDate) involving these options: \(betDescription). \
                Include date-specific considerations such as game cancellations due to weather, postponements, or schedule changes that might affect bets on \(formattedDate). \
                Use simple language suitable for users, avoid legal jargon, do not use placeholders like [Your Company], \
                and keep the response under 300 words. Make sure to address what happens if events are moved or cancelled on the target date.
                """
                
                let responseText = try await AIServices.shared.sendPrompt(
                    prompt,
                    model: "gemini-2.5-flash-lite",
                    temperature: 0.7,
                    maxTokens: 600
                )
                
                betTerms = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                
            } catch {
                print("Failed to generate bet terms: \(error)")
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                let formattedDate = dateFormatter.string(from: date)
                
                betTerms = """
                Bet is valid for games and events occurring on \(formattedDate). \
                If any scheduled games are postponed or cancelled on the target date, affected bets will be void. \
                Results will be determined based on official game statistics from \(formattedDate). \
                Weather-related cancellations or delays beyond \(formattedDate) will result in bet cancellation. \
                All participants must confirm their selections before the first scheduled event on \(formattedDate).
                """
            }
        }
    }
}

struct FinalizeBetView: View {
    @Binding var navPath: NavigationPath
    let email: String
    let betPrompt: String
    let selectedDate: Date
    let betOptions: [String]
    let betTerms: String
    let betType: String
    let userId: UUID?

    @State private var partyName: String = ""
    @State private var privacy: String = "Public"
    @State private var maxMembers: Int = 10
    @State private var terms: String = ""
    @State private var isSubmitting = false
    @State private var showPartyDetails = false
    @State private var createdPartyCode: String = ""
    @State private var errorMessage: String = ""
    
    @Environment(\.supabaseClient) private var supabaseClient

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Date Display
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.blue)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Bet Date")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                            Text(selectedDate, style: .date)
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading) {
                        Text("Enter party name")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.horizontal)
                        HStack {
                            TextField("Party Name", text: $partyName)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                            Button(action: randomizePartyName) {
                                Image(systemName: "die.face.5.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                            }
                        }.padding(.horizontal)
                    }

                    VStack(alignment: .leading) {
                        Text("Choose privacy option")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.horizontal)

                        Picker("Privacy", selection: $privacy) {
                            Text("Open").tag("Open")
                            Text("Friends Only").tag("Friends Only")
                            Text("Invite Only").tag("Invite Only")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }

                    Stepper(value: $maxMembers, in: 2...50) {
                        Text("Max Members: \(maxMembers)").foregroundColor(.white)
                    }.padding(.horizontal)

                    // Show error message if any
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Button(action: submitBet) {
                        if isSubmitting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Create Bet")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(isSubmitting)
                }
                .padding(.top)
            }
        }
        .navigationDestination(isPresented: $showPartyDetails) {
            PartyDetailsView(partyCode: createdPartyCode, email: email)
        }
    }

    func randomizePartyName() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let dateString = dateFormatter.string(from: selectedDate)
        
        let suggestions = [
            "\(dateString) Bet Bros",
            "\(dateString) Wager Warriors",
            "\(dateString) Game Day Squad",
            "\(dateString) Prediction Party",
            "\(dateString) Lock & Load",
            "\(dateString) Sure Things",
            "\(dateString) Betting Brigade",
            "\(dateString) Odds Squad",
            "\(dateString) Props & Profits",
            "\(dateString) Smart Money"
        ]

        partyName = suggestions.randomElement() ?? "My \(dateString) Party"
    }

    func submitBet() {
        guard let userId = userId else {
            print("Error: userId is nil")
            errorMessage = "User ID is missing"
            return
        }
        
        guard !partyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Error: Party name cannot be empty")
            errorMessage = "Party name cannot be empty"
            return
        }
        
        isSubmitting = true
        errorMessage = ""

        let partyCode = UUID().uuidString.prefix(6).uppercased()

        // Fix: Properly configure the DateFormatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // Use ISO date format for database
        // Alternative formats you could use:
        // dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // If you need timestamp
        // dateFormatter.dateStyle = .medium // For human-readable format
        
        let formattedDate = dateFormatter.string(from: selectedDate)
        print("🔄 Formatted date: \(formattedDate)") // Debug log to verify format
        
        let payload = PartyInsertPayload(
            created_by: userId.uuidString,
            party_name: partyName,
            privacy_option: privacy,
            max_members: maxMembers,
            bet: betPrompt,
            bet_date: formattedDate, // Now properly formatted
            bet_type: betType,
            options: betOptions,
            terms: betTerms,
            status: "open",
            party_code: String(partyCode)
        )

        Task {
            do {
                print("🔄 Creating party with code: \(partyCode) for date: \(formattedDate)")
                
                // First, insert the party
                let response = try await supabaseClient
                    .from("Parties")
                    .insert(payload)
                    .select()
                    .single()
                    .execute()

                print("✅ Raw insert response: \(String(data: response.data, encoding: .utf8) ?? "No data")")

                // Decode the response to get the party ID
                let decodedParty = try JSONDecoder().decode(Party.self, from: response.data)
                print("✅ Successfully created party: \(decodedParty)")
                
                // Now add the creator as a member to the Party Members table
                if let partyId = decodedParty.id {
                    print("🔄 Adding creator as member to party ID: \(partyId)")
                    
                    let memberPayload = PartyMemberInsert(
                        party_id: Int(partyId),
                        user_id: userId.uuidString
                    )
                    
                    let memberResponse = try await supabaseClient
                        .from("Party Members")
                        .insert(memberPayload)
                        .execute()
                    
                    print("✅ Successfully added creator as member")
                    print("✅ Member response: \(String(data: memberResponse.data, encoding: .utf8) ?? "No data")")
                } else {
                    print("⚠️ Warning: Could not get party ID from response")
                }
                
                // Navigate to PartyDetailsView
                await MainActor.run {
                    self.createdPartyCode = String(partyCode)
                    self.showPartyDetails = true
                    self.isSubmitting = false
                    print("✅ Navigation set up for party code: \(self.createdPartyCode)")
                }

            } catch {
                print("❌ Error submitting bet: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    self.isSubmitting = false
                    self.errorMessage = "Failed to create party: \(error.localizedDescription)"
                }
            }
        }
    }
}

// Extension to AIServices for date-aware suggestions
extension AIServices {
    func generateBetSuggestionsWithDate(betType: String, count: Int, targetDate: String) async throws -> [String] {
        let prompt = """
        Generate \(count) creative and engaging sports betting suggestions for \(targetDate). 
        Consider what sports events, games, or activities are likely to occur on \(targetDate).
        Make the suggestions specific to the day of the week and season.
        Each suggestion should be a complete betting question that users can answer with multiple choice options.
        Focus on \(betType) betting scenarios that would be relevant for \(targetDate).
        Return only the betting questions, one per line, without numbering or additional text.
        """
        
        let response = try await sendPrompt(
            prompt,
            model: "gemini-2.5-flash-lite",
            temperature: 0.8,
            maxTokens: 400
        )
        
        return response
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 10 }
            .prefix(count)
            .map { String($0) }
    }
}
