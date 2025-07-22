//
//  AIServices.swift
//  BroWager
//
//  Created by Nachuan Wang on 2025-07-21.
//
//
//private func checkBetResults() async {
//    guard let userId = currentUserId, let partyId = partyId, let game = selectedGame else { return }
//    
//    struct UserBetEvents: Codable {
//        let bet_events: [String]
//    }
//    do {
//        // 1. Fetch the user's bets
//        let betResponse: [UserBetEvents] = try await supabaseClient
//            .from("User Bets")
//            .select("bet_events")
//            .eq("user_id", value: userId)
//            .eq("party_id", value: Int(partyId))
//            .limit(1)
//            .execute()
//            .value
//        
//        print("DEBUG: betResponse = \(betResponse)")
//        
//        guard let userBet = betResponse.first else {
//            await MainActor.run {
//                self.errorMessage = "No bet found for this party. Please make a bet first."
//            }
//            print("DEBUG: No bet found for userId=\(userId), partyId=\(partyId)")
//            return
//        }
//        print("DEBUG: userBet.bet_events = \(userBet.bet_events)")
//        // 2. Create the prompt for Gemini
//        let prompt = """
//        You are a sports game fact-checker. For the baseball game between \(game.home_team_name) and \(game.away_team_name) that occurred on \(game.date), please analyze the following list of predicted events. Return a JSON object with a single key \"correct_bets\" which holds an array of strings. This array should contain ONLY the predicted events from the list that actually happened.
//
//        List of predicted events:
//        \(userBet.bet_events.joined(separator: "\n"))
//        """
//
//        // 3. Call Gemini API
//        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyBPjz5MsImnnmKvyltj6X6h7E-JqVufe4E") else {
//            // Replace YOUR_GEMINI_API_KEY with your actual key
//            self.errorMessage = "Invalid Gemini API URL"
//            return
//        }
//        
//        let requestBody: [String: Any] = [
//            "contents": [["parts": [["text": prompt]]]],
//            "generationConfig": ["response_mime_type": "application/json"]
//        ]
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
//        
//        let (data, _) = try await URLSession.shared.data(for: request)
//        print("DEBUG: Gemini raw response = \(String(data: data, encoding: .utf8) ?? "nil")")
//        // 4. Parse response and update score
//        struct GeminiResponse: Decodable {
//            struct Candidate: Decodable {
//                struct Content: Decodable {
//                    struct Part: Decodable {
//                        let text: String
//                    }
//                    let parts: [Part]
//                }
//                let content: Content
//            }
//            let candidates: [Candidate]
//        }
//
//        let responseText = try JSONDecoder().decode(GeminiResponse.self, from: data).candidates.first?.content.parts.first?.text ?? ""
//        print("DEBUG: Gemini responseText = \(responseText)")
//        struct ResultPayload: Decodable {
//            let correct_bets: [String]
//        }
//        
//        let resultData = Data(responseText.utf8)
//        let finalResult = try JSONDecoder().decode(ResultPayload.self, from: resultData)
//        
//        let correctBetsArray = finalResult.correct_bets
//        let score = correctBetsArray.count
//        
//        // 5. Update the UserBets table
//        try await supabaseClient
//            .from("User Bets")
//            .update(["score": score])
//            .eq("user_id", value: userId)
//            .eq("party_id", value: Int(partyId))
//            .execute()
//            
//        // 6. Update the UI
//        await MainActor.run {
//            self.score = score
//            self.correctBets = correctBetsArray
//        }
//        
//    } catch {
//        await MainActor.run {
//            self.errorMessage = "Failed to check results: \(error.localizedDescription)"
//        }
//        print("DEBUG: Error in checkBetResults: \(error)")
//    }
//}

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
        }
    }
}

// MARK: - AI Service Class for Gemini
public class AIServices {
    
    // MARK: - Properties
    public static let shared = AIServices()
    
    private let session: URLSession
    private let baseURL: String
    private let apiKey: String
    private let defaultModel: String
    
    // MARK: - Initialization
    private init() {
        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
        
        // Load API key from Info.plist or environment
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String ?? ""
        
        // Gemini API configuration
        self.baseURL = "https://generativelanguage.googleapis.com/v1beta/models/"
        self.defaultModel = "gemini-2.5-flash" // or "gemini-pro"
    }
    
    // MARK: - Public Methods
    
    /// Send a simple text prompt to Gemini
    func sendPrompt(_ prompt: String,
                   model: String? = nil,
                   temperature: Double? = nil,
                   maxTokens: Int? = nil,
                   completion: @escaping (Result<String, AIServiceError>) -> Void) {
        
        let content = GeminiContent(
            parts: [GeminiPart(text: prompt)],
            role: nil
        )
        
        sendContents([content], model: model, temperature: temperature, maxTokens: maxTokens) { result in
            switch result {
            case .success(let response):
                let text = response.candidates?.first?.content.parts.first?.text ?? ""
                completion(.success(text))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Send conversation contents to Gemini
    func sendContents(_ contents: [GeminiContent],
                     model: String? = nil,
                     temperature: Double? = nil,
                     maxTokens: Int? = nil,
                     completion: @escaping (Result<GeminiResponse, AIServiceError>) -> Void) {
        
        guard !apiKey.isEmpty else {
            completion(.failure(.noAPIKey))
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
    func sendPrompt(_ prompt: String,
                   model: String? = nil,
                   temperature: Double? = nil,
                   maxTokens: Int? = nil) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            sendPrompt(prompt, model: model, temperature: temperature, maxTokens: maxTokens) { result in
                continuation.resume(with: result)
            }
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
            break
        case 400:
            completion(.failure(.apiError("Bad Request - Check your request format")))
            return
        case 401, 403:
            completion(.failure(.unauthorized))
            return
        case 429:
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
    
    
    /// Generate suggestions for bets
    @available(iOS 15.0, *)
    public func generateBetSuggestions(betType: String, count: Int) async throws -> [String] {
        let prompt = """
        You are a bet suggestion generator. A group of friends are hanging out and they want to make a bet. Generate \(count) bets of type \(betType) in JSON format. For each bet, only generate a string of the bet content. 
        """

        let responseText = try await sendPrompt(prompt, model: defaultModel, temperature: 0.9, maxTokens: 200)

        // Extract JSON array from response string
        guard let start = responseText.firstIndex(of: "["),
              let end = responseText.lastIndex(of: "]") else {
            throw AIServiceError.decodingError
        }

        let jsonString = String(responseText[start...end])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.decodingError
        }
        try print(JSONDecoder().decode([String].self, from: jsonData))

        return try JSONDecoder().decode([String].self, from: jsonData)
    }
}

