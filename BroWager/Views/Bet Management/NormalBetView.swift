// Updated Bet Creation Flow with Category-Influenced AI Suggestions

import SwiftUI

#Preview {
    NormalBetView(
        navPath: .constant(NavigationPath()),
        email: "preview@example.com",
        userId: UUID(),
        selectedCategory: BetCategoryView.BetCategory.sports
    )
}

struct NormalBetView: View {
    @Binding var navPath: NavigationPath
    let email: String
    let userId: UUID?
    let selectedCategory: BetCategoryView.BetCategory?

    @State private var aiSuggestions: [String] = []
    @State private var betPrompt: String = ""
    @State private var selectedDate = Date()
    @State private var isNextActive = false
    @State private var optionCount = 4
    @State private var maxSelections = 1
    
    // Date picker states
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedDay = Calendar.current.component(.day, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    
    private let months = Array(1...12)
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
                    
                    // Category Header
                    if let category = selectedCategory {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(category.rawValue)
                                    .foregroundColor(.white)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(category.description)
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.caption)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    
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
                    
                    // TimerSetView-style Date Picker Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a date for your bet")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(.horizontal)
                        
                        HStack(spacing: 0) {
                            DatePickerView(title: "Month",
                                         range: 1...12,
                                         binding: $selectedMonth,
                                         formatter: { monthNumber in
                                             Calendar.current.monthSymbols[monthNumber - 1]
                                         })
                            
                            DatePickerView(title: "Day",
                                         range: 1...days.count,
                                         binding: $selectedDay)
                            
                            DatePickerView(title: "Year",
                                         range: currentYear...(currentYear + 5),
                                         binding: $selectedYear)
                        }
                        .frame(height: 100)
                        .padding(.horizontal)
                        .onChange(of: selectedMonth) { _ in updateSelectedDate() }
                        .onChange(of: selectedDay) { _ in updateSelectedDate() }
                        .onChange(of: selectedYear) { _ in updateSelectedDate() }
                        .onChange(of: optionCount) { _ in
                            // Ensure maxSelections doesn't exceed optionCount - 1
                            if maxSelections >= optionCount {
                                maxSelections = max(1, optionCount - 1)
                            }
                        }
                        
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
                    
                    // Maximum Selections Section
                    VStack(spacing: 12) {
                        HStack {
                            Text("Max selections per user")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            // Counter/Ticker on the right
                            HStack(spacing: 16) {
                                Button(action: {
                                    if maxSelections > 1 {
                                        maxSelections -= 1
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(maxSelections > 1 ? .blue : .gray)
                                        .font(.title2)
                                }
                                .disabled(maxSelections <= 1)
                                
                                Text("\(maxSelections)")
                                    .foregroundColor(.white)
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(minWidth: 30)
                                
                                Button(action: {
                                    if maxSelections < (optionCount - 1) {
                                        maxSelections += 1
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(maxSelections < (optionCount - 1) ? .blue : .gray)
                                        .font(.title2)
                                }
                                .disabled(maxSelections >= (optionCount - 1))
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
                            optionCount: optionCount,
                            maxSelections: maxSelections,
                            selectedCategory: selectedCategory
                        ),
                        isActive: $isNextActive
                    ) {
                        EmptyView()
                    }
                    
                    Button(action: {
                        if canProceed {
                            isNextActive = true
                        }
                    }) {
                        Text("Next")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(canProceed ? Color.green : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
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
            print("Attempting to fetch category-based AI suggestions...")
            
            let result = try await AIServices.shared.generateCategoryBetSuggestions(
                category: selectedCategory,
                count: 5
            )
            print("Raw AI Response: \(result)")
            aiSuggestions = result
        } catch {
            print("AI decoding error: \(error.localizedDescription)")
            
            // Category-specific fallback suggestions
            let fallbackSuggestions = getCategoryFallbackSuggestions()
            aiSuggestions = fallbackSuggestions
        }
    }
    
    private func getCategoryFallbackSuggestions() -> [String] {
        guard let category = selectedCategory else {
            return [
                "Who will finish their coffee first this morning?",
                "What will be the next song that comes on shuffle?",
                "Which elevator will arrive first when we press the button?",
                "How many red cars will we see in the next 10 minutes?",
                "Who will get the most likes on their next social media post?"
            ]
        }
        
        switch category {
        case .sports:
            return [
                "Which team will score first in the next game?",
                "Who will run the fastest mile in our group?",
                "Which player will have the most assists this season?",
                "Will the home team win their next match?",
                "Who will make the most free throws out of 10 attempts?"
            ]
        case .food:
            return [
                "Which restaurant will we choose for dinner tonight?",
                "Who can eat the spiciest food without drinking water?",
                "What will be the most popular pizza topping ordered?",
                "Which of us will finish our meal first?",
                "Will the new restaurant get good reviews this week?"
            ]
        case .lifeEvents:
            return [
                "Who will get engaged first in our friend group?",
                "Which of us will get promoted this year?",
                "Who will move to a new city first?",
                "Which couple will celebrate their anniversary first?",
                "Who will learn a new skill by the end of the month?"
            ]
        case .politics:
            return [
                "Which candidate will win the local election?",
                "What will be the voter turnout percentage?",
                "Which political party will gain more seats?",
                "Will the new policy be approved this quarter?",
                "Which state will announce results first?"
            ]
        case .other:
            return [
                "What will be the weather like tomorrow?",
                "Which movie will be #1 at the box office this weekend?",
                "Who will get the next text message first?",
                "What color car will drive by next?",
                "Which of us will wake up earliest tomorrow?"
            ]
        }
    }
}

// New DatePickerView component similar to TimerSetView
struct DatePickerView: View {
    private let pickerViewTitlePadding: CGFloat = 4.0
    
    let title: String
    let range: ClosedRange<Int>
    let binding: Binding<Int>
    let formatter: ((Int) -> String)?
    
    init(title: String, range: ClosedRange<Int>, binding: Binding<Int>, formatter: ((Int) -> String)? = nil) {
        self.title = title
        self.range = range
        self.binding = binding
        self.formatter = formatter
    }
    
    var body: some View {
        HStack(spacing: -pickerViewTitlePadding) {
            Picker(title, selection: binding) {
                ForEach(range, id: \.self) { value in
                    HStack {
                        Spacer()
                        Text(formatter?(value) ?? "\(value)")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .pickerStyle(InlinePickerStyle())
            .labelsHidden()
            
            Text(title)
                .fontWeight(.bold)
                .foregroundColor(.white)
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
    let maxSelections: Int
    let selectedCategory: BetCategoryView.BetCategory?

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
                // Category and Date Display
                HStack {
                    if let category = selectedCategory {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                            Text(category.rawValue)
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    }
                    
                    Spacer()
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text("Bet Date: \(selectedDate, style: .date)")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.subheadline)
                    }
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
                        maxSelections: maxSelections,
                        userId: userId
                    ),
                    isActive: $isNextActive
                ) {
                    EmptyView()
                }
                
                Button(action: {
                    if canProceed {
                        isNextActive = true
                    }
                }) {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canProceed ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
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
                
                let categoryContext = selectedCategory?.aiPromptContext ?? "general activities"
                
                let prompt: String
                
                if isBinaryBet {
                    prompt = """
                    Analyze this betting question: "\(betPrompt)"
                    
                    This is a binary (yes/no or either/or) question in the \(selectedCategory?.rawValue.lowercased() ?? "general") category.
                    
                    Generate exactly 2 clear, specific options that directly answer this question:
                    
                    Rules:
                    - Extract the exact entities/teams/people mentioned in the question
                    - If it's "Who will win X vs Y", return exactly "X" and "Y" (use the actual names)
                    - If it's "Will [something] happen", return "Yes" and "No"
                    - If it's "Which is better A or B", return "A" and "B" (use actual names)
                    - Be precise and use the exact terms from the question
                    - Keep each option under 8 words
                    
                    Return only the 2 options, one per line, no numbering or extra text.
                    """
                } else {
                    prompt = """
                    Analyze this betting question: "\(betPrompt)"
                    
                    Generate exactly \(targetCount) realistic, specific options that directly answer this question about \(categoryContext).
                    
                    Requirements:
                    - Each option must be a plausible answer to the exact question asked
                    - Be specific and measurable (avoid vague terms like "other" or "something else")
                    - If the question mentions specific entities, include them in relevant options
                    - Options should be mutually exclusive (only one can be correct)
                    - Make them realistic for the date: \(formattedDate)
                    - Keep each option concise (under 15 words)
                    - Ensure all \(targetCount) options are filled
                    
                    For example:
                    - If asked "What will the weather be like?": "Sunny", "Rainy", "Cloudy", "Stormy"
                    - If asked "Who will score first?": Use actual player names if mentioned
                    - If asked "What time will we arrive?": "Before 2 PM", "2-4 PM", "4-6 PM", "After 6 PM"
                    
                    Return exactly \(targetCount) options, one per line, no numbering or extra text.
                    """
                }

                let responseText = try await AIServices.shared.sendPrompt(
                    prompt,
                    model: "gemini-2.5-flash-lite",
                    temperature: 0.3,
                    maxTokens: 300
                )

                let cleanedLines = responseText
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .map {
                        // Remove numbering, bullets, and other prefixes
                        $0.replacingOccurrences(of: #"^\s*[\d\-\•\*\)\.\:]+\.?\s*"#, with: "", options: .regularExpression)
                    }
                    .filter { $0.count > 1 && $0.count < 150 }

                var generatedOptions = Array(cleanedLines.prefix(targetCount))
                
                // Ensure we have the exact number of options needed
                while generatedOptions.count < targetCount {
                    let fallbackOptions = generateFallbackOptions(for: betPrompt, isBinary: isBinaryBet, count: targetCount - generatedOptions.count)
                    generatedOptions.append(contentsOf: fallbackOptions)
                }
                
                // Take exactly the number we need
                generatedOptions = Array(generatedOptions.prefix(targetCount))
                
                // Clear existing options and fill with generated ones
                betOptions = Array(repeating: "", count: optionCount)
                for (index, option) in generatedOptions.enumerated() {
                    if index < betOptions.count {
                        betOptions[index] = option
                    }
                }

                // If we still don't have enough, use fallback
                if generatedOptions.count < targetCount {
                    let additionalFallback = generateFallbackOptions(for: betPrompt, isBinary: isBinaryBet, count: targetCount)
                    for (index, option) in additionalFallback.enumerated() {
                        if index < betOptions.count && betOptions[index].isEmpty {
                            betOptions[index] = option
                        }
                    }
                }

            } catch {
                print("Failed to generate bet options: \(error)")
                let fallbackOptions = generateFallbackOptions(for: betPrompt, isBinary: detectBinaryBet(betPrompt), count: optionCount)
                betOptions = Array(repeating: "", count: optionCount)
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
            "who will win", "vs", " v ", " or ", "will there be", "will it", "yes or no",
            "true or false", "happen or not", "over or under", "better", "worse",
            "will they", "will he", "will she", "does", "is it", "can they", "should"
        ]
        
        let versusPatterns = [
            " vs?\\.? ",
            " versus ",
            "\\b\\w+ or \\w+\\b",
            " vs$ ",
            "\\bversus\\b"
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
            
            // Try to extract specific entities from vs/versus patterns
            if let vsRange = lowercased.range(of: " vs ") ?? lowercased.range(of: " versus ") ?? lowercased.range(of: " v ") {
                let beforeVs = String(lowercased[..<vsRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let afterVs = String(lowercased[vsRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let lastWord = beforeVs.components(separatedBy: " ").last?.capitalized,
                   let firstWord = afterVs.components(separatedBy: " ").first?.capitalized,
                   !lastWord.isEmpty && !firstWord.isEmpty {
                    return [lastWord, firstWord]
                }
            }
            
            // Check for "will" questions
            if lowercased.contains("will") {
                return ["Yes", "No"]
            }
            
            // Check for choice questions
            if lowercased.contains(" or ") {
                let parts = lowercased.components(separatedBy: " or ")
                if parts.count >= 2 {
                    let option1 = parts[0].components(separatedBy: " ").last?.capitalized ?? "Option A"
                    let option2 = parts[1].components(separatedBy: " ").first?.capitalized ?? "Option B"
                    return [option1, option2]
                }
            }
            
            return ["Yes", "No"]
        } else {
            // Non-binary bet fallback options
            guard let category = selectedCategory else {
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
            
            let categoryOptions: [String] = {
                switch category {
                case .sports:
                    return [
                        "Home team wins",
                        "Away team wins",
                        "Game goes to overtime",
                        "Under total score",
                        "Over total score",
                        "First half leader",
                        "Most fouls",
                        "Fastest goal",
                        "Defensive play",
                        "Surprise outcome"
                    ]
                case .food:
                    return [
                        "Spicy option",
                        "Sweet choice",
                        "Healthy alternative",
                        "Comfort food",
                        "New cuisine",
                        "Local favorite",
                        "Chef's special",
                        "Vegetarian option",
                        "Popular choice",
                        "Unique dish"
                    ]
                case .lifeEvents:
                    return [
                        "Within a month",
                        "Within 6 months",
                        "By end of year",
                        "Next year",
                        "Sooner than expected",
                        "Later than planned",
                        "Exactly on time",
                        "With celebration",
                        "Quietly",
                        "Unexpected timing"
                    ]
                case .politics:
                    return [
                        "Incumbent wins",
                        "Challenger wins",
                        "Close margin",
                        "Landslide victory",
                        "High turnout",
                        "Low turnout",
                        "Policy passes",
                        "Policy fails",
                        "Delayed decision",
                        "Surprise outcome"
                    ]
                case .other:
                    return [
                        "Most likely outcome",
                        "Second choice",
                        "Unexpected result",
                        "Popular option",
                        "Unique possibility",
                        "Traditional choice",
                        "Modern alternative",
                        "Safe bet",
                        "Risky option",
                        "Wild card"
                    ]
                }
            }()
            
            return Array(categoryOptions.prefix(count))
        }
    }

    func generateTerms(date: Date) {
        Task {
            do {
                let validOptions = betOptions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                let betDescription = validOptions.joined(separator: ", ")
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .full
                let formattedDate = dateFormatter.string(from: date)
                
                let categoryContext = selectedCategory?.aiPromptContext ?? "general activities"
                let categoryName = selectedCategory?.rawValue.lowercased() ?? "general"
                
                let prompt = """
                Generate concise, user-friendly terms and conditions for a \(categoryName) bet scheduled for \(formattedDate) 
                involving these options: \(betDescription). 
                
                This bet is specifically about \(categoryContext), so include relevant rules and considerations for this type of bet.
                Use simple language suitable for users, avoid legal jargon, do not use placeholders like [Your Company], 
                and keep the response under 300 words. 
                
                Include:
                - Basic rules about how the bet will be determined for \(categoryContext)
                - What happens if there are disputes specific to \(categoryName) bets
                - Any special considerations for \(categoryContext)
                - Simple consequences or rewards appropriate for friends betting on \(categoryName)
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
                
                // Category-specific fallback terms
                let categorySpecificTerms = getCategoryFallbackTerms(date: formattedDate)
                betTerms = categorySpecificTerms
            }
        }
    }
    
    private func getCategoryFallbackTerms(date: String) -> String {
        guard let category = selectedCategory else {
            return """
            Bet is valid for \(date). \
            Results will be determined based on the agreed upon criteria. \
            All participants must confirm their selections before the bet begins. \
            In case of disputes, the majority vote of participants will determine the outcome. \
            Have fun and bet responsibly!
            """
        }
        
        switch category {
        case .sports:
            return """
            Sports bet valid for \(date). Results determined by official game/match outcomes. \
            All participants must lock in predictions before the event starts. \
            Disputes resolved using official statistics and scores. \
            In case of game cancellation or postponement, bet extends to rescheduled date. \
            Winner buys the group drinks or snacks!
            """
        case .food:
            return """
            Food bet valid for \(date). Results determined by actual choices made or outcomes achieved. \
            All participants must confirm their predictions before the meal/event. \
            Taste tests and food challenges must be conducted fairly with all participants present. \
            Disputes resolved by group consensus or neutral taste tester. \
            Loser pays for the meal or treats everyone to dessert!
            """
        case .lifeEvents:
            return """
            Life events bet valid for \(date). Results determined by actual life events as they occur. \
            All participants must confirm predictions before the deadline. \
            Personal milestones must be verified through social media or mutual friends. \
            Respect privacy - no pressure on participants to rush life decisions. \
            Winner gets bragging rights and a celebration dinner from the group!
            """
        case .politics:
            return """
            Political bet valid for \(date). Results determined by official election results or policy announcements. \
            All participants must confirm predictions before voting/announcement deadlines. \
            Disputes resolved using official government sources and verified news outlets. \
            Keep discussions respectful regardless of political affiliations. \
            Winner gets to choose the next group discussion topic!
            """
        case .other:
            return """
            General bet valid for \(date). Results determined based on observable, verifiable outcomes. \
            All participants must confirm their selections before the event/deadline. \
            Evidence must be clear and agreed upon by all participants. \
            In case of disputes, majority vote or neutral observer determines the outcome. \
            Winner gets bragging rights and a small prize from the group!
            """
        }
    }
}

// Extension to AIServices for category-based bet suggestions
extension AIServices {
    @available(iOS 15.0, *)
    func generateCategoryBetSuggestions(category: BetCategoryView.BetCategory?, count: Int) async throws -> [String] {
        let categoryContext = category?.aiPromptContext ?? "general everyday activities"
        let categoryName = category?.rawValue.lowercased() ?? "general"
        
        let prompt = """
        Generate \(count) fun and creative betting questions specifically about \(categoryContext).
        These should be engaging \(categoryName) situations that friends can make bets about.
        
        Focus exclusively on \(categoryContext) and make them:
        - Realistic and achievable
        - Fun for friends to bet on
        - Measurable with clear outcomes
        - Appropriate for social betting
        
        Examples of \(categoryName) bets should include scenarios like \(getSamplePrompts(for: category)).
        
        Return only the betting questions, one per line, without numbering or additional text.
        Make them diverse and engaging for \(categoryName) enthusiasts.
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
            .filter { !$0.isEmpty && $0.count > 15 }
            .prefix(count)
            .map { String($0) }
    }
    
    private func getSamplePrompts(for category: BetCategoryView.BetCategory?) -> String {
        guard let category = category else {
            return "everyday random events, social situations, or general predictions"
        }
        
        switch category {
        case .sports:
            return "which team will score first, who will have the most assists, what the final score margin will be"
        case .food:
            return "which restaurant will have the longest wait, who can finish the spiciest dish, what the most popular menu item will be"
        case .lifeEvents:
            return "who will get engaged first, which friend will move cities, who will get promoted this year"
        case .politics:
            return "which candidate will win, what the voter turnout will be, which policy will pass first"
        case .other:
            return "what the weather will be like, which movie will top the box office, who will reply to texts fastest"
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
    let maxSelections: Int
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
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Max Selections per User:")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                            Text("\(maxSelections) out of \(betOptions.count) options")
                                .foregroundColor(.blue)
                                .font(.system(size: 14, weight: .semibold))
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
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(canProceed ? Color.green : Color.gray)
                                .frame(height: 50)

                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Bet")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
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
