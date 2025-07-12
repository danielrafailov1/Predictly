//
//  Basketball.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-06-06.
//

import Foundation
import SwiftUI

struct GameResponse: Codable {
    let data: [BasketballGame]
}

struct BasketballGame: Codable, Identifiable, Hashable {
    let id: Int
    let datetime: String
    let home_team: Team
    let visitor_team: Team
}

struct Team: Codable, Hashable {
    let full_name: String
}
