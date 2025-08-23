//
//  AIServices.swift
//  BroWager
//
//  Created by Nachuan Wang on 2025-07-21.
//
//

import Foundation

struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?
    let safetySettings: [GeminiSafetySetting]?
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
    let role: String?
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiGenerationConfig: Codable {
    let temperature: Double?
    let topK: Int?
    let topP: Double?
    let maxOutputTokens: Int?
    let stopSequences: [String]?
    
    enum CodingKeys: String, CodingKey {
        case temperature
        case topK
        case topP
        case maxOutputTokens
        case stopSequences
    }
}

struct GeminiSafetySetting: Codable {
    let category: String
    let threshold: String
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
    let usageMetadata: GeminiUsageMetadata?
    let promptFeedback: GeminiPromptFeedback?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?
    let index: Int?
    let safetyRatings: [GeminiSafetyRating]?
}

struct GeminiSafetyRating: Codable {
    let category: String
    let probability: String
}

struct GeminiUsageMetadata: Codable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?
}

struct GeminiPromptFeedback: Codable {
    let safetyRatings: [GeminiSafetyRating]?
    let blockReason: String?
}

// MARK: - Custom Errors
enum AIServiceError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case apiError(String)
    case unauthorized
    case rateLimited
    case contentBlocked
    case noAPIKey
    case missingResponse
    case allKeysExhausted
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noData:
            return "No data received from API"
        case .decodingError:
            return "Failed to decode API response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .unauthorized:
            return "Unauthorized: Check your API key"
        case .rateLimited:
            return "Rate limit exceeded"
        case .contentBlocked:
            return "Content was blocked by safety filters"
        case .noAPIKey:
            return "No API key provided"
        case .missingResponse:
            return "Missing response from Gemini API"
        case .allKeysExhausted:
            return "All API keys are exhausted or blocked"
        }
        
    }
}

// MARK: - Sports Entity Models
private struct SportsEntities {
    let teams: [String]
    let players: [String]
    let league: String?
    let sport: String?
}

private struct SimpleSportsEntities {
    let teams: [String]
    let league: String?
}

// MARK: - Google Search Response Models
struct GoogleSearchResponse: Codable {
    struct Item: Codable {
        let title: String
        let snippet: String
        let link: String
        let displayLink: String?
        
        // Additional metadata that might be useful
        struct PageMap: Codable {
            struct MetaTags: Codable {
                let description: String?
                let keywords: String?
            }
            let metatags: [MetaTags]?
        }
        let pagemap: PageMap?
    }
    
    struct SearchInformation: Codable {
        let totalResults: String
        let searchTime: Double
    }
    
    let items: [Item]?
    let searchInformation: SearchInformation?
}

// MARK: - AI Service Class for Gemini + Enhanced Sports Search
public class AIServices {
    
    // MARK: - Properties
    public static let shared = AIServices()
    
    private let session: URLSession
    private let baseURL: String
    private let defaultModel: String
    
    // MARK: - Initialization
    private init() {
        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
        
        // Gemini API base URL and model
        self.baseURL = "https://generativelanguage.googleapis.com/v1beta/models/"
        self.defaultModel = "gemini-2.5-flash"
    }
    
    // MARK: - Gemini API Methods
    
