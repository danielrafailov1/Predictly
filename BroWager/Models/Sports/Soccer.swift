//
//  Soccer.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-06-06.
//

import Foundation
import SwiftUI

struct SoccerGame: Identifiable, Codable, Hashable {
    let id: Int
    let home_team_id: Int
    let away_team_id: Int
    let kickoff: String
    let status: String
}

struct SoccerResponse: Codable {
    let data: [SoccerGame]
}

struct SoccerTeam: Codable, Hashable {
    let id: Int
    let name: String
    let abbr: String
}

struct SoccerTeamResponse: Codable {
    let data: [SoccerTeam]
}
