//
//  Hockey.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-06-06.
//

import Foundation
import SwiftUI

struct NHLGame: Identifiable {
    let id: Int
    let homeTeam: String
    let awayTeam: String
    let dateTime: String
}

struct NHLScheduleResponse: Codable {
    let dates: [NHLDate]
}

struct NHLDate: Codable {
    let date: String
    let games: [NHLGameRaw]
}

struct NHLGameRaw: Codable {
    let gamePk: Int
    let gameDate: String
    let teams: NHLTeams
}

struct NHLTeams: Codable {
    let home: NHLTeamDetail
    let away: NHLTeamDetail
}

struct NHLTeamDetail: Codable {
    let team: NHLTeam
}

struct NHLTeam: Codable {
    let name: String
}
