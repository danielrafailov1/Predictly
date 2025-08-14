import Foundation

public enum BetType: String, CaseIterable, Identifiable, Codable {
    case predefined = "Predefined Challenge"
    case draftTeam = "Draft Team Challenge"
    case randomPlayer = "Random Player"
    case statBased = "Stat-Based"
    case outcomeBased = "Outcome-Based"
    case custom = "Custom"
    case politics = "Politics"
    case food = "Food"
    case lifeEvents = "Life Events"
    public var id: String { rawValue }
} 
