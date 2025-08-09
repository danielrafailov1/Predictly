#Preview {
    LoginSignupView()
        .environment(\.supabaseClient, .development)
}//
//  ContentView.swift
//  BroWager2
//
//  Created by Daniel Rafailov on 2025-05-13.
//

import SwiftUI
import AVFoundation
import AuthenticationServices
import Supabase

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
    
    var body: some View {
        NavigationStack(path: $navPath) {
            LoginContentView(
                email: $email,
                password: $password,
                isSignUpMode: $isSignUpMode,
                isPasswordStrong: isPasswordStrong,
                errorMessage: errorMessage,
                isGoogleLoading: $isGoogleLoading,
                appleSignInError: appleSignInError,
                isLoading: isLoading,
                onLoginSignup: { isSignUp in
                    Task {
                        if isSignUp {
                            await signup()
                        } else {
                            await login()
                        }
                    }
                },
                onGoogleSignIn: handleGoogleSignIn,
                onAppleSignIn: handleAppleSignIn
            )
            .onReceive(NotificationCenter.default.publisher(for: .receivedURL)) { notification in
                handleOAuthCallback(notification)
            }
            .navigationDestination(for: String.self) { email in
                LoggedInView(navPath: $navPath, email: email)
            }
            .navigationDestination(for: BetFlowPath.self) { path in
                BetFlowDestination(path: path, navPath: $navPath)
            }
            .background(
                NavigationLink(
                    destination: UsernameSelectionDestination(
                        newUserId: newUserId,
                        newUserEmail: newUserEmail,
                        newUserPassword: newUserPassword,
                        onComplete: handleUsernameComplete
                    ),
                    isActive: $isChooseUsernameActive,
                    label: { EmptyView() }
                )
            )
        }
        .onChange(of: resolvedEmail) { email in
            if let email = email {
                navPath = NavigationPath()
                navPath.append(email)
            }
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeSheet(resolvedEmail: resolvedEmail, navPath: $navPath)
        }
        .alert(isPresented: $showWelcome) {
            Alert(
                title: Text("Welcome to BroWager!"),
                message: Text("Your account has been created. Good luck!"),
                dismissButton: .default(Text("OK")) {
                    self.showWelcome = false
                }
            )
        }
        .sheet(isPresented: $isChooseUsernameActive) {
            UsernameSelectionSheet(
                newUserId: newUserId,
                newUserEmail: newUserEmail,
                onComplete: { email, _ in
                    Task {
                        await sessionManager.refreshSession()
                        isChooseUsernameActive = false
                    }
                }
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func handleUsernameComplete(email: String, password: String) {
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
    }
    
    // MARK: - Authentication Functions
    
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
                print("🔵 Looking up username: \(email)")
                
                // First, check if username exists
                struct UsernameRow: Decodable { let user_id: String }
                let usernameResp = try await supabaseClient
                    .from("Username")
                    .select("user_id")
                    .eq("username", value: email)
                    .limit(1)
                    .execute()
                
                // Decode as array since Supabase returns arrays
                let usernameRows = try JSONDecoder().decode([UsernameRow].self, from: usernameResp.data)
                
                // Check if we found any results
                guard let usernameRow = usernameRows.first else {
                    print("❌ No username found for: \(email)")
                    await MainActor.run {
                        self.errorMessage = "Username not found. Please check your username or use your email."
                        self.showError = true
                    }
                    return
                }
                
                let userId = usernameRow.user_id
                print("✅ Found user_id for username: \(userId)")
                
                // Now get the email for this user_id
                struct EmailRow: Decodable { let email: String }
                let emailResp = try await supabaseClient
                    .from("Login Information")
                    .select("email")
                    .eq("user_id", value: userId)
                    .limit(1)
                    .execute()
                
                let emailRows = try JSONDecoder().decode([EmailRow].self, from: emailResp.data)
                
                guard let emailRow = emailRows.first else {
                    print("❌ No email found for user_id: \(userId)")
                    await MainActor.run {
                        self.errorMessage = "Account information not found. Please contact support."
                        self.showError = true
                    }
                    return
                }
                
                loginEmail = emailRow.email
                print("✅ Found email for username: \(loginEmail)")
                
            } catch {
                print("❌ Error during username lookup: \(error)")
                await MainActor.run {
                    self.errorMessage = "Username lookup failed. Please try again or use your email."
                    self.showError = true
                }
                return
            }
        }
        
        // Now attempt to sign in with the resolved email
        do {
            print("🔵 Attempting login with email: \(loginEmail)")
            let session = try await supabaseClient.auth.signIn(email: loginEmail, password: password)
            let user = session.user
            print("✅ Logged in with user ID: \(user.id)")
            
            await MainActor.run {
                self.resolvedEmail = loginEmail
                self.showError = false
                self.errorMessage = nil
            }
            
            await sessionManager.refreshSession()
            self.showWelcome = true
            
        } catch {
            let errorText = error.localizedDescription
            print("❌ Login failed: \(errorText)")
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
    
    private func handleGoogleSignIn() {
        Task {
            print("🔵 Google Sign-In button tapped")
            isGoogleLoading = true
            
            do {
                print("🔵 Attempting Google OAuth with Supabase...")
                
                // Initiate Google OAuth
                try await supabaseClient.auth.signInWithOAuth(
                    provider: .google,
                    redirectTo: URL(string: "browager://login-callback")
                )
                
                print("✅ Google OAuth initiated successfully")
                print("🔵 Waiting for authentication to complete...")
                
                // Wait a bit for the OAuth flow to complete
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                
                // Manually check if we now have a session
                print("🔵 Checking for active session...")
                
                do {
                    let session = try await supabaseClient.auth.session
                    let user = session.user
                    
                    print("✅ Found active session after OAuth!")
                    print("✅ User: \(user.email ?? "nil")")
                    print("✅ User ID: \(user.id)")
                    
                    // Ensure Login Information exists
                    await ensureLoginInformationExists(for: user)
                    
                    // Check if user needs username
                    let needsUsername = await checkIfUserNeedsUsername(userId: user.id.uuidString)
                    
                    await MainActor.run {
                        if needsUsername {
                            print("🔵 User needs username, showing username selection...")
                            self.newUserId = user.id.uuidString
                            self.newUserEmail = user.email ?? ""
                            self.isChooseUsernameActive = true
                        } else {
                            print("🔵 User has username, navigating to LoggedInView...")
                            // Manually refresh session and navigate
                            Task {
                                await sessionManager.refreshSession()
                                await MainActor.run {
                                    self.resolvedEmail = user.email
                                }
                            }
                        }
                        
                        // Clear any error states
                        self.showError = false
                        self.errorMessage = nil
                    }
                    
                } catch {
                    print("❌ No active session found after OAuth: \(error)")
                    
                    // Try one more time after a longer delay
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 more seconds
                    
                    do {
                        let session = try await supabaseClient.auth.session
                        let user = session.user
                        
                        print("✅ Found session on second attempt!")
                        
                        await MainActor.run {
                            Task {
                                await sessionManager.refreshSession()
                                self.resolvedEmail = user.email
                            }
                        }
                        
                    } catch {
                        print("❌ Still no session after second attempt: \(error)")
                        await MainActor.run {
                            errorMessage = "Google sign-in completed but session not found. Please try again."
                            showError = true
                        }
                    }
                }
                
            } catch {
                print("❌ Google OAuth initiation failed: \(error)")
                
                let errorString = error.localizedDescription.lowercased()
                
                if errorString.contains("cancel") || errorString.contains("canceled") || errorString.contains("cancelled") {
                    print("🟡 User canceled Google Sign-In")
                    showError = false
                    errorMessage = nil
                } else {
                    print("❌ Setting error message: \(error.localizedDescription)")
                    errorMessage = "Google sign-in failed: \(error.localizedDescription)"
                    showError = true
                }
            }
            
            isGoogleLoading = false
            print("🔵 Google Sign-In button action completed")
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
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
    
    private func handleOAuthCallback(_ notification: Notification) {
        print("\n🟢 =================================")
        print("🟢 handleOAuthCallback triggered!")
        print("🟢 =================================")
        
        guard let url = notification.object as? URL else {
            print("❌ handleOAuthCallback: No URL in notification")
            print("❌ Notification object: \(notification.object ?? "nil")")
            return
        }
        
        print("✅ handleOAuthCallback: Received URL: \(url)")
        print("✅ URL scheme: \(url.scheme ?? "nil")")
        print("✅ URL host: \(url.host ?? "nil")")
        print("✅ URL path: \(url.path)")
        print("✅ URL query: \(url.query ?? "nil")")
        print("✅ URL absoluteString: \(url.absoluteString)")
        
        // Check if this looks like a Google OAuth callback
        if url.scheme == "browager" && url.host == "login-callback" {
            print("✅ This appears to be a Google OAuth callback URL")
        } else {
            print("🟡 URL doesn't match expected Google OAuth callback pattern")
        }
        
        Task {
            do {
                print("🔵 Attempting to create session from URL...")
                let session = try await supabaseClient.auth.session(from: url)
                let user = session.user
                print("✅ OAuth session created successfully!")
                print("✅ User ID: \(user.id)")
                print("✅ User email: \(user.email ?? "nil")")
                
                // Your existing code for handling login info and username...
                struct LoginInfoRow: Decodable { let user_id: String }
                
                let loginInfoResp = try await supabaseClient
                    .from("Login Information")
                    .select("user_id")
                    .eq("user_id", value: user.id.uuidString)
                    .limit(1)
                    .execute()
                
                let loginInfoRows = try JSONDecoder().decode([LoginInfoRow].self, from: loginInfoResp.data)
                
                if loginInfoRows.isEmpty {
                    print("🔵 Creating new Login Information row...")
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
                    
                    print("✅ Login Information row created")
                } else {
                    print("✅ Login Information row already exists for user_id: \(user.id.uuidString)")
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
                    print("🔵 No username found, showing username selection...")
                    await MainActor.run {
                        self.newUserId = user.id.uuidString
                        self.newUserEmail = user.email ?? ""
                        self.isChooseUsernameActive = true
                    }
                } else {
                    print("✅ Username exists, refreshing session...")
                    await sessionManager.refreshSession()
                }
                
            } catch {
                print("❌ OAuth session creation failed!")
                print("❌ Error: \(error)")
                print("❌ Error type: \(type(of: error))")
                print("❌ Error localized description: \(error.localizedDescription)")
            }
        }
        
        print("🟢 handleOAuthCallback completed\n")
    }
    
    private func ensureLoginInformationExists(for user: Auth.User) async {
        do {
            print("🔵 Checking Login Information for user...")
            
            let userUuid = user.id.uuidString
            print("🔵 User UUID: \(userUuid)")
            
            let loginInfoResp = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("user_id", value: userUuid)
                .limit(1)
                .execute()
            
            struct LoginInfoRow: Decodable { let user_id: String }
            let loginInfoRows = try JSONDecoder().decode([LoginInfoRow].self, from: loginInfoResp.data)
            
            if loginInfoRows.isEmpty {
                print("🔵 Creating Login Information row...")
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let newLoginInfo = LoginInfo(
                    created_at: timestamp,
                    email: user.email ?? "",
                    user_id: userUuid,
                    music_on: false,
                    wins: 0
                )
                
                _ = try await supabaseClient
                    .from("Login Information")
                    .insert(newLoginInfo)
                    .execute()
                
                print("✅ Login Information created")
            } else {
                print("✅ Login Information already exists")
            }
            
        } catch {
            print("❌ Error with Login Information: \(error)")
        }
    }

    private func checkIfUserNeedsUsername(userId: String) async -> Bool {
        do {
            print("🔵 Checking if user needs username...")
            
            let usernameResp = try await supabaseClient
                .from("Username")
                .select("username")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            
            struct UsernameRow: Decodable { let username: String }
            let usernameRows = try JSONDecoder().decode([UsernameRow].self, from: usernameResp.data)
            
            let needsUsername = usernameRows.isEmpty
            print(needsUsername ? "🔵 User needs username" : "✅ User has username")
            
            return needsUsername
            
        } catch {
            print("❌ Error checking username: \(error)")
            return false // Assume they don't need username if we can't check
        }
    }
}

// MARK: - Supporting Views

struct LoginContentView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isSignUpMode: Bool
    let isPasswordStrong: Bool
    let errorMessage: String?
    @Binding var isGoogleLoading: Bool
    let appleSignInError: String?
    let isLoading: Bool
    let onLoginSignup: (Bool) -> Void
    let onGoogleSignIn: () -> Void
    let onAppleSignIn: (Result<ASAuthorization, Error>) -> Void
    
    var body: some View {
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
                    HeaderView(isSignUpMode: isSignUpMode)
                    
                    InputFieldsView(
                        email: $email,
                        password: $password,
                        isPasswordStrong: isPasswordStrong,
                        isSignUpMode: isSignUpMode
                    )
                    
                    ActionButtonView(
                        email: email,
                        password: password,
                        isSignUpMode: isSignUpMode,
                        isLoading: isLoading,
                        isPasswordStrong: isPasswordStrong,
                        onAction: onLoginSignup
                    )
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                            .padding(.horizontal, 24)
                    }
                    
                    SocialLoginView(
                        isGoogleLoading: $isGoogleLoading,
                        appleSignInError: appleSignInError,
                        onGoogleSignIn: onGoogleSignIn,
                        onAppleSignIn: onAppleSignIn
                    )
                    
                    ToggleModeButton(
                        isSignUpMode: $isSignUpMode
                    )
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}

struct HeaderView: View {
    let isSignUpMode: Bool
    
    var body: some View {
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
    }
}

struct InputFieldsView: View {
    @Binding var email: String
    @Binding var password: String
    let isPasswordStrong: Bool
    let isSignUpMode: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Email/Username Field with conditional labeling
            VStack(alignment: .leading, spacing: 8) {
                Text(isSignUpMode ? "Email" : "Email or Username")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                TextField(isSignUpMode ? "Enter your email" : "Enter email or username", text: $email)
                    .keyboardType(isSignUpMode ? .emailAddress : .default)
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
                
                SecureField("Enter your password", text: $password)
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
            
            // Password strength indicator (only show in signup mode)
            if isSignUpMode && !password.isEmpty && !isPasswordStrong {
                Text("Password must be at least 8 characters, include uppercase, lowercase, a digit, and a special character.")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                    .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, 32)
    }
}

struct ActionButtonView: View {
    let email: String
    let password: String
    let isSignUpMode: Bool
    let isLoading: Bool
    let isPasswordStrong: Bool
    let onAction: (Bool) -> Void
    
    // Email validation helper
    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // Check if form is valid based on mode
    private var isFormValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidInput = !trimmedEmail.isEmpty && !password.isEmpty
        
        if isSignUpMode {
            // Signup requires valid email and strong password
            return hasValidInput && isValidEmail && isPasswordStrong
        } else {
            // Login just needs non-empty email/username and password
            return hasValidInput
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                onAction(isSignUpMode)
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
            .disabled(!isFormValid || isLoading)
            
            // Show email validation error in signup mode
            if isSignUpMode && !email.isEmpty && !isValidEmail {
                Text("Please enter a valid email address")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                    .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, 32)
    }
}

struct SocialLoginView: View {
    @Binding var isGoogleLoading: Bool
    let appleSignInError: String?
    let onGoogleSignIn: () -> Void
    let onAppleSignIn: (Result<ASAuthorization, Error>) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            
            GoogleSignInButton(
                isLoading: $isGoogleLoading,
                onSignIn: onGoogleSignIn
            )
            
            AppleSignInButtonView(
                appleSignInError: appleSignInError,
                onSignIn: onAppleSignIn
            )
        }
        .padding(.horizontal, 32)
    }
}

