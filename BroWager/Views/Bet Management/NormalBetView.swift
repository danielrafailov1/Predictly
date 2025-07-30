// Updated Bet Creation Flow with Random AI Suggestions and Validation

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
    @State private var optionCount = 4
    
    // Date picker states
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedDay = Calendar.current.component(.day, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    
    private let months = Calendar.current.monthSymbols
    private let currentYear = Calendar.current.component(.year, from: Date())
    
    private var years: [Int] {
        Array(currentYear...(currentYear + 5))
    }
    
    private var days: [Int] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1
        
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return Array(1...31)
        }
        
        return Array(1...range.count)
    }
    
    // Validation computed property
    private var canProceed: Bool {
        !betPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
                    
                    // AI Suggestions Header
                    VStack(spacing: 12) {
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
                    }
                    
                    // Scrollable Suggestion Buttons
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
                    .frame(height: 150)
                    
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
                    
                    // Custom Scrollable Date Picker Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a date for your bet")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            // Month Picker
                            VStack {
                                Text("Month")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.system(size: 14, weight: .medium))
                                
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(Array(months.enumerated()), id: \.offset) { index, month in
                                            Button(action: {
                                                selectedMonth = index + 1
                                                updateSelectedDate()
                                            }) {
                                                Text(month)
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 12)
                                                    .foregroundColor(selectedMonth == index + 1 ? .blue : .white)
                                                    .font(.system(size: 16, weight: selectedMonth == index + 1 ? .semibold : .regular))
                                            }
                                        }
                                    }
                                }
                                .frame(height: 120)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Day Picker
                            VStack {
                                Text("Day")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.system(size: 14, weight: .medium))
                                
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(days, id: \.self) { day in
                                            Button(action: {
                                                selectedDay = day
                                                updateSelectedDate()
                                            }) {
                                                Text("\(day)")
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 12)
                                                    .foregroundColor(selectedDay == day ? .blue : .white)
                                                    .font(.system(size: 16, weight: selectedDay == day ? .semibold : .regular))
                                            }
                                        }
                                    }
                                }
                                .frame(height: 120)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Year Picker
                            VStack {
                                Text("Year")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.system(size: 14, weight: .medium))
                                
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(years, id: \.self) { year in
                                            Button(action: {
                                                selectedYear = year
                                                updateSelectedDate()
                                            }) {
                                                Text(String(year))
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 12)
                                                    .foregroundColor(selectedYear == year ? .blue : .white)
                                                    .font(.system(size: 16, weight: selectedYear == year ? .semibold : .regular))
                                            }
                                        }
                                    }
                                }
                                .frame(height: 120)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Display selected date
                        HStack {
                            Spacer()
                            Text("Selected: \(formattedSelectedDate())")
                                .foregroundColor(.blue)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    // Number of Options Section
                    VStack(spacing: 12) {
                        HStack {
                            Text("Number of options")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            // Counter/Ticker on the right
                            HStack(spacing: 16) {
                                Button(action: {
                                    if optionCount > 2 {
                                        optionCount -= 1
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(optionCount > 2 ? .blue : .gray)
                                        .font(.title2)
                                }
                                .disabled(optionCount <= 2)
                                
                                Text("\(optionCount)")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(minWidth: 30)
                                
                                Button(action: {
                                    if optionCount < 10 {
                                        optionCount += 1
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(optionCount < 10 ? .blue : .gray)
                                        .font(.title2)
                                }
                                .disabled(optionCount >= 10)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    NavigationLink(
                        destination: BetOptionsView(
                            navPath: $navPath,
                            betPrompt: betPrompt,
                            selectedDate: selectedDate,
                            email: email,
                            userId: userId,
                            optionCount: optionCount
                        ),
                        isActive: $isNextActive
                    ) {
                        EmptyView()
                    }
                    
                    Button("Next") {
                        if canProceed {
                            isNextActive = true
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(canProceed ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(!canProceed)
                    
                    // Validation message
                    if !canProceed {
                        Text("Please enter a bet question to continue")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .onAppear(perform: loadAISuggestions)
            }
        }
    }
    
    private func dateFromComponents() -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = selectedDay
        
        if let date = calendar.date(from: components) {
            return date
        } else {
            components.day = 1
            guard let firstOfMonth = calendar.date(from: components),
                  let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
                return Date()
            }
            components.day = min(selectedDay, range.count)
            return calendar.date(from: components) ?? Date()
        }
    }
    
    private func updateSelectedDate() {
        let newDate = dateFromComponents()
        selectedDate = newDate
    }
    
    private func formattedSelectedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }

    @MainActor
    func loadAISuggestions() {
        let calendar = Calendar.current
        let currentDate = selectedDate
        
        selectedMonth = calendar.component(.month, from: currentDate)
        selectedDay = calendar.component(.day, from: currentDate)
        selectedYear = calendar.component(.year, from: currentDate)
        
        Task {
            await refreshAISuggestions()
        }
    }

    @MainActor
    func refreshAISuggestions() async {
        do {
            print("Attempting to fetch random AI suggestions...")
            
            let result = try await AIServices.shared.generateRandomBetSuggestions(count: 5)
            print("Raw AI Response: \(result)")
            aiSuggestions = result
        } catch {
            print("AI decoding error: \(error.localizedDescription)")
            
            // Random fallback suggestions
            let fallbackSuggestions = [
                "Who will finish their coffee first this morning?",
                "What will be the next song that comes on shuffle?",
                "Which elevator will arrive first when we press the button?",
                "How many red cars will we see in the next 10 minutes?",
                "Who will get the most likes on their next social media post?"
            ]
            
            aiSuggestions = fallbackSuggestions
        }
    }
}

struct BetOptionsView: View {
    @Binding var navPath: NavigationPath
    let betPrompt: String
    let selectedDate: Date
    let email: String
    let userId: UUID?
    let optionCount: Int

    @State private var betOptions: [String] = []
    @State private var betTerms: String = ""
    @State private var isNextActive = false
    
    // Validation computed property
    private var canProceed: Bool {
        betOptions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        !betTerms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
                    Text("Options (\(optionCount) required)")
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
                }
                .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(betOptions.indices, id: \.self) { index in
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(width: 20)
                                
                                TextField("Option \(index + 1)", text: $betOptions[index])
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .frame(maxHeight: 250)

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
                    if canProceed {
                        isNextActive = true
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(canProceed ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(!canProceed)
                
                // Validation message
                if !canProceed {
                    Text("Please fill out all options and terms to continue")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
            }
            .padding(.top)
        }
        .onAppear {
            // Initialize with the specified number of empty options
            if betOptions.isEmpty {
                betOptions = Array(repeating: "", count: optionCount)
            }
        }
    }

    func generateOptions(betPrompt: String, date: Date) {
        Task {
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .full
                let formattedDate = dateFormatter.string(from: date)
                
                let isBinaryBet = detectBinaryBet(betPrompt)
                let targetCount = isBinaryBet ? 2 : optionCount
                
                let prompt: String
                
                if isBinaryBet {
                    prompt = """
                    Based on this bet: "\(betPrompt)", generate exactly 2 simple, direct answer options.
                    
                    This appears to be a simple either/or question. Provide only the two most obvious choices.
                    For example:
                    - If it's "Who will win X vs Y", return: "Team X" and "Team Y"
                    - If it's "Will X happen", return: "Yes" and "No"
                    
                    Keep options short (1-4 words each) and direct. No complex scenarios.
                    Return only the options, one per line, no numbering.
                    """
                } else {
                    prompt = """
                    Based on this bet: "\(betPrompt)", generate exactly \(targetCount) realistic and specific options.
                    
                    Create measurable outcomes that can be definitively determined as true or false.
                    Each option should be one clear sentence.
                    Keep options concise but specific enough to be interesting.
                    
                    Return only the options, one per line, no numbering or extra text.
                    """
                }

                let responseText = try await AIServices.shared.sendPrompt(
                    prompt,
                    model: "gemini-2.5-flash-lite",
                    temperature: 0.6,
                    maxTokens: 200
                )

                let cleanedLines = responseText
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map {
                        $0.replacingOccurrences(of: #"^\s*[\d\-\•\*]+\.?\s*"#, with: "", options: .regularExpression)
                    }
                    .filter { $0.count > 2 && $0.count < 100 }

                let generatedOptions = Array(cleanedLines.prefix(targetCount))
                
                // Update the existing betOptions array with generated content
                for (index, option) in generatedOptions.enumerated() {
                    if index < betOptions.count {
                        betOptions[index] = option
                    }
                }

                // Fill remaining slots with fallback if needed
                if generatedOptions.isEmpty {
                    let fallbackOptions = generateFallbackOptions(for: betPrompt, isBinary: isBinaryBet, count: targetCount)
                    for (index, option) in fallbackOptions.enumerated() {
                        if index < betOptions.count {
                            betOptions[index] = option
                        }
                    }
                }

            } catch {
                print("Failed to generate bet options: \(error)")
                let fallbackOptions = generateFallbackOptions(for: betPrompt, isBinary: detectBinaryBet(betPrompt), count: optionCount)
                for (index, option) in fallbackOptions.enumerated() {
                    if index < betOptions.count {
                        betOptions[index] = option
                    }
                }
            }
        }
    }

    func detectBinaryBet(_ prompt: String) -> Bool {
        let lowercased = prompt.lowercased()
        
        let binaryKeywords = [
            "who will win", "vs", " v ", "or", "will there be", "will it", "yes or no",
            "true or false", "happen or not", "over or under"
        ]
        
        let versusPatterns = [
            " vs? ",
            " versus ",
            "\\b\\w+ or \\w+\\b"
        ]
        
        for keyword in binaryKeywords {
            if lowercased.contains(keyword) {
                return true
            }
        }
        
        for pattern in versusPatterns {
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    func generateFallbackOptions(for prompt: String, isBinary: Bool, count: Int) -> [String] {
        if isBinary {
            let lowercased = prompt.lowercased()
            
            if lowercased.contains("who will win") {
                if let vsRange = lowercased.range(of: " vs ") ?? lowercased.range(of: " v ") {
                    let afterVs = String(lowercased[vsRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let beforeVs = String(lowercased[..<vsRange.lowerBound])
                    
                    if let lastWord = beforeVs.components(separatedBy: " ").last,
                       let firstWord = afterVs.components(separatedBy: " ").first {
                        return [lastWord.capitalized, firstWord.capitalized]
                    }
                }
            }
            
            if lowercased.contains("will") {
                return ["Yes", "No"]
            }
            
            return ["Option A", "Option B"]
        } else {
            let baseOptions = [
                "Most likely outcome",
                "Second most likely",
                "Unexpected result",
                "Long shot possibility",
                "Alternative scenario",
                "Dark horse option",
                "Wildcard choice",
                "Backup possibility",
                "Outside chance",
                "Final option"
            ]
            
            return Array(baseOptions.prefix(count))
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
                Generate concise, user-friendly terms and conditions for a bet scheduled for \(formattedDate) involving these options: \(betDescription). \
                Use simple language suitable for users, avoid legal jargon, do not use placeholders like [Your Company], \
                and keep the response under 300 words. Include basic rules about how the bet will be determined and what happens if there are disputes.
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
                Bet is valid for \(formattedDate). \
                Results will be determined based on the agreed upon criteria. \
                All participants must confirm their selections before the bet begins. \
                In case of disputes, the majority vote of participants will determine the outcome. \
                Have fun and bet responsibly!
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
    
    // Validation computed property
    private var canProceed: Bool {
        !partyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
                    
                    // Bet Summary Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bet Summary")
                            .foregroundColor(.white)
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Question:")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                            Text(betPrompt)
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Options (\(betOptions.count)):")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(betOptions.enumerated()), id: \.offset) { index, option in
                                    if !option.isEmpty {
                                        Text("• \(option)")
                                            .foregroundColor(.white)
                                            .font(.system(size: 14))
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                        }
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
                    .background(canProceed ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(!canProceed || isSubmitting)
                    
                    // Validation message
                    if !canProceed {
                        Text("Please enter a party name to continue")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
        }
        .navigationDestination(isPresented: $showPartyDetails) {
            PartyDetailsView(partyCode: createdPartyCode, email: email)
        }
    }

    func randomizePartyName() {
        let suggestions = [
            "Bet Bros",
            "Wager Warriors",
            "Game Day Squad",
            "Prediction Party",
            "Lock & Load",
            "Sure Things",
            "Betting Brigade",
            "Odds Squad",
            "Props & Profits",
            "Smart Money",
            "The Predictors",
            "Bet Busters",
            "Wager Wizards",
            "Lucky Legends",
            "Risk Takers"
        ]

        partyName = suggestions.randomElement() ?? "My Betting Party"
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
        
        // Validate that we have valid bet options (filter out empty ones)
        let validOptions = betOptions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard validOptions.count >= 2 else {
            errorMessage = "At least 2 valid options are required"
            return
        }
        
        isSubmitting = true
        errorMessage = ""

        let partyCode = UUID().uuidString.prefix(6).uppercased()

        // Fix: Properly configure the DateFormatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd" // Use ISO date format for database
        
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
            options: validOptions, // Use filtered valid options
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

// Extension to AIServices for random bet suggestions
extension AIServices {
    @available(iOS 15.0, *)
    func generateRandomBetSuggestions(count: Int) async throws -> [String] {
        let prompt = """
        Generate \(count) completely random, fun, and creative betting questions that friends can make bets about. 
        These should be everyday situations, random events, or silly challenges that have nothing to do with sports.
        Make them engaging and something people would actually want to bet on with friends.
        
        Examples of the style:
        - "Who will get a text message first in the next hour?"
        - "What color shirt will the next person we see be wearing?"
        - "How many dogs will we see on our walk?"
        
        Return only the betting questions, one per line, without numbering or additional text.
        Make them diverse and creative - avoid sports entirely.
        """
        
        let response = try await sendPrompt(
            prompt,
            model: "gemini-2.5-flash-lite",
            temperature: 0.9,
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
