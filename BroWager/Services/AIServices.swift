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
            
            print(geminiResponse)
            
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
        You are a bet suggestion generator. A group of friends are hanging out and they want to make a bet. Generate \(count) bets \(betType) in JSON format. For each bet, only generate a string of the bet content. 
        """

        let responseText = try await sendPrompt(prompt, model: defaultModel, temperature: 0.9, maxTokens: 10000)

        // Extract JSON array from response string

        guard let start = responseText.firstIndex(of: "["),
              let end = responseText.lastIndex(of: "]") else {
            throw AIServiceError.decodingError
        }
        let jsonString = String(responseText[start...end])
        print(jsonString)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIServiceError.decodingError
        }
        try print(JSONDecoder().decode([String].self, from: jsonData))

        return try JSONDecoder().decode([String].self, from: jsonData)
    }
}

