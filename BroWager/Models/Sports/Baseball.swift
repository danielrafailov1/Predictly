//
//  Baseball.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-06-06.
//

import Foundation
import SwiftUI

struct BaseballGame: Identifiable, Codable, Hashable {
    let id: Int
    let home_team_name: String
    let away_team_name: String
    let date: String
}

struct BaseballResponse: Codable {
    let data: [BaseballGame]
}
