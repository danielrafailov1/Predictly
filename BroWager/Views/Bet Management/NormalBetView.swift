import SwiftUI

struct NormalBetView: View {
    @Binding var navPath: NavigationPath
    let email: String
    @State private var aiBets: [String] = []
    @State private var customBet: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: ErrorMessage?
    @State private var longPressedBet: Bet? = nil

    // Error message struct to conform to Identifiable
    struct ErrorMessage: Identifiable {
        var id = UUID() // UUID to make it identifiable
        var message: String
    }

    // Identifiable Bet struct
    struct Bet: Identifiable {
        var id = UUID()  // Unique ID to make it identifiable
        var text: String
    }

    // Call to fetch AI-generated bets
    private func generateBets() async {
        isLoading = true
        errorMessage = nil

        let prompt = """
        Generate 5 fun bet ideas. For example: Will it rain tomorrow?, Who will be the next president?, Who will win the next basketball game? etc. Separate each suggestion with a comma and make each suggestion between 5 and 7 words long
        """

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyAunbuh_N_W_mkRpvKIosu-TDajJvJO8Q8") else {
            print("[NormalBetView] Invalid Gemini API URL.")
            errorMessage = ErrorMessage(message: "Invalid URL")
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
            if let responseJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let candidates = responseJSON["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    // Split by commas and trim whitespace
                    aiBets = text.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                } else {
                    errorMessage = ErrorMessage(message: "AI response missing expected structure. Using fallback.")
                    aiBets = fallbackBets()
                }
            } else {
                errorMessage = ErrorMessage(message: "Failed to parse AI response. Using fallback.")
                aiBets = fallbackBets()
            }
        } catch {
            errorMessage = ErrorMessage(message: "Error fetching AI bets: \(error). Using fallback.")
            aiBets = fallbackBets()
        }

        isLoading = false
    }

    // Fallback bets if AI fails
    private func fallbackBets() -> [String] {
        return [
            "Who will score the first goal?",
            "Which team will have the most penalties?",
            "How many goals will be scored in total?",
            "Will there be a penalty shootout?",
            "Will there be a red card in the match?"
        ]
    }

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Suggestions Header with Refresh Button
                HStack {
                    Text("Suggestions")
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        Task {
                            await generateBets() // Refresh the AI suggestions
                        }
                    }) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                    }
                }
                .padding(.top, 16) // Reduced padding to move content up
                .padding(.horizontal, 24)

                // AI Bets List (non-scrolling)
                if isLoading {
                    ProgressView("Loading AI Bets...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .padding(.top, 16)
                } else {
                    VStack(spacing: 12) {
                        ForEach(aiBets, id: \.self) { bet in
                            let betObject = Bet(text: bet)  // Create Bet object for each bet

                            Button(action: {
                                customBet = bet // Autofill the bet when clicked
                            }) {
                                Text(bet)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(14)
                                    .frame(maxWidth: .infinity) // Ensure uniform width
                                    .background(Color.gray.opacity(0.4))
                                    .cornerRadius(12)
                                    .padding(.horizontal, 24)
                            }
                            .gesture(
                                LongPressGesture(minimumDuration: 1.0)  // 1 second for long press
                                    .onEnded { _ in
                                        longPressedBet = betObject  // Set the long-pressed bet object
                                    }
                            )
                            .popover(item: $longPressedBet) { bet in  // Now using the Identifiable Bet object
                                VStack {
                                    Text(bet.text)  // Display the full bet text
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                        .padding()
                                        .frame(width: 250)  // Adjust width of the popover
                                }
                                .background(Color.white)
                                .cornerRadius(10)
                                .shadow(radius: 5)
                            }
                        }
                    }
                    .padding(.top, 16)
                }

                // Create Your Own Bet Text
                Text("Create your own bet")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)

                TextField("Enter your custom bet", text: $customBet)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Color.gray.opacity(0.2))  // Gray background
                    .cornerRadius(8)
                    .frame(height: 100)  // Ensuring at least 3 lines of space
                    .lineLimit(nil)  // Allow multiline input by expanding if needed
                    .padding(.horizontal, 24)

                // Next Button
                NavigationLink(destination: BetOptionsView(navPath: $navPath, betPrompt: customBet)) {
                    Text("Next")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(14)
                        .padding(.top, 16)
                        .padding(.horizontal, 24)
                }

                Spacer() // Add Spacer to push content upwards
            }
            .padding(.top, 16) // Reduce overall padding to move everything up
        }
        .onAppear {
            Task {
                await generateBets() // Fetch initial AI suggestions
            }
        }
        .alert(item: $errorMessage) { error in
            Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
    }
}

struct BetOptionsView: View {
    @Binding var navPath: NavigationPath
    let betPrompt: String
    
    @State private var betOptions: [String] = []
    @State private var betTerms: String = ""

    @State private var isGeneratingOptions = false
    @State private var isGeneratingTerms = false
    @State private var errorMessage: ErrorMessage?

    struct ErrorMessage: Identifiable {
        var id = UUID()
        var message: String
    }