    /// Send conversation contents to Gemini
    func sendContents(_ contents: [GeminiContent],
                     model: String? = nil,
                     temperature: Double? = nil,
                     maxTokens: Int? = nil,
                     completion: @escaping (Result<GeminiResponse, AIServiceError>) -> Void) {
        
        guard let apiKey = APIKeyManager.shared.getCurrentAPIKey() else {
            completion(.failure(.allKeysExhausted))
            return
        }
        
        let generationConfig = GeminiGenerationConfig(
            temperature: temperature,
            topK: nil,
            topP: nil,
            maxOutputTokens: maxTokens,
            stopSequences: nil
        )
        
        let safetySettings = [
            GeminiSafetySetting(category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
            GeminiSafetySetting(category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
            GeminiSafetySetting(category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
            GeminiSafetySetting(category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE")
        ]
        
        let request = GeminiRequest(
            contents: contents,
            generationConfig: generationConfig,
            safetySettings: safetySettings
        )
        
        performRequest(request, model: model ?? defaultModel, completion: completion)
    }
    
    /// Send a chat conversation to Gemini
    func sendChatMessages(_ messages: [(role: String, text: String)],
                         model: String? = nil,
                         temperature: Double? = nil,
                         maxTokens: Int? = nil,
                         completion: @escaping (Result<String, AIServiceError>) -> Void) {
        
        let contents = messages.map { message in
            GeminiContent(
                parts: [GeminiPart(text: message.text)],
                role: message.role == "assistant" ? "model" : "user"
            )
        }
        
        sendContents(contents, model: model, temperature: temperature, maxTokens: maxTokens) { result in
            switch result {
            case .success(let response):
                let text = response.candidates?.first?.content.parts.first?.text ?? ""
                completion(.success(text))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Async/Await Methods (iOS 15+)
    
    @available(iOS 15.0, *)
    public func sendPrompt(
        _ prompt: String,
        model: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard let apiKey = APIKeyManager.shared.getCurrentAPIKey() else {
            throw AIServiceError.allKeysExhausted
        }
        
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw AIServiceError.invalidURL
        }

        let payload = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": maxTokens
            ]
        ] as [String: Any]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, _) = try await URLSession.shared.data(for: request)

        // Debug: Print the raw response from Gemini
        if let raw = String(data: data, encoding: .utf8) {
            print("🔥 Raw Gemini Response:\n\(raw)")
        }

        let decoder = JSONDecoder()
        do {
            let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
            if let candidates = geminiResponse.candidates,
               let text = candidates.first?.content.parts.first?.text {

                return text
            } else {
                throw AIServiceError.missingResponse
            }
        } catch {
            print("❌ Decoding error: \(error)")
            throw AIServiceError.decodingError
        }
    }
    
    @available(iOS 15.0, *)
    func sendContents(_ contents: [GeminiContent],
                     model: String? = nil,
                     temperature: Double? = nil,
                     maxTokens: Int? = nil) async throws -> GeminiResponse {
        return try await withCheckedThrowingContinuation { continuation in
            sendContents(contents, model: model, temperature: temperature, maxTokens: maxTokens) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    @available(iOS 15.0, *)
    func sendChatMessages(_ messages: [(role: String, text: String)],
                         model: String? = nil,
                         temperature: Double? = nil,
                         maxTokens: Int? = nil) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            sendChatMessages(messages, model: model, temperature: temperature, maxTokens: maxTokens) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performRequest(_ geminiRequest: GeminiRequest,
                               model: String,
                               completion: @escaping (Result<GeminiResponse, AIServiceError>) -> Void) {
        
        guard let apiKey = APIKeyManager.shared.getCurrentAPIKey() else {
            completion(.failure(.allKeysExhausted))
            return
        }
        
        let urlString = "\(baseURL)\(model):generateContent?key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(geminiRequest)
            urlRequest.httpBody = jsonData
            
            // Debug print
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Request JSON: \(jsonString)")
            }
        } catch {
            completion(.failure(.decodingError))
            return
        }
        
        session.dataTask(with: urlRequest) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleResponse(data: data, response: response, error: error, completion: completion)
            }
        }.resume()
    }
    
    private func handleResponse(data: Data?,
                              response: URLResponse?,
                              error: Error?,
                              completion: @escaping (Result<GeminiResponse, AIServiceError>) -> Void) {
        
        if let error = error {
            completion(.failure(.networkError(error)))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(.networkError(NSError(domain: "Invalid response", code: 0))))
            return
        }
        
        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            // Success - increment usage for the current key
            if let currentKey = APIKeyManager.shared.getCurrentAPIKey() {
                APIKeyManager.shared.incrementUsage(for: currentKey)
            }
            break
        case 400:
            completion(.failure(.apiError("Bad Request - Check your request format")))
            return
        case 401, 403:
            // Block current key and retry
            if let currentKey = APIKeyManager.shared.getCurrentAPIKey() {
                APIKeyManager.shared.blockKey(currentKey, reason: "Auth error (\(httpResponse.statusCode))")
            }
            completion(.failure(.unauthorized))
            return
        case 429:
            // Block current key due to rate limiting
            if let currentKey = APIKeyManager.shared.getCurrentAPIKey() {
                APIKeyManager.shared.blockKey(currentKey, reason: "Rate limited (429)")
            }
            completion(.failure(.rateLimited))
            return
        default:
            completion(.failure(.apiError("HTTP \(httpResponse.statusCode)")))
            return
        }
        
