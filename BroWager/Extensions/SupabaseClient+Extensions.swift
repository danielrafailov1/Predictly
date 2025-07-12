//
//  SupabaseClient+Extensions.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-15.
//

import Foundation
import Supabase

extension SupabaseClient {
    
    static var development: SupabaseClient {
        SupabaseClient(
          supabaseURL: URL(string: "https://wwqbjakkuprsyvwxlgch.supabase.co")!,
          supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind3cWJqYWtrdXByc3l2d3hsZ2NoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDczMzMxNDUsImV4cCI6MjA2MjkwOTE0NX0.9BTfCnpDCIzQ8Zve69JpJ6_B_AeGier_uuEQgNBlqMM")
    }
}
