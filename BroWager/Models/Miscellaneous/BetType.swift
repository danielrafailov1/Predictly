import Foundation

public enum BetType: String, CaseIterable, Identifiable, Codable {
    case normal = "Normal"
    case timed = "Timed"
    case contest = "Contest"
    public var id: String { rawValue }
} 