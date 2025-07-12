//
//  BroWagerApp.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-15.
//

import SwiftUI
import Supabase

extension Notification.Name {
    static let receivedURL = Notification.Name("ReceivedURL")
}

@main
struct BroWagerApp: App {
    
    @AppStorage("isMusicOn") private var isMusicOn: Bool = true
    
    static let client = SupabaseClient(
      supabaseURL: URL(string: "https://wwqbjakkuprsyvwxlgch.supabase.co")!,
      supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind3cWJqYWtrdXByc3l2d3hsZ2NoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDczMzMxNDUsImV4cCI6MjA2MjkwOTE0NX0.9BTfCnpDCIzQ8Zve69JpJ6_B_AeGier_uuEQgNBlqMM"
    )

    @State private var showSplash = true
    @StateObject private var sessionManager: SessionManager

    init() {
        _sessionManager = StateObject(wrappedValue: SessionManager(supabaseClient: BroWagerApp.client))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                } else {
                    RootView()
                        .environmentObject(sessionManager)
                        .environment(\.supabaseClient, BroWagerApp.client)
                }
            }
            .environment(\.supabaseClient, BroWagerApp.client)
            .environmentObject(sessionManager)
            .onAppear {
                Task {
                    await sessionManager.refreshSession()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showSplash = false
                    }
                }
            }
            .onOpenURL { url in
                print("onOpenURL called with: \(url)")
                NotificationCenter.default.post(name: .receivedURL, object: url)
            }
        }
    }
}

// Simple splash screen view
struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                Text("BroWager")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
}
