//
//  BroWagerApp.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-15.
//

import SwiftUI
import Supabase
import GoogleSignIn  // Add this import

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
        
        // Configure Google Sign-In
        if let clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
            print("✅ Google Sign-In configured with client ID: \(clientId)")
        } else {
            print("❌ Failed to configure Google Sign-In: GIDClientID not found in Info.plist")
        }
        
        // ADD THIS: Request notification permissions
        Task {
            await NotificationManager.shared.requestPermission()
        }
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
                print("\n🔴 =================================")
                print("🔴 onOpenURL called!")
                print("🔴 =================================")
                print("🔴 URL: \(url)")
                print("🔴 URL scheme: \(url.scheme ?? "nil")")
                print("🔴 URL host: \(url.host ?? "nil")")
                print("🔴 URL path: \(url.path)")
                print("🔴 URL query: \(url.query ?? "nil")")
                
                // Handle Google Sign-In URLs first
                if GIDSignIn.sharedInstance.handle(url) {
                    print("✅ URL handled by Google Sign-In SDK")
                    return
                } else {
                    print("🟡 URL not handled by Google Sign-In SDK")
                }
                
                // Handle custom OAuth callback URLs
                print("🔴 Posting notification for custom URL handling...")
                NotificationCenter.default.post(name: .receivedURL, object: url)
                print("🔴 onOpenURL completed\n")
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
                Image("titan")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 250, height: 250)
                    .clipped()
                Text("Bet Titan")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
            .previewLayout(.sizeThatFits) // Adjusts the preview to fit content size
            .preferredColorScheme(.dark)  // Optional: Show it in dark mode
    }
}
