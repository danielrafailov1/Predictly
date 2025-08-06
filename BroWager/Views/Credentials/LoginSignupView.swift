//
//  ContentView.swift
//  BroWager2
//
//  Created by Daniel Rafailov on 2025-05-13.
//

import SwiftUI
import AVFoundation
import AuthenticationServices

struct LoginSignupView: View {
    
    @Environment(\.supabaseClient) private var supabaseClient
    @EnvironmentObject var sessionManager: SessionManager
    @State private var logins: [LoginInfo] = []
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var emailExists: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String? = nil
    @State private var emails: [String] = []
    @State private var isLoginScreenActive: Bool = false
    @State private var isSignUpMode: Bool = false
    @State private var isChooseUsernameActive = false
    @State private var newUserId: String? = nil
    @State private var newUserEmail: String? = nil
    @State private var newUserPassword: String? = nil
    @State private var resolvedEmail: String? = nil
    @State private var isGoogleLoading: Bool = false
    @State private var navPath = NavigationPath()
    @State private var showWelcome = false
    @State private var appleSignInError: String? = nil
    @State private var isLoading: Bool = false
    
    // Computed property to check password strength
    private var isPasswordStrong: Bool {
        let password = self.password
        let minLength = password.count >= 8
        let hasUpper = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLower = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
        return minLength && hasUpper && hasLower && hasDigit && hasSpecial
    }
    
    private func fetchEmails() async {
        do {
            let result: [EmailRow] = try await supabaseClient
                .from("Login Information")
                .select("email")
                .execute()
                .value
            emails = result.map { $0.email }
        } catch {
            print(error)
        }
        if emails.contains(email) {
            emailExists = true
            showError = true
        } else {
            emailExists = false
            showError = false
        }
    }
    
    private func login() async {
        var loginEmail = email
    
        if !email.contains("@") {
            do {
                
                struct UsernameRow: Decodable { let user_id: String }
                let usernameResp = try await supabaseClient
                    .from("Username")
                    .select("user_id")
                    .eq("username", value: email)
                    .limit(1)
                    .execute()
                let usernameRow = try JSONDecoder().decode(UsernameRow.self, from: usernameResp.data)
                let userId = usernameRow.user_id
                
                struct EmailRow: Decodable { let email: String }
                let emailResp = try await supabaseClient
                    .from("Login Information")
                    .select("email")
                    .eq("user_id", value: userId)
                    .limit(1)
                    .execute()
                let emailRow = try JSONDecoder().decode(EmailRow.self, from: emailResp.data)
                loginEmail = emailRow.email
            } catch {
                await MainActor.run {
                    self.errorMessage = "Username not found. Please check your username or use your email."
                    self.showError = true
                }
                return
            }
        }
        do {
            let session = try await supabaseClient.auth.signIn(email: loginEmail, password: password)
            let user = session.user
            print("Logged in with user ID: \(user.id)")
            let resolved = loginEmail
            await MainActor.run {
                self.resolvedEmail = resolved
                self.showError = false
                self.errorMessage = nil
            }
            await sessionManager.refreshSession()
            self.showWelcome = true
        } catch {
            let errorText = error.localizedDescription
            print("Login failed: \(errorText)")
            await MainActor.run {
                errorMessage = errorText
                showError = true
            }
        }
    }
    
