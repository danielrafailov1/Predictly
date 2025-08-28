//
//  PerplexityService.swift
//  BroWager
//
//  Created by Nachuan Wang on 2025-08-20.
//

import Foundation

struct PerplexityAPI {
    private let apiKey: String
    private let baseURL = URL(string: "https://api.perplexity.ai")!
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Makes a request to Perplexity with the given prompt
    func ask(_ prompt: String) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "sonar",
            "input": prompt
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let output = json["output"] as? String {
                return output
            }
            return json.description
        } else {
            throw NSError(domain: "PerplexityAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
    }
}
