//
//  Instrument.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-15.
//

import Foundation

struct Instrument: Decodable, Identifiable {
  let id: Int
  let name: String
}
