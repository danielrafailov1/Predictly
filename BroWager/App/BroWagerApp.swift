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

    // Load Supabase credentials from Info.plist
    static let client: SupabaseClient = {
        guard
            let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
            let key = Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String,
            let url = URL(string: urlString)
        else {
            fatalError("Missing or invalid Supabase URL or Key in Info.plist")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()

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
