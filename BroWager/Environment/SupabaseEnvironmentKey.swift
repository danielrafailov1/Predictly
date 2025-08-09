//
//  SupabaseEnvironmentKey.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-15.
//

import Foundation
import SwiftUI
import Supabase

struct SupabaseEnvironmentKey: EnvironmentKey {
    static var defaultValue: SupabaseClient = .development
}

extension EnvironmentValues {
    var supabaseClient: SupabaseClient {
        get { self[SupabaseEnvironmentKey.self] }
        set { self[SupabaseEnvironmentKey.self] = newValue }
    }
}