    // MARK: - Replace with your secure stored key / injection
    private let geminiAPIKey = "AIzaSyAunbuh_N_W_mkRpvKIosu-TDajJvJO8Q8"

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background Gradient to match previous view
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                ScrollView {
                    VStack(spacing: 24) {

                        // Header + Add Option + AI Generate Options
                        HStack(spacing: 16) {
                            Text("Set Bet Options")
                                .font(.system(size: 18, weight: .regular, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()

                            // AI generate options button
                            if isGeneratingOptions {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Button {
                                    Task { await generateAIBetOptions() }
                                } label: {
                                    Image(systemName: "sparkles") // star-ish icon
                                        .font(.system(size: 22))
                                        .foregroundColor(.yellow)
                                        .accessibilityLabel("AI fill bet options")
                                }
                            }

                            // Manually add blank option
                            Button(action: { betOptions.append("") }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                                    .accessibilityLabel("Add bet option")
                            }
                        }
                        .padding(.top, 16)
                        .padding(.horizontal, 24)

                        // Bet Options List
                        ForEach(betOptions.indices, id: \.self) { index in
                            HStack {
                                TextField("Enter a bet option", text: $betOptions[index])
                                    .padding(14)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                                    .frame(height: 50)
                                    .padding(.horizontal, 24)

                                Button(action: {
                                    betOptions.remove(at: index)
                                }) {
                                    Image(systemName: "x.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 24))
                                        .accessibilityLabel("Remove bet option")
                                }
                                .padding(.trailing, 24)
                            }
                        }

                        // Terms of the Bet + AI Fill
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 16) {
                                Text("Terms of the bet (Prize, Penalty, etc)")
                                    .font(.system(size: 18, weight: .regular, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()

                                if isGeneratingTerms {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Button {
                                        Task { await generateAITerms() }
                                    } label: {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 22))
                                            .foregroundColor(.yellow)
                                            .accessibilityLabel("AI fill terms of the bet")
                                    }
                                }
                            }
                            .padding(.horizontal, 24)

                            TextField("Enter the bet terms", text: $betTerms, axis: .vertical)
                                .padding(14)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .frame(minHeight: 120, alignment: .topLeading)
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 80) // Room for bottom button
                    }
                }

                NavigationLink(
                    destination: FinalizeBetView(
                        navPath: $navPath,
                        betPrompt: betPrompt,
                        betOptions: betOptions,
                        betTerms: betTerms
                    )
                ) {
                    Text("Next")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }

            }
        }
        .alert(item: $errorMessage) { err in
            Alert(title: Text("Error"), message: Text(err.message), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - AI Calls

    private func generateAIBetOptions() async {
        guard !isGeneratingOptions else { return }
        isGeneratingOptions = true
        defer { isGeneratingOptions = false }

        let prompt = """
        Generate 4-6 short, mutually exclusive bet outcome options appropriate for a casual friendly wager. 
        This is the main bet: "\(betPrompt)"
        Examples: Team A Wins, Team B Wins, Total Score Over 200, Total Score Under 200.
        Each option should be under 7 words. Return as a comma-separated list.
        """

        do {
            let text = try await callGemini(with: prompt)
            // Parse comma-separated; strip empties
            let parts = text
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if parts.isEmpty {
                throw NSError(domain: "AIBetOptionsEmpty", code: 0)
            }
            betOptions = parts
        } catch {
            errorMessage = ErrorMessage(message: "Could not generate bet options. Using placeholders.")
            betOptions = [
                "Player 1 wins",
                "Player 2 wins",
                "Tie / Push",
                "Total points over 50",
                "Total points under 50"
            ]
        }
    }

    private func generateAITerms() async {
        guard !isGeneratingTerms else { return }
        isGeneratingTerms = true
        defer { isGeneratingTerms = false }

        // Provide context: include current bet options so model can tailor stakes
        let contextList = betOptions.isEmpty ? "No options currently set." :
            betOptions.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")

        let prompt = """
        Write short, clear terms for a friendly bet with the topic:

        \(betPrompt)

        Options:
        \(contextList)

        Include: what counts as a valid result, how winner is determined, tie/push rules, fun low-stakes prize or penalty, and when results are finalized.
        Keep under 80 words. Return plain text only.
        """


        do {
            let text = try await callGemini(with: prompt)
            // Trim + collapse extra whitespace
            betTerms = text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            errorMessage = ErrorMessage(message: "Could not generate bet terms. Please edit manually.")
        }
    }

    // MARK: - Generic Gemini Call
    private func callGemini(with prompt: String) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(geminiAPIKey)") else {
            throw URLError(.badURL)
        }

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard
            let resp = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = resp["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw NSError(domain: "GeminiParsing", code: 0)
        }
        return text
    }
}

struct FinalizeBetView: View {
    @Binding var navPath: NavigationPath
    let betPrompt: String
    let betOptions: [String]
    let betTerms: String

    @State private var partyName: String = ""
    @State private var privacyOption: String = "Open"
    @State private var maxMembers: Int = 10

    private let privacyOptions = ["Open", "Friends Only", "Invite Only"]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.2)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Finalize Your Bet")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prompt")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                        Text(betPrompt)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Options")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                        ForEach(betOptions, id: \ .self) { option in
                            Text(option)
                                .foregroundColor(.white)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Terms")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                        Text(betTerms)
                            .foregroundColor(.white)
                    }

                    Divider()
                        .background(Color.white.opacity(0.3))

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Party Settings")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)

                        TextField("Party Name", text: $partyName)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)

                        Picker("Privacy", selection: $privacyOption) {
                            ForEach(privacyOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        Stepper(value: $maxMembers, in: 2...50) {
                            Text("Max Members: \(maxMembers)")
                                .foregroundColor(.white)
                        }
                    }

                    Spacer()

                    Button(action: {
                        navPath.removeLast(navPath.count)
                    }) {
                        Text("Create Party")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(14)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Finalize")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        NormalBetView(navPath: .constant(NavigationPath()), email: "test@example.com")
    }
}