struct GoogleSignInButton: View {
    @Binding var isLoading: Bool
    let onSignIn: () -> Void
    
    var body: some View {
        Button(action: onSignIn) {
            HStack {
                Image("GoogleLogo")
                    .resizable()
                    .frame(width: 24, height: 24)
                Spacer().frame(width: 12)
                Text(isLoading ? "Signing in..." : "Sign in with Google")
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
        .disabled(isLoading)
    }
}

struct AppleSignInButtonView: View {
    let appleSignInError: String?
    let onSignIn: (Result<ASAuthorization, Error>) -> Void
    
    var body: some View {
        VStack {
            SignInWithAppleButton { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                onSignIn(result)
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
    }
}

struct ToggleModeButton: View {
    @Binding var isSignUpMode: Bool
    
    var body: some View {
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
}

// MARK: - Navigation Helper Views

struct BetFlowDestination: View {
    let path: BetFlowPath
    @Binding var navPath: NavigationPath
    
    var body: some View {
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
}

struct UsernameSelectionDestination: View {
    let newUserId: String?
    let newUserEmail: String?
    let newUserPassword: String?
    let onComplete: (String, String) -> Void
    
    var body: some View {
        if let userId = newUserId,
           let email = newUserEmail,
           let password = newUserPassword {
            ChooseUsernameView(
                userId: userId,
                email: email,
                password: password,
                onComplete: onComplete
            )
        } else {
            EmptyView()
        }
    }
}

struct UsernameSelectionSheet: View {
    let newUserId: String?
    let newUserEmail: String?
    let onComplete: (String, String) -> Void
    
    var body: some View {
        if let userId = newUserId, let email = newUserEmail {
            ChooseUsernameView(
                userId: userId,
                email: email,
                password: "", // Apple sign-in, so password is blank
                onComplete: onComplete
            )
        } else {
            EmptyView()
        }
    }
}

struct WelcomeSheet: View {
    let resolvedEmail: String?
    @Binding var navPath: NavigationPath
    
    var body: some View {
        if let email = resolvedEmail {
            ProfileView(navPath: $navPath, email: email)
        } else {
            EmptyView()
        }
    }
}