        guard let data = data else {
            completion(.failure(.noData))
            return
        }
        
        do {
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            // Check if content was blocked
            if let promptFeedback = geminiResponse.promptFeedback,
               promptFeedback.blockReason != nil {
                completion(.failure(.contentBlocked))
                return
            }
            
            completion(.success(geminiResponse))
        } catch {
            print("Decoding error: \(error)")
            completion(.failure(.decodingError))
        }
    }
    
    // MARK: - Bet Suggestion Helpers
    
    /// Generate suggestions for bets
    @available(iOS 15.0, *)
    public func generateBetSuggestions(betType: String, count: Int) async throws -> [String] {
        let prompt = """
        You are a suggestion generator. A group of friends are hanging out and they want to make friendly wagers or challenges. Generate \(count) suggestions of type \(betType) in JSON format. For each suggestion, only generate a string of the content.
        
        Focus on:
        - Fun friendly competitions
        - Skill-based challenges  
        - Sports predictions
        - Entertainment wagers
        - Social activities
        
        Avoid using the word that rhymes with "net" in your responses. Instead use terms like:
        - "wager"
        - "challenge"
        - "prediction"
        - "contest"
        - "competition"
        
        Return only a JSON array of strings.
        """

        let responseText = try await sendPrompt(prompt, model: defaultModel, temperature: 0.9, maxTokens: 10000)

        print("📦 Full responseText:\n\(responseText)\n")

        // Extract JSON array from response string
        guard let start = responseText.firstIndex(of: "["),
              let end = responseText.lastIndex(of: "]") else {
            print("⚠️ Failed to find valid JSON array in response.")
            throw AIServiceError.decodingError
        }

        let jsonString = String(responseText[start...end])
        print("🔍 Extracted jsonString:\n\(jsonString)\n")

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("⚠️ Failed to convert jsonString to Data.")
            throw AIServiceError.decodingError
        }

        // Decode and filter out any responses containing the forbidden word
        let suggestions = try JSONDecoder().decode([String].self, from: jsonData)
        return suggestions.filter { !$0.lowercased().contains("bet") }
    }

    
    /// Generate suggestions for bets (alternative)
    @available(iOS 15.0, *)
    public func generateBetSuggestions(prompt: String) async throws -> [String] {
        
        let enhancedPrompt = """
        \(prompt)
        
        Important: Do not use the word that rhymes with "net" in your responses. Instead use alternative terms like:
        - "wager"
        - "challenge" 
        - "prediction"
        - "contest"
        - "competition"
        - "dare"
        
        Return only a JSON array of strings.
        """
        
        let responseText = try await sendPrompt(enhancedPrompt, model: defaultModel, temperature: 0.9, maxTokens: 10000)

        // Extract JSON array from response string
        guard let start = responseText.firstIndex(of: "["),
              let end = responseText.lastIndex(of: "]") else {
            throw AIServiceError.decodingError
        }

        let jsonString = String(responseText[start...end])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.decodingError
        }
        
        print(jsonData)
        
        let suggestions = try JSONDecoder().decode([String].self, from: jsonData)
        
        // Filter out any responses that might contain the forbidden word
        let filteredSuggestions = suggestions.filter { !$0.lowercased().contains("bet") }
        
        try print(filteredSuggestions)
        
        return filteredSuggestions
    }
    
    // MARK: - Enhanced Google Custom Search API Integration
    
    @available(iOS 15.0, *)
    func performSportsOptimizedGoogleSearch(query: String, numResults: Int = 8, dateRange: String? = nil) async throws -> String {
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CSE_API_KEY") as? String ?? ""
        let engineId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CSE_ENGINE_ID") as? String ?? ""
        
        if apiKey.isEmpty || engineId.isEmpty {
            throw AIServiceError.noAPIKey
        }
        
        var components = URLComponents(string: "https://www.googleapis.com/customsearch/v1")!
        var queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "cx", value: engineId),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "num", value: "\(numResults)"),
            URLQueryItem(name: "safe", value: "off"), // Allow all content types
            URLQueryItem(name: "lr", value: "lang_en"), // English results only
        ]
        
        // Add date range if provided
        if let dateRange = dateRange {
            queryItems.append(URLQueryItem(name: "dateRestrict", value: dateRange))
        }
        
        // Prioritize sports websites
        let sportsWebsites = [
            "espn.com",
            "cbssports.com",
            "si.com",
            "nfl.com",
            "nba.com",
            "mlb.com",
            "nhl.com",
            "foxsports.com",
            "bleacherreport.com",
            "sports.yahoo.com"
        ]
        
        // Create site-specific search for better results
        let siteQuery = sportsWebsites.map { "site:\($0)" }.joined(separator: " OR ")
        let enhancedQuery = "\(query) (\(siteQuery))"
        queryItems[2] = URLQueryItem(name: "q", value: enhancedQuery)
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw AIServiceError.invalidURL
        }
        
        print("🔍 Enhanced sports search URL: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check for rate limiting
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 Search API response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 429 {
                    // Rate limited, wait and retry once
                    print("⏳ Rate limited, waiting 2 seconds...")
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    let (retryData, _) = try await URLSession.shared.data(from: url)
                    return try parseGoogleSearchResponse(retryData)
                } else if httpResponse.statusCode != 200 {
                    throw AIServiceError.apiError("Google Search API returned status: \(httpResponse.statusCode)")
                }
            }
            
            return try parseGoogleSearchResponse(data)
            
        } catch {
            print("❌ Google Search API error: \(error)")
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - Enhanced Search Response Parser
    private func parseGoogleSearchResponse(_ data: Data) throws -> String {
        let searchResult = try JSONDecoder().decode(GoogleSearchResponse.self, from: data)
        
        guard let items = searchResult.items, !items.isEmpty else {
            return "No search results found."
        }
        
        print("🔍 Found \(items.count) search results")
        
        // Sort results by relevance to sports content
        let sortedItems = items.sorted { (item1, item2) in
            let score1 = calculateSportsRelevanceScore(for: item1)
            let score2 = calculateSportsRelevanceScore(for: item2)
            return score1 > score2
        }
        
        // Format results with enhanced information
        var formattedResults: [String] = []
        
        for (index, item) in sortedItems.enumerated() {
            let source = item.displayLink ?? extractDomain(from: item.link)
            let relevanceScore = calculateSportsRelevanceScore(for: item)
            
            let formattedResult = """
            
            RESULT \(index + 1) - \(source.uppercased()) [Relevance: \(String(format: "%.1f", relevanceScore))]
            Title: \(item.title)
            Content: \(item.snippet)
            URL: \(item.link)
            """
            
            formattedResults.append(formattedResult)
            
            // If we have high-quality results, we don't need all of them
            if formattedResults.count >= 6 && relevanceScore < 3.0 {
                break
            }
        }
        
        let totalResults = searchResult.searchInformation?.totalResults ?? "unknown"
        let searchTime = searchResult.searchInformation?.searchTime ?? 0
        
        let header = """
        GOOGLE SEARCH RESULTS (Found \(totalResults) total results in \(searchTime)s)
        Showing top \(formattedResults.count) most relevant results:
        """
        
        return header + "\n" + formattedResults.joined(separator: "\n")
    }
    
    // MARK: - Sports Relevance Scoring
    private func calculateSportsRelevanceScore(for item: GoogleSearchResponse.Item) -> Double {
        var score = 0.0
        
        let titleLower = item.title.lowercased()
        let snippetLower = item.snippet.lowercased()
        let linkLower = item.link.lowercased()
        let combinedText = titleLower + " " + snippetLower
        
        // High-value sports websites
        let premiumSites = [
            "espn.com": 5.0,
            "cbssports.com": 4.5,
            "nfl.com": 4.5,
            "nba.com": 4.5,
            "mlb.com": 4.5,
            "nhl.com": 4.5,
            "si.com": 4.0,
            "bleacherreport.com": 3.5,
            "sports.yahoo.com": 3.5,
            "foxsports.com": 3.5
        ]
        
        for (site, value) in premiumSites {
            if linkLower.contains(site) {
                score += value
                break
            }
        }
        
        // Game result indicators (high value)
        let resultIndicators = [
            "final score": 3.0,
            "final": 2.5,
            "recap": 2.5,
            "box score": 3.0,
            "game recap": 3.0,
            "highlights": 2.0,
            "won": 2.0,
            "lost": 2.0,
            "defeated": 2.0,
            "beat": 1.5,
            "victory": 1.5,
            "wins": 1.5,
            "loses": 1.5
        ]
        
        for (indicator, value) in resultIndicators {
            if combinedText.contains(indicator) {
                score += value
            }
        }
        
        // Score patterns (very high value - indicates actual game results)
        let scorePatterns = [
            "\\b\\d{1,3}[-–]\\d{1,3}\\b", // "24-17", "105-98"
            "\\b\\d{1,3}\\s*-\\s*\\d{1,3}\\b", // "24 - 17"
            "\\b\\d{1,3}\\s+\\d{1,3}\\b" // "24 17" (less common)
        ]
        
        for pattern in scorePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: combinedText, options: [], range: NSRange(location: 0, length: combinedText.utf16.count))
                if matches.count > 0 {
                    score += 4.0 // Very high value for actual scores
                    break
                }
            }
        }
        
        // Time indicators (recent games are more likely to have results)
        let timeIndicators = [
            "today": 1.0,
            "yesterday": 1.0,
            "final": 1.5,
            "ended": 1.5,
            "completed": 1.0
        ]
        
        for (indicator, value) in timeIndicators {
            if combinedText.contains(indicator) {
                score += value
            }
        }
        
        // Negative indicators (reduce score for irrelevant content)
        let negativeIndicators = [
            "preview": -2.0,
            "prediction": -1.5,
            "odds": -1.0,
            "betting": -1.0,
            "schedule": -1.0,
            "upcoming": -1.5,
            "will play": -2.0,
            "expected": -1.0,
            "projected": -1.0
        ]
        
        for (indicator, penalty) in negativeIndicators {
            if combinedText.contains(indicator) {
                score += penalty
            }
        }
        
        return max(0, score) // Don't allow negative scores
    }
    
    // MARK: - Enhanced Date-Aware Search
    @available(iOS 15.0, *)
    func performDateAwareSportsSearch(query: String, betDate: String, numResults: Int = 8) async throws -> String {
        let dateFormatter = ISO8601DateFormatter()
        var searchQueries: [String] = []
        
        // Parse the bet date
        if let date = dateFormatter.date(from: betDate) {
            let calendar = Calendar.current
            let now = Date()
            
            // Determine search date range strategy
            if calendar.isDate(date, inSameDayAs: now) {
                // Today's game - search for live results
                searchQueries.append(query)
                searchQueries.append("\(query) live score")
                searchQueries.append("\(query) today")
            } else if date < now {
                // Past game - search for final results
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "MMMM d"
                let dateString = dayFormatter.string(from: date)
                
                searchQueries.append("\(query) final score")
                searchQueries.append("\(query) \(dateString) final")
                searchQueries.append("\(query) result")
            } else {
                // Future game - unlikely to have results
                searchQueries.append(query)
            }
        } else {
            // Fallback to original query
            searchQueries.append(query)
        }
        
        // Try each search query and return the best result
        var bestResult = ""
        var bestScore = 0.0
        
        for searchQuery in searchQueries {
            do {
                let result = try await performSportsOptimizedGoogleSearch(
                    query: searchQuery,
                    numResults: numResults
                )
                
                let score = evaluateSearchResultQuality(result)
                print("🔍 Query '\(searchQuery)' scored: \(score)")
                
                if score > bestScore {
                    bestResult = result
                    bestScore = score
                }
                
                // If we found a very good result, no need to continue
                if score >= 8.0 {
                    break
                }
                
            } catch {
                print("❌ Search query '\(searchQuery)' failed: \(error)")
                continue
            }
        }
        
        return bestResult
    }
    
    // MARK: - Search Result Quality Evaluation
    private func evaluateSearchResultQuality(_ searchResults: String) -> Double {
        var qualityScore = 0.0
        let resultsLower = searchResults.lowercased()
        
        // High-quality indicators
        let qualityIndicators = [
            "espn.com": 3.0,
            "cbssports.com": 2.5,
            "final score": 4.0,
            "game recap": 3.0,
            "box score": 3.5,
            "nfl.com": 2.5,
            "nba.com": 2.5,
            "mlb.com": 2.5,
            "nhl.com": 2.5
        ]
        
        for (indicator, score) in qualityIndicators {
            if resultsLower.contains(indicator) {
                qualityScore += score
            }
        }
        
        // Check for score patterns
        let scorePattern = "\\b\\d{1,3}[-–]\\d{1,3}\\b"
        if let regex = try? NSRegularExpression(pattern: scorePattern, options: []) {
            let matches = regex.matches(in: searchResults, options: [], range: NSRange(location: 0, length: searchResults.utf16.count))
            qualityScore += Double(matches.count) * 2.0
        }
        
        // Penalty for low-quality content
        let lowQualityIndicators = [
            "no search results found": -5.0,
            "preview": -1.0,
            "prediction": -1.0,
            "upcoming": -1.0
        ]
        
        for (indicator, penalty) in lowQualityIndicators {
            if resultsLower.contains(indicator) {
                qualityScore += penalty
            }
        }
        
        // Bonus for content length (more content usually means better results)
        let contentLengthBonus = min(2.0, Double(searchResults.count) / 1000.0)
        qualityScore += contentLengthBonus
        
        return max(0, qualityScore)
    }
    
    // MARK: - Multi-Source Sports Data Aggregation
    @available(iOS 15.0, *)
    func aggregateSportsDataFromMultipleSources(query: String, betDate: String) async throws -> String {
        print("🔍 Starting multi-source sports data aggregation")
        
        var allResults: [String] = []
        var sources: [String] = []
        
        // Source 1: Enhanced Google Search
        do {
            let googleResults = try await performDateAwareSportsSearch(
                query: query,
                betDate: betDate,
                numResults: 6
            )
            allResults.append(googleResults)
            sources.append("Google Custom Search")
            print("✅ Google search completed")
        } catch {
            print("❌ Google search failed: \(error)")
        }
        
        // Source 2: Direct ESPN search (if we can construct a good query)
        let entities = extractSportsEntitiesFromQuery(query)
        if !entities.teams.isEmpty {
            do {
                let espnQuery = "site:espn.com \(entities.teams.joined(separator: " ")) final score"
                let espnResults = try await performSportsOptimizedGoogleSearch(
                    query: espnQuery,
                    numResults: 3
                )
                allResults.append("ESPN SPECIFIC SEARCH:\n\(espnResults)")
                sources.append("ESPN Direct")
                print("✅ ESPN direct search completed")
            } catch {
                print("❌ ESPN direct search failed: \(error)")
            }
        }
        
        // Source 3: CBS Sports search
        if !entities.teams.isEmpty {
            do {
                let cbsQuery = "site:cbssports.com \(entities.teams.joined(separator: " ")) result"
                let cbsResults = try await performSportsOptimizedGoogleSearch(
                    query: cbsQuery,
                    numResults: 3
                )
                allResults.append("CBS SPORTS SPECIFIC SEARCH:\n\(cbsResults)")
                sources.append("CBS Sports Direct")
                print("✅ CBS Sports search completed")
            } catch {
                print("❌ CBS Sports search failed: \(error)")
            }
        }
        
        let aggregatedResult = """
        AGGREGATED SPORTS DATA FROM \(sources.count) SOURCES:
        Sources: \(sources.joined(separator: ", "))
        
        \(allResults.joined(separator: "\n\n" + String(repeating: "=", count: 50) + "\n\n"))
        """
        
        print("🔍 Multi-source aggregation completed with \(sources.count) sources")
        return aggregatedResult
    }
    
    // MARK: - Sports Entity Extraction
    private func extractSportsEntities(from betPrompt: String) -> SportsEntities {
        var teams: [String] = []
        var players: [String] = []
        var league: String?
        var sport: String?
        
        let prompt = betPrompt.lowercased()
        
        // Extract teams (look for common patterns)
        let teamPatterns = [
            "\\b([A-Z][a-z]+ [A-Z][a-z]+)\\b", // "Los Angeles Lakers"
            "\\b([A-Z][a-z]+)\\s+vs\\s+([A-Z][a-z]+)", // "Lakers vs Warriors"
            "\\b([A-Z]{2,})\\s+vs\\s+([A-Z]{2,})", // "LAL vs GSW"
        ]
        
        for pattern in teamPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: betPrompt, options: [], range: NSRange(location: 0, length: betPrompt.utf16.count))
                for match in matches {
                    for rangeIndex in 1..<match.numberOfRanges {
                        let range = match.range(at: rangeIndex)
                        if range.location != NSNotFound, let swiftRange = Range(range, in: betPrompt) {
                            let team = String(betPrompt[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !team.isEmpty && !teams.contains(team) {
                                teams.append(team)
                            }
                        }
                    }
                }
            }
        }
        
        // Detect leagues
        let leagueKeywords = [
            ("nfl", "NFL"),
            ("nba", "NBA"),
            ("mlb", "MLB"),
            ("nhl", "NHL"),
            ("premier league", "Premier League"),
            ("champions league", "Champions League"),
            ("la liga", "La Liga"),
            ("bundesliga", "Bundesliga"),
            ("serie a", "Serie A"),
            ("mls", "MLS"),
            ("ncaa", "NCAA"),
            ("college football", "NCAA Football"),
            ("college basketball", "NCAA Basketball")
        ]
        
        for (keyword, fullName) in leagueKeywords {
            if prompt.contains(keyword) {
                league = fullName
                break
            }
        }
        
        // Detect sports
        let sportKeywords = [
            ("football", "Football"),
            ("basketball", "Basketball"),
            ("baseball", "Baseball"),
            ("hockey", "Hockey"),
            ("soccer", "Soccer"),
            ("tennis", "Tennis"),
            ("golf", "Golf"),
            ("boxing", "Boxing"),
            ("mma", "MMA")
        ]
        
        for (keyword, fullName) in sportKeywords {
            if prompt.contains(keyword) {
                sport = fullName
                break
            }
        }
        
        return SportsEntities(teams: teams, players: players, league: league, sport: sport)
    }
    
    // MARK: - Helper function for entity extraction (simplified version)
    private func extractSportsEntitiesFromQuery(_ query: String) -> SimpleSportsEntities {
        var teams: [String] = []
        var league: String?
        
        // Simple team extraction - look for capitalized words that might be team names
        let words = query.components(separatedBy: .whitespaces)
        var potentialTeam = ""
        
        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
            if cleanWord.first?.isUppercase == true {
                potentialTeam += cleanWord + " "
            } else if !potentialTeam.isEmpty {
                teams.append(potentialTeam.trimmingCharacters(in: .whitespaces))
                potentialTeam = ""
            }
        }
        
        // Don't forget the last potential team
        if !potentialTeam.isEmpty {
            teams.append(potentialTeam.trimmingCharacters(in: .whitespaces))
        }
        
        // Simple league detection
        let queryLower = query.lowercased()
        if queryLower.contains("nfl") {
            league = "NFL"
        } else if queryLower.contains("nba") {
            league = "NBA"
        } else if queryLower.contains("mlb") {
            league = "MLB"
        } else if queryLower.contains("nhl") {
            league = "NHL"
        }
        
        return SimpleSportsEntities(teams: teams, league: league)
    }
    
    // MARK: - Utility Functions
    private func extractDomain(from url: String) -> String {
        guard let urlObj = URL(string: url) else { return "unknown" }
        return urlObj.host ?? "unknown"
    }
    
    // MARK: - Updated performGoogleCustomSearch method (backward compatibility)
    @available(iOS 15.0, *)
    func performGoogleCustomSearch(query: String, numResults: Int = 3) async throws -> String {
        // Use the enhanced sports-optimized search
        return try await performSportsOptimizedGoogleSearch(query: query, numResults: numResults)
    }
    
    @available(iOS 15.0, *)
    public func searchAndAskGeminiWithGoogle(query: String, question: String) async throws -> String {
        let searchSummary = try await performGoogleCustomSearch(query: query)
        let prompt = """
        Here are search results for "\(query)":\n\n\(searchSummary)\n\n
        Based on these, answer:\n\(question)
        """
        return try await sendPrompt(prompt, model: defaultModel, temperature: 0.7, maxTokens: 2048)
    }
    
    @available(iOS 15.0, *)
    func parseNaturalLanguageDate(text: String, referenceDate: Date = Date()) async throws -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let referenceDateString = formatter.string(from: referenceDate)
        
        let prompt = """
        Current date and time: \(referenceDateString)
        
        Parse any date/time information from this text: "\(text)"
        
        Common patterns to recognize:
        - "tonight" → today at 8:00 PM
        - "tomorrow" → tomorrow at 7:00 PM  
        - "tomorrow night" → tomorrow at 8:00 PM
        - "tomorrow morning" → tomorrow at 10:00 AM
        - "Sunday", "Monday", etc → next occurrence at 7:00 PM
        - "Sunday morning" → next Sunday at 10:00 AM
        - "this weekend" → next Saturday at 7:00 PM
        - "next week" → next Monday at 7:00 PM
        - Times like "7pm", "3:30 PM", "8:00" → combine with detected day
        
        Default times when not specified:
        - morning: 10:00 AM
        - afternoon: 2:00 PM  
        - evening/night: 8:00 PM
        - no time specified: 7:00 PM
        
        Return the parsed date in format: YYYY-MM-DD HH:MM:SS
        If no date/time found, return exactly: NONE
        
        Examples:
        - "Who will win the game tonight?" → \(formatter.string(from: Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: referenceDate) ?? referenceDate))
        - "Tomorrow morning meeting" → \(formatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: referenceDate) ?? referenceDate) ?? referenceDate))
        """
        
        let response = try await sendPrompt(
            prompt,
            model: "gemini-2.5-flash-lite",
            temperature: 0.1,
            maxTokens: 50
        )
        
        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanResponse.uppercased() == "NONE" {
            return nil
        }
        
        return formatter.date(from: cleanResponse)
    }
    
    @available(iOS 15.0, *)
    public func requestWithSearch(prompt: String) async throws -> [String] {

        let responseText = try await sendPromptWithSearch(prompt, model: defaultModel, temperature: 0.9, maxTokens: 10000)

        print("📦 Full responseText:\n\(responseText)\n")

        // Extract JSON array from response string
        guard let start = responseText.firstIndex(of: "["),
              let end = responseText.lastIndex(of: "]") else {
            print("⚠️ Failed to find valid JSON array in response.")
            throw AIServiceError.decodingError
        }

        let jsonString = String(responseText[start...end])
        print("🔍 Extracted jsonString:\n\(jsonString)\n")

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("⚠️ Failed to convert jsonString to Data.")
            throw AIServiceError.decodingError
        }

        let response = try JSONDecoder().decode([String].self, from: jsonData)
        return response.filter { !$0.lowercased().contains("bet") }
    }
    
    public func sendPromptWithSearch(
        _ prompt: String,
        model: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        guard let apiKey = APIKeyManager.shared.getCurrentAPIKey() else {
            throw AIServiceError.allKeysExhausted
        }
        
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw AIServiceError.invalidURL
        }

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "tools": [
                [
                    "google_search": [:]
                ]
            ],
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": maxTokens
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, _) = try await URLSession.shared.data(for: request)

        // Debug: Print the raw response from Gemini
        if let raw = String(data: data, encoding: .utf8) {
            print("🔥 Raw Gemini Response:\n\(raw)")
        }

        let decoder = JSONDecoder()
        do {
            let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
            if let candidates = geminiResponse.candidates,
               let text = candidates.first?.content.parts.first?.text {

                return text
            } else {
                throw AIServiceError.missingResponse
            }
        } catch {
            print("❌ Decoding error: \(error)")
            throw AIServiceError.decodingError
        }
    }
}
