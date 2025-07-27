// Updated Bet Creation Flow (NormalBetView, BetOptionsView, FinalizeBetView)

import SwiftUI

struct NormalBetView: View {
    @Binding var navPath: NavigationPath
    let email: String
    let userId: UUID?

    @State private var aiSuggestions: [String] = []
    @State private var betPrompt: String = ""
    @State private var isNextActive = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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

                NavigationLink(
                    destination: BetOptionsView(navPath: $navPath, betPrompt: betPrompt, email: email, userId: userId),
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

    @MainActor
    func loadAISuggestions() {
        Task {
            await refreshAISuggestions()
        }
    }

    @MainActor
    func refreshAISuggestions() async {
        do {
            print("Attempting to fetch AI suggestions...")
            let result = try await AIServices.shared.generateBetSuggestions(betType: "sports", count: 5)
            print("Raw AI Response: \(result)")
            aiSuggestions = result
        } catch {
            print("AI decoding error: \(error.localizedDescription)")
            
            // Fallback suggestion that matches hardcoded options and terms
            aiSuggestions = [
                "Which of these game outcomes will happen: Team A wins by more than 10 points, Team B scores first, game goes into overtime, total points over 45.5, or a player scores 2+ touchdowns?"
            ]
        }
    }

}




#Preview {
    NormalBetView(
        navPath: .constant(NavigationPath()),
        email: "preview@example.com",
        userId: UUID()
    )
}

struct BetOptionsView: View {
    @Binding var navPath: NavigationPath
    let betPrompt: String
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
                HStack {
                    Text("Options")
                        .foregroundColor(.white)
                        .font(.headline)
                    Spacer()
                    Button {
                        Task {
                            await generateOptions(betPrompt: betPrompt)
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
                    Button { generateTerms() } label: {
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

    func generateOptions(betPrompt: String) {
        Task {
            do {
                let prompt = """
                Based on the following bet prompt: "\(betPrompt)", generate exactly 5 short and specific bet options. \
                Each option should be one sentence, measurable, and phrased like a realistic sports prop bet. \
                Do not include any introductory text. Only return the 5 options, one per line.
                """

                let responseText = try await AIServices.shared.sendPrompt(
                    prompt,
                    model: "gemini-2.5-flash-lite",
                    temperature: 0.7,
                    maxTokens: 300
                )

                // Split and clean the response
                let cleanedLines = responseText
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter {
                        !$0.isEmpty &&
                        !$0.lowercased().contains("option") &&
                        !$0.lowercased().contains("here") &&
                        !$0.lowercased().contains("bet prompt") &&
                        !$0.lowercased().contains("generate")
                    }
                    .map {
                        // Remove leading "1.", "-", etc.
                        $0.replacingOccurrences(of: #"^\s*[\d\-\•]+\s*"#, with: "", options: .regularExpression)
                    }
                    .filter { $0.count > 8 }  // reasonable length

                betOptions = Array(cleanedLines.prefix(5))

                if betOptions.isEmpty {
                    throw NSError(domain: "AIResponseParsing", code: 1, userInfo: [NSLocalizedDescriptionKey: "No valid options found"])
                }

            } catch {
                print("Failed to generate bet options: \(error)")
                betOptions = [
                    "Team A wins by more than 10 points",
                    "Team B scores first",
                    "Game goes into overtime",
                    "Total points over 45.5",
                    "A player scores 2 or more touchdowns"
                ]
            }
        }
    }

    func generateTerms() {
        Task {
            do {
                let betDescription = betOptions.joined(separator: ", ")
                print("Generate concise, user-friendly terms and conditions for a bet involving: \(betDescription). Use simple language, no placeholders, and keep it under 300 words.")
                
                let prompt = """
                Generate concise, user-friendly terms and conditions for a sports bet involving these options: \(betDescription). \
                Use simple language suitable for users, avoid legal jargon, do not use placeholders like [Your Company], \
                and keep the response under 300 words.
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
                betTerms = """
                If Team A wins by more than 10 points, the bettor wins. \
                If Team B scores first but loses, the bet is void. \
                Overtime bets only apply if the game officially enters overtime. \
                'Total points over 45.5' is based on final score. \
                A player scoring 2+ touchdowns must be on the starting roster.
                """
            }
        }
    }

}

struct FinalizeBetView: View {
    @Binding var navPath: NavigationPath
    let email: String
    let betPrompt: String
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
                            Text("Public").tag("Public")
                            Text("Private").tag("Private")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                    }

                    Stepper(value: $maxMembers, in: 2...50) {
                        Text("Max Members: \(maxMembers)").foregroundColor(.white)
                    }.padding(.horizontal)

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
        let suggestions = ["Bet Bros", "Wager Warriors", "Odds Squad", "Risky Business", "The Punters"]
        partyName = suggestions.randomElement() ?? "My Party"
    }

    func submitBet() {
        guard let userId = userId else {
            print("Error: userId is nil")
            return
        }
        
        guard !partyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Error: Party name cannot be empty")
            return
        }
        
        isSubmitting = true

        let partyCode = UUID().uuidString.prefix(6).uppercased()

        let payload = PartyInsertPayload(
            created_by: userId.uuidString,
            party_name: partyName,
            privacy_option: privacy,
            max_members: maxMembers,
            bet: betPrompt,
            bet_type: betType,
            options: betOptions,
            terms: betTerms,
            status: "open",
            party_code: String(partyCode)
        )

        Task {
            do {
                let response = try await supabaseClient
                    .from("Parties")
                    .insert(payload)
                    .select()
                    .single()
                    .execute()

                print("Raw insert response: \(response)")

                // Decode the response to verify creation
                let decodedParty = try JSONDecoder().decode(Party.self, from: response.data)
                print("Successfully created party: \(decodedParty)")
                
                // Navigate to PartyDetailsView
                await MainActor.run {
                    self.createdPartyCode = String(partyCode)
                    self.showPartyDetails = true
                    self.isSubmitting = false
                }

            } catch {
                print("Error submitting bet: \(error)")
                await MainActor.run {
                    self.isSubmitting = false
                }
            }
        }
    }
}
