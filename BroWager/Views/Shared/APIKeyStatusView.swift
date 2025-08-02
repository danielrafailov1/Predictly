//
//  APIKeyStatusView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-08-02.
//

import SwiftUI

struct APIKeyStatusView: View {
    @State private var keyStatuses: [(key: String, usage: Int, blocked: Bool)] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(keyStatuses.enumerated()), id: \.offset) { index, status in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(status.key)
                                .font(.headline)
                            Text("Usage: \(status.usage)/1000")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if status.blocked {
                            Text("BLOCKED")
                                .foregroundColor(.red)
                                .font(.caption)
                                .fontWeight(.bold)
                        } else {
                            Text("ACTIVE")
                                .foregroundColor(.green)
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Button("Reset All Keys") {
                    APIKeyManager.shared.resetKeyUsage()
                    loadKeyStatuses()
                }
                .foregroundColor(.blue)
            }
            .navigationTitle("API Key Status")
            .onAppear {
                loadKeyStatuses()
            }
        }
    }
    
    private func loadKeyStatuses() {
        keyStatuses = APIKeyManager.shared.getKeyStatus()
    }
}
