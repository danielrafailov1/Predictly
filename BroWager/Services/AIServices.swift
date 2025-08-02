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

// MARK: - AI Service Class for Gemini + Search
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
        
        // Load Gemini API key from Info.plist or environment
        
        // Gemini API base URL and model
        self.baseURL = "https://generativelanguage.googleapis.com/v1beta/models/"
        self.defaultModel = "gemini-2.5-flash" // or "gemini-pro"
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
        // Add this line to get the API key
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

        // 🔥 Debug: Print the raw response from Gemini
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
        
        // Add this guard to get the API key
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
        You are a bet suggestion generator. A group of friends are hanging out and they want to make a bet. Generate \(count) bets of type \(betType) in JSON format. For each bet, only generate a string of the bet content. 
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

        // Decode and return
        return try JSONDecoder().decode([String].self, from: jsonData)
    }

    
    /// Generate suggestions for bets (alternative)
    @available(iOS 15.0, *)
    public func generateBetSuggestions(prompt: String) async throws -> [String] {
     
        let responseText = try await sendPrompt(prompt, model: defaultModel, temperature: 0.9, maxTokens: 10000)

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
        
        try print(JSONDecoder().decode([String].self, from: jsonData))
        
        return try JSONDecoder().decode([String].self, from: jsonData)
    }
    
    // MARK: - Google Custom Search API Integration
    
    @available(iOS 15.0, *)
    func performGoogleCustomSearch(query: String, numResults: Int = 3) async throws -> String {
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CSE_API_KEY") as? String ?? ""
        let engineId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CSE_ENGINE_ID") as? String ?? ""
        if apiKey.isEmpty || engineId.isEmpty {
            throw AIServiceError.noAPIKey
        }
        
        var components = URLComponents(string: "https://www.googleapis.com/customsearch/v1")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "cx", value: engineId),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "num", value: "\(numResults)")
        ]
        
        guard let url = components.url else {
            throw AIServiceError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        struct GoogleSearchResponse: Codable {
            struct Item: Codable {
                let title: String
                let snippet: String
                let link: String
            }
            let items: [Item]?
        }
        
        let searchResult = try JSONDecoder().decode(GoogleSearchResponse.self, from: data)
        let items = searchResult.items ?? []
        
        return items.map { "🔗 \($0.title): \($0.snippet) (\($0.link))" }
                    .joined(separator: "\n\n")
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
}