    private func signup() async {
        await fetchEmails()
        guard !emailExists else { return }
        do {
            let signupSession = try await supabaseClient.auth.signUp(email: email, password: password)
            let user = signupSession.user
            // Create new user with all required fields (do not set id)
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let newUser = LoginInfo(
                created_at: timestamp,
                email: email,
                user_id: user.id.uuidString,
                music_on: false,
                wins: 0
            )
            try await supabaseClient
                .from("Login Information")
                .insert(newUser)
                .execute()
            // Save user_id, email, and password for username selection
            await MainActor.run {
                self.newUserId = user.id.uuidString
                self.newUserEmail = email
                self.newUserPassword = password
                self.isChooseUsernameActive = true
            }
        } catch {
            print("Error inserting user: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func handleOAuthCallback(_ notification: Notification) {
        guard let url = notification.object as? URL else {
            print("onReceive: No URL in notification")
            return
        }
        
        Task {
            do {
                let session = try await supabaseClient.auth.session(from: url)
                let user = session.user
                
                struct LoginInfoRow: Decodable { let user_id: String }
                
                let loginInfoResp = try await supabaseClient
                    .from("Login Information")
                    .select("user_id")
                    .eq("user_id", value: user.id.uuidString)
                    .limit(1)
                    .execute()
                
                let loginInfoRows = try JSONDecoder().decode([LoginInfoRow].self, from: loginInfoResp.data)
                
                if loginInfoRows.isEmpty {
                    
                    let timestamp = ISO8601DateFormatter().string(from: Date())
                    let newLoginInfo = LoginInfo(
                        created_at: timestamp,
                        email: user.email ?? "",
                        user_id: user.id.uuidString,
                        music_on: false,
                        wins: 0
                    )
                    
                    _ = try await supabaseClient
                        .from("Login Information")
                        .insert(newLoginInfo)
                        .execute()
                    
                } else {
                    print("[OAuth] Login Information row already exists for user_id: \(user.id.uuidString)")
                }
                
                struct UsernameRow: Decodable { let username: String }
                
                let usernameResp = try await supabaseClient
                    .from("Username")
                    .select("username")
                    .eq("user_id", value: user.id.uuidString)
                    .limit(1)
                    .execute()
                
                let usernameRows = try JSONDecoder().decode([UsernameRow].self, from: usernameResp.data)
                
                if usernameRows.isEmpty {
                    
                    await MainActor.run {
                        self.newUserId = user.id.uuidString
                        self.newUserEmail = user.email ?? ""
                        self.isChooseUsernameActive = true
                        
                    }
                    
                } else {
                    
                    await sessionManager.refreshSession()
                    
                }
                
            } catch {
                
                print("onReceive: OAuth session error: \(error)")
                
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .topTrailing) {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Logo and Welcome Text
                        VStack(spacing: 12) {
                            Image(systemName: "sportscourt.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .padding(.bottom, 8)
                            
                            Text("BroWager")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(isSignUpMode ? "Create Your Account" : "Sign In to Your Account")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 4)
                        }
                        .padding(.top, 40)
                        
                        // Input Fields
                        VStack(spacing: 20) {
                            // Email/Username Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email or Username")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                TextField("", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                SecureField("", text: $password)
                                    .font(.system(size: 18))
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            if !isPasswordStrong && !password.isEmpty {
                                Text("Password must be at least 8 characters, include uppercase, lowercase, a digit, and a special character.")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // Action Buttons
                        Button(action: {
                            Task {
                                if isSignUpMode {
                                    await signup()
                                } else {
                                    await login()
                                }
                            }
                        }) {
                            Text(isSignUpMode ? "Sign Up" : "Sign In")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue,
                                            Color.blue.opacity(0.8)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || isLoading || (isSignUpMode && !isPasswordStrong))
                        .padding(.horizontal, 32)
                        
                        // Error message (moved up)
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.system(size: 16, weight: .medium))
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                                .padding(.horizontal, 24)
                        }
                        
                        Text("        or sign in with         ")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 16, weight: .medium))
                            .background(Color.clear)
                        
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                Task {
                                    isGoogleLoading = true
                                    do {
                                        
                                        try await supabaseClient.auth.signInWithOAuth(
                                            provider: .google,
                                            redirectTo: URL(string: "browager://login-callback")
                                        )
                                        
                                        await sessionManager.refreshSession()
                                        
                                    } catch {
                                        
                                        let errorString = error.localizedDescription.lowercased()
                                        
                                        if errorString.contains("cancel") || errorString.contains("canceled") || errorString.contains("cancelled") {
                                            showError = false
                                            errorMessage = nil
                                        } else {
                                            errorMessage = "Google sign-in failed: \(error.localizedDescription)"
                                            showError = true
                                        }
                                    }
                                    isGoogleLoading = false
                                }
                                
                            }) {
                                HStack {
                                    Image("GoogleLogo")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                    Spacer().frame(width: 12)
                                    Text(isGoogleLoading ? "Signing in..." : "Sign in with Google")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .disabled(isGoogleLoading)
                            SignInWithAppleButton { request in
                                request.requestedScopes = [.email, .fullName]
                            } onCompletion: { result in
                                Task {
                                    
                                    self.appleSignInError = nil
                                    showError = false
                                    errorMessage = nil
                                    do {
                                        guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential else {
                                            self.appleSignInError = "Apple credential missing"
                                            return
                                        }
                                        guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                                            self.appleSignInError = "Apple ID token missing"
                                            return
                                        }
                                        try await supabaseClient.auth.signInWithIdToken(
                                            credentials: .init(
                                                provider: .apple,
                                                idToken: idToken
                                            )
                                        )
                                        await sessionManager.refreshSession()
                                    } catch {
                                        
                                        let errorString = error.localizedDescription.lowercased()
                                        if errorString.contains("cancel") || errorString.contains("canceled") || errorString.contains("cancelled") {
                                            showError = false
                                            errorMessage = nil
                                            self.appleSignInError = nil
                                        } else {
                                            self.appleSignInError = "Apple Sign-In failed: \(error.localizedDescription)"
                                            showError = true
                                            errorMessage = nil
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .cornerRadius(12)
                    
                            if let error = appleSignInError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.horizontal, 32)
                        // Move sign up toggle below social buttons
                        Button(action: {
                            withAnimation {
                                isSignUpMode.toggle()
                            }
                        }) {
                            Text(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.bottom, 40)
                }
                .ignoresSafeArea(.keyboard)
                
                // Handle OAuth redirect
                .onReceive(NotificationCenter.default.publisher(for: .receivedURL)) { notification in
                    handleOAuthCallback(notification)
                }
                
            }
            .navigationDestination(for: String.self) { email in
                LoggedInView(navPath: $navPath, email: email)
            }
            .navigationDestination(for: BetFlowPath.self) { path in
                switch path {
                case .partyLobby(let game, let gameName, let email):
                    PartyLobbyView(navPath: $navPath, game: game, gameName: gameName, email: email)
                case .createParty(let party_code, let betType, let userEmail):
                    CreatePartyView(navPath: $navPath, party_code: party_code, betType: betType, userEmail: userEmail)
                case .gameEvent(let game, let partyId, let userId, let betType, let party_code, let userEmail):
                    GameEventHostView(navPath: $navPath, game: game, partyId: partyId, userId: userId, betType: betType, refreshCount: .constant(0), maxRefreshes: 3, party_code: party_code, userEmail: userEmail, fixedEvents: nil)
                case .partyDetails(let party_code, let email):
                    PartyDetailsView(party_code: party_code, email: email)
                }
            }
            NavigationLink(
                destination: (newUserId != nil && newUserEmail != nil && newUserPassword != nil) ?
                    AnyView(ChooseUsernameView(userId: newUserId!, email: newUserEmail!, password: newUserPassword!, onComplete: { email, password in
                        Task {
                            do {
                                _ = try await supabaseClient.auth.signIn(email: email, password: password)
                                await sessionManager.refreshSession()
                                self.resolvedEmail = email
                                self.showWelcome = true
                            } catch {
                                self.errorMessage = error.localizedDescription
                                self.showError = true
                            }
                        }
                    })) : AnyView(EmptyView()),
                isActive: $isChooseUsernameActive,
                label: { EmptyView() }
            )
        }
        .onChange(of: resolvedEmail) { email in
            if let email = email {
                navPath = NavigationPath()
                navPath.append(email)
            }
        }
        .sheet(isPresented: $showWelcome) {
            if let email = resolvedEmail {
                ProfileView(navPath: $navPath, email: email)
            }
        }
        // Welcome alert for new users
        .alert(isPresented: $showWelcome) {
            Alert(
                title: Text("Welcome to BroWager!"),
                message: Text("Your account has been created. Good luck!"),
                dismissButton: .default(Text("OK")) {
                    self.showWelcome = false
                }
            )
        }
        // Present ChooseUsernameView as a modal sheet for new Apple sign-in users
        .sheet(isPresented: $isChooseUsernameActive) {
            if let userId = newUserId, let email = newUserEmail {
                ChooseUsernameView(
                    userId: userId,
                    email: email,
                    password: "", // Apple sign-in, so password is blank
                    onComplete: { email, _ in
                        Task {
                            await sessionManager.refreshSession()
                            isChooseUsernameActive = false
                        }
                    }
                )
            }
        }
    }
}

#Preview {
    LoginSignupView()
        .environment(\.supabaseClient, .development)
}
