import Foundation
import SwiftUI
import PhotosUI
import Auth
import Supabase

struct ProfileView: View {
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var profileImage: Image? = nil
    @State private var profileUIImage: UIImage? = nil
    @Binding var navPath: NavigationPath
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    @State private var userId: String? = nil
    @State private var username: String = ""
    @State private var identifier: String = ""
    @State private var isEditingUsername = false
    @State private var newUsername: String = ""
    @State private var isEditingEmail = false
    @State private var showChangePassword = false
    @State private var currentEmail: String
    @State private var updateMessage: String?
    @State private var isErrorUpdate: Bool = false
    @State private var showingCredits = false
    @State private var isEditingPassword = false
    @State private var newPassword = ""
    @State private var authProvider: String? = nil
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String? = nil
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var profileCache = ProfileCache.shared
    @State private var isLoadingFromCache = false
    
    // Friends functionality states
    @State private var friends: [FriendUser] = []
    @State private var pendingRequests: [FriendRequest] = []
    @State private var isFriendsLoading = true
    @State private var showAddFriend = false
    @State private var showRequests = false
    @State private var inviteTarget: FriendUser? = nil
    @State private var showPartyPicker = false
    @State private var userParties: [Party1] = []
    @State private var isLoadingParties = false
    @State private var inviteStatus: String? = nil
    @State private var activeChatFriend: FriendUser? = nil

    init(navPath: Binding<NavigationPath>, email: String) {
        _navPath = navPath
        _currentEmail = State(initialValue: email)
    }

    var body: some View {
        ZStack {
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
                if isLoadingFromCache {
                    VStack {
                        ProgressView("Loading...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .foregroundColor(.white)
                            .padding(.top, 100)
                        Spacer()
                    }
                }
                else {
                    VStack(spacing: 32) {
                        profileHeader
                        accountInfoSection
                        
                        // Enhanced Friends Section with full functionality
                        friendsSectionWithFullFunctionality
                        
                        if let message = updateMessage {
                            Text(message)
                                .foregroundColor(isErrorUpdate ? .red : .green)
                                .padding()
                        }
                        
                        Button(action: {
                            showingCredits = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                                
                                Text("Credits")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        .sheet(isPresented: $showingCredits) {
                            CreditsView()
                        }
                        
                        logoutButton
                        
                        deleteAccountButton
                    }
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else {
                        return
                    }
                    
                    profileUIImage = uiImage
                    profileImage = Image(uiImage: uiImage)
                    
                    // Upload to Supabase
                    isUploading = true
                    uploadError = nil
                    do {
                        // Get user_id if not already fetched
                        if userId == nil {
                            userId = try await fetchUserId()
                        }
                        guard let userId = userId else {
                            uploadError = "Could not fetch user ID."
                            isUploading = false
                            return
                        }
                        let manager = ProfileManager(supabaseClient: supabaseClient)
                        let _ = try await manager.uploadProfileImageAndSaveURL(for: userId, image: uiImage)
                        
                        // Update cache with new image
                        let cacheKey = "\(userId)_\(currentEmail)"
                        profileCache.updateProfileImage(uiImage, swiftUIImage: Image(uiImage: uiImage), for: cacheKey)
                        
                        isUploading = false
                    } catch {
                        uploadError = "Upload failed: \(error.localizedDescription)"
                        isUploading = false
                    }
                }
            }
            .task {
                await fetchUserProfile()
            }
            .refreshable {
                // Clear cache and reload
                if let userId = userId {
                    let cacheKey = "\(userId)_\(currentEmail)"
                    profileCache.clearCache(for: cacheKey)
                }
                await fetchUserProfile()
            }
            .alert("Delete Account", isPresented: $showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone and will permanently remove all your data, including parties, bets, friends, and profile information.")
            }
            .alert("Account Deletion Error", isPresented: .constant(deleteAccountError != nil)) {
                Button("OK") {
                    deleteAccountError = nil
                }
            } message: {
                if let error = deleteAccountError {
                    Text(error)
                }
            }
            // Friends sheets
            .sheet(isPresented: $showAddFriend, onDismiss: { Task { await loadFriends() } }) {
                AddFriendView(email: currentEmail)
                    .environment(\.supabaseClient, supabaseClient)
            }
            .sheet(isPresented: $showRequests, onDismiss: { Task { await loadFriends() } }) {
                FriendRequestsView(email: currentEmail)
                    .environment(\.supabaseClient, supabaseClient)
            }
            .sheet(isPresented: $showPartyPicker) {
                VStack(spacing: 20) {
                    Text("Invite \(inviteTarget != nil ? "\(inviteTarget!.username)#\(inviteTarget!.identifier)" : "Friend") to a Party")
                        .font(.title2)
                        .padding(.top, 24)
                    if isLoadingParties {
                        ProgressView()
                    } else if userParties.isEmpty {
                        Text("You have no active parties to invite to.")
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(userParties, id: \.id) { party in
                                    Button(action: {
                                        Task { await inviteFriendToParty(friend: inviteTarget!, party: party) }
                                    }) {
                                        HStack {
                                            Text(party.party_name ?? "Unnamed Party")
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "arrowshape.turn.up.right.fill")
                                                .foregroundColor(.blue)
                                        }
                                        .padding()
                                        .background(Color.blue.opacity(0.08))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    if let status = inviteStatus {
                        Text(status)
                            .foregroundColor(.green)
                            .padding(.top, 8)
                    }
                    Spacer()
                    Button("Cancel") { showPartyPicker = false }
                        .padding(.bottom, 24)
                }
                .onDisappear { inviteStatus = nil }
                .padding()
                .background(Color(.systemBackground))
            }
            .sheet(item: $activeChatFriend) { friend in
                DirectMessageView(friend: friend, currentUserId: userId ?? "")
            }
        }
        .navigationBarHidden(true)
        .toolbarBackground(.hidden, for: .tabBar)
    }

    // MARK: - Friends Section View
    
    private var friendsSectionWithFullFunctionality: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Friends")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                
                // Friend actions buttons
                HStack(spacing: 12) {
                    Button(action: { showRequests = true }) {
                        Image(systemName: "envelope")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.green.opacity(0.8))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { showAddFriend = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 24)
            
            // Friends List
            if isFriendsLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading friends...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
            } else if friends.isEmpty {
                VStack(spacing: 12) {
                    Text("No friends yet.")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 16))
                    
                    Button(action: { showAddFriend = true }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Add Your First Friend")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(friends, id: \.user_id) { friend in
                        HStack(spacing: 12) {
                            AsyncProfileImage(userId: friend.user_id, supabaseClient: supabaseClient)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(friend.username)#\(friend.identifier)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Button(action: {
                                    inviteTarget = friend
                                    Task { await loadUserParties() }
                                    showPartyPicker = true
                                }) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 18))
                                        .padding(6)
                                        .background(Color.blue.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    activeChatFriend = friend
                                }) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 18))
                                        .padding(6)
                                        .background(Color.green.opacity(0.15))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Friends Functionality Methods
    
    private func loadFriends() async {
        let currentUserId: String
        if let existingUserId = userId {
            currentUserId = existingUserId
        } else {
            // Try to get userId first
            if let fetchedUserId = try? await fetchUserId() {
                await MainActor.run { self.userId = fetchedUserId }
                currentUserId = fetchedUserId
            } else {
                print("[ProfileView] Cannot load friends: User ID not found")
                await MainActor.run { self.isFriendsLoading = false }
                return
            }
        }
        
        await MainActor.run { self.isFriendsLoading = true }
        
        do {
            // Get accepted friends using the RPC function
            let friendsResp = try await supabaseClient
                .rpc("get_friends", params: ["uid": currentUserId])
                .execute()
            let friendsArr = try JSONDecoder().decode([FriendUser].self, from: friendsResp.data)
            print("[ProfileView] Friends fetched: \(friendsArr)")
            
            await MainActor.run {
                self.friends = friendsArr
                self.isFriendsLoading = false
            }
        } catch {
            print("[ProfileView] Error loading friends: \(error)")
            await MainActor.run { self.isFriendsLoading = false }
        }
    }
    
    private func loadUserParties() async {
        guard let currentUserId = userId else { return }
        
        isLoadingParties = true
        do {
            // Fetch parties where user is a member and not expired/deleted
            let partiesResp = try await supabaseClient
                .rpc("get_user_parties", params: ["uid": currentUserId])
                .execute()
            let allParties = try JSONDecoder().decode([Party1].self, from: partiesResp.data)
            // Filter to only active/joinable parties
            userParties = allParties.filter { ($0.status ?? "active") != "expired" && ($0.status ?? "active") != "deleted" }
        } catch {
            print("[ProfileView] Error loading user parties: \(error)")
            userParties = []
        }
        isLoadingParties = false
    }
    
    private func inviteFriendToParty(friend: FriendUser, party: Party1) async {
        guard let partyId = party.id, let currentUserId = userId else {
            await MainActor.run {
                inviteStatus = "Failed to send invite: invalid party ID or user ID."
            }
            return
        }
        
        do {
            let invite = PartyInvite1(
                party_id: partyId,
                inviter_user_id: currentUserId,
                invitee_user_id: friend.user_id,
                status: "pending"
            )
            _ = try await supabaseClient
                .from("Party Invites")
                .insert(invite)
                .execute()
            await MainActor.run {
                inviteStatus = "Invite sent to \(friend.username)!"
            }
        } catch {
            print("[ProfileView] Error inviting friend: \(error)")
            await MainActor.run {
                inviteStatus = "Failed to send invite."
            }
        }
    }

    // MARK: - Original ProfileView Subviews and Methods
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Image
            ZStack {
                if let image = profileImage {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.8),
                                            Color.white.opacity(0.4)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Change Photo Button
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .offset(x: 40, y: 40)
            }
            
            Text("Change Profile Picture")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            if isUploading {
                ProgressView("Uploading...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            if let uploadError = uploadError {
                Text(uploadError)
                    .foregroundColor(.red)
            }
        }
        .padding(.top, 32)
    }
    
    private var accountInfoSection: some View {
        VStack(spacing: 24) {
            // Section Header
            HStack {
                Text("Account Info")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 24)
            
            // Username Field
            EditableInfoRow(
                title: "Username",
                value: $username,
                isEditing: $isEditingUsername,
                onSave: { updatedUsername in
                    Task { await updateUsername(newUsername: updatedUsername) }
                },
                identifier: identifier
            )
            
            // Email Field
            EditableInfoRow(
                title: "Email",
                value: $currentEmail,
                isEditing: $isEditingEmail,
                onSave: { updatedEmail in
                    Task { await updateUserEmail(newEmail: updatedEmail) }
                }
            )
            
            // Conditionally show Password Field (only for email/password auth)
            if shouldShowPasswordField {
                EditablePasswordRow(
                    isEditing: $isEditingPassword,
                    password: $newPassword,
                    onSave: { updatedPassword in
                        Task { await updatePassword(newPassword: updatedPassword) }
                    }
                )
            }
        }
    }
    
    // Computed property to determine if password field should be shown
    private var shouldShowPasswordField: Bool {
        guard let provider = authProvider else { return true } // Show by default if unknown
        return provider == "email" // Only show for email/password authentication
    }
    
    private var logoutButton: some View {
        Button(action: {
            Task {
                await sessionManager.signOut()
                navPath = NavigationPath()
            }
        }) {
            HStack {
                Image(systemName: "arrow.right.square.fill")
                    .font(.system(size: 20))
                Text("Logout")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.red,
                        Color.red.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    private var deleteAccountButton: some View {
        Button(action: {
            showDeleteAccountConfirmation = true
        }) {
            HStack {
                if isDeletingAccount {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 20))
                }
                Text(isDeletingAccount ? "Deleting..." : "Delete Account")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.red.opacity(0.8),
                        Color.red.opacity(0.6)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .disabled(isDeletingAccount)
    }

    // MARK: - Original ProfileView Functions
    
    private func fetchUserProfile() async {
        do {
            var fetchedUserId: String? = nil
            // Prefer user_id from sessionManager if available
            if let sessionUserId = sessionManager.newUserId {
                fetchedUserId = sessionUserId
                print("[ProfileView] Using userId from sessionManager: \(sessionUserId)")
            } else {
                // Fallback: fetch user_id from Login Information by email
                let response = try await supabaseClient
                    .from("Login Information")
                    .select("user_id")
                    .eq("email", value: currentEmail)
                    .limit(1)
                    .execute()
                struct UserIdRow: Decodable { let user_id: String }
                let userRows = try JSONDecoder().decode([UserIdRow].self, from: response.data)
                guard let userRow = userRows.first else {
                    throw URLError(.cannotDecodeContentData)
                }
                fetchedUserId = userRow.user_id
                print("[ProfileView] Fallback loaded userId: \(fetchedUserId ?? "nil")")
            }
            guard let userId = fetchedUserId else { throw URLError(.userAuthenticationRequired) }
            
            // Set userId immediately
            await MainActor.run {
                self.userId = userId
                self.isLoadingFromCache = true
            }
            
            // Check cache first
            let cacheKey = "\(userId)_\(currentEmail)"
            if let cachedProfile = profileCache.getCachedProfile(for: cacheKey) {
                print("[ProfileView] Loading from cache for userId: \(userId)")
                await MainActor.run {
                    self.username = cachedProfile.username
                    self.identifier = cachedProfile.identifier
                    self.currentEmail = cachedProfile.email
                    self.authProvider = cachedProfile.authProvider
                    if let uiImage = cachedProfile.profileImage, let swiftUIImage = cachedProfile.profileImageSwiftUI {
                        self.profileUIImage = uiImage
                        self.profileImage = swiftUIImage
                    }
                    self.isErrorUpdate = false
                    self.updateMessage = nil
                    self.isLoadingFromCache = false
                }
                // Load friends after setting user info
                await loadFriends()
                return
            }
            
            print("[ProfileView] No valid cache found, fetching from server for userId: \(userId)")
            
            // Fetch authentication provider
            await fetchAuthProvider()

            // Fetch email from Login Information
            let emailResponse = try await supabaseClient
                .from("Login Information")
                .select("email")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            struct EmailRow: Decodable { let email: String }
            let emailRows = try JSONDecoder().decode([EmailRow].self, from: emailResponse.data)
            let fetchedEmail = emailRows.first?.email ?? ""

            // Fetch username and profile image in parallel
            async let usernameTask = fetchUsernameAndIdentifier(for: userId)
            async let profileImageTask = fetchAndLoadProfileImage(for: userId)

            let (fetchedUsername, fetchedIdentifier) = await (try? usernameTask) ?? ("", "")
            let loadedImage = await (try? profileImageTask)
            let fetchedAuthProvider = await MainActor.run { self.authProvider ?? "email" }

            // Cache the data (without friends for now)
            let cachedProfile = CachedProfile(
                userId: userId,
                username: fetchedUsername,
                identifier: fetchedIdentifier,
                email: fetchedEmail,
                profileImage: loadedImage?.0,
                profileImageSwiftUI: loadedImage?.1,
                authProvider: fetchedAuthProvider,
                friendsWithImages: [], // We'll load friends separately
                timestamp: Date()
            )
            profileCache.setCachedProfile(cachedProfile, for: cacheKey)

            await MainActor.run {
                self.username = fetchedUsername
                self.identifier = fetchedIdentifier
                self.currentEmail = fetchedEmail
                if let (uiImage, image) = loadedImage {
                    self.profileUIImage = uiImage
                    self.profileImage = image
                }
                self.isErrorUpdate = false
                self.updateMessage = nil
                self.isLoadingFromCache = false
            }
            
            // Load friends after setting user info
            await loadFriends()
            
        } catch {
            print("❌ Error fetching user profile: \(error.localizedDescription)")
            await MainActor.run {
                self.isErrorUpdate = true
                self.updateMessage = "Error loading profile. Please try again."
                self.isLoadingFromCache = false
                self.isFriendsLoading = false
            }
        }
    }
    
    // New function to fetch the authentication provider
    private func fetchAuthProvider() async {
        do {
            // Get the current user from Supabase Auth
            let user = try await supabaseClient.auth.user()
            
            // Debug: Print all available metadata
            print("🔍 Debug - appMetadata: \(user.appMetadata)")
            print("🔍 Debug - userMetadata: \(user.userMetadata)")
            print("🔍 Debug - identities: \(user.identities)")
            
            // Try different ways to get the provider
            var provider: String = "email" // default
            
            // Method 1: Check app_metadata.provider
            if let appProvider = user.appMetadata["provider"] as? String {
                provider = appProvider
                print("📱 Found provider in appMetadata: \(appProvider)")
            }
            // Method 2: Check app_metadata.providers (some setups use array)
            else if let providers = user.appMetadata["providers"] as? [String], let firstProvider = providers.first {
                provider = firstProvider
                print("📱 Found provider in appMetadata.providers: \(firstProvider)")
            }
            // Method 3: Check identities for OAuth providers
            else if let identities = user.identities, !identities.isEmpty {
                for identity in identities {
                    provider = identity.provider
                    print("📱 Found provider in identities: \(identity.provider)")
                    break
                }
            }
            // Method 4: Check if email contains OAuth indicators
            else if user.email?.contains("@") == true {
                // This is a fallback - you might need to store provider info differently
                // For now, we'll assume email auth if we can't find OAuth indicators
                provider = "email"
                print("📧 Defaulting to email provider")
            }
            
            await MainActor.run {
                self.authProvider = provider
                print("🔐 Final Auth provider: \(provider)")
            }
            
        } catch {
            print("❌ Error fetching auth provider: \(error.localizedDescription)")
            // Default to email if we can't determine the provider
            await MainActor.run {
                self.authProvider = "email"
            }
        }
    }

    private func updateUsername(newUsername: String) async {
        guard let userId = userId, !newUsername.isEmpty else { return }
        do {
            try await supabaseClient
                .from("Username")
                .update(["username": newUsername])
                .eq("user_id", value: userId)
                .execute()
            
            // Update cache
            let cacheKey = "\(userId)_\(currentEmail)"
            profileCache.updateUsername(newUsername, for: cacheKey)
            
            await MainActor.run {
                self.username = newUsername
                self.isEditingUsername = false
            }
        } catch {
            print("❌ Error updating username: \(error.localizedDescription)")
        }
    }

    private func updateUserEmail(newEmail: String) async {
        guard !newEmail.isEmpty, newEmail != currentEmail, let userId = userId else { return }
        
        do {
            try await supabaseClient.auth.update(
                user: UserAttributes(email: newEmail)
            )
            
            // Also update the Login Information table
            try await supabaseClient
                .from("Login Information")
                .update(["email": newEmail])
                .eq("user_id", value: userId)
                .execute()

            // Update cache
            let oldCacheKey = "\(userId)_\(currentEmail)"
            let newCacheKey = "\(userId)_\(newEmail)"
            profileCache.updateEmail(newEmail, for: oldCacheKey)
            // Move cache to new key
            if let cached = profileCache.getCachedProfile(for: oldCacheKey) {
                profileCache.setCachedProfile(cached, for: newCacheKey)
                profileCache.clearCache(for: oldCacheKey)
            }

            await MainActor.run {
                self.currentEmail = newEmail
                self.isEditingEmail = false
                self.isErrorUpdate = false
                self.updateMessage = "Confirmation email sent to \(newEmail). Please verify to complete the change."
            }
        } catch {
            await MainActor.run {
                self.isErrorUpdate = true
                self.updateMessage = "Error updating email: \(error.localizedDescription)"
            }
        }
    }
    
    private func updatePassword(newPassword: String) async {
        guard !newPassword.isEmpty else {
            await MainActor.run {
                self.isErrorUpdate = true
                self.updateMessage = "Password cannot be empty."
            }
            return
        }

        do {
            try await supabaseClient.auth.update(user: UserAttributes(password: newPassword))
            await MainActor.run {
                self.isEditingPassword = false
                self.newPassword = ""
                self.isErrorUpdate = false
                self.updateMessage = "Password updated successfully!"
            }
        } catch {
            await MainActor.run {
                self.isErrorUpdate = true
                self.updateMessage = "Error updating password: \(error.localizedDescription)"
            }
        }
    }

    // Helper to fetch user_id from Login Information
    func fetchUserId() async throws -> String? {
        struct UserIdResponse: Decodable { let user_id: String }
        let response: UserIdResponse = try await supabaseClient
            .from("Login Information")
            .select("user_id")
            .eq("email", value: currentEmail)
            .limit(1)
            .execute()
            .value
        return response.user_id
    }

    func fetchUsernameAndIdentifier(for userId: String) async throws -> (String, String) {
        do {
            let response: [UsernameRow] = try await supabaseClient
                .from("Username")
                .select("username, identifier")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            let uname = response.first?.username ?? ""
            let ident = response.first?.identifier ?? ""
            return (uname, ident)
        } catch {
            return ("", "")
        }
    }
    
    func fetchAndLoadProfileImage(for userId: String) async throws -> (UIImage, Image)? {
        let manager = ProfileManager(supabaseClient: supabaseClient)
        guard let urlString = try await manager.fetchProfileImageURL(for: userId),
              let url = URL(string: urlString + "?t=\(Int(Date().timeIntervalSince1970))") else {
            return nil
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        if let uiImage = UIImage(data: data) {
            return (uiImage, Image(uiImage: uiImage))
        }
        return nil
    }
    
    // MARK: - Account Deletion
    
    private func deleteAccount() async {
        guard let userId = userId else {
            await MainActor.run {
                deleteAccountError = "User ID not found"
            }
            return
        }
        
        await MainActor.run {
            isDeletingAccount = true
            deleteAccountError = nil
        }
        
        do {
            // Create deletion service and delete account directly
            let deletionService = AccountDeletionService(supabaseClient: supabaseClient)
            let result = await deletionService.deleteAccount(userId: userId)
            
            await MainActor.run {
                isDeletingAccount = false
                
                if result.success {
                    // Account deleted successfully, sign out and redirect to login
                    print("✅ Account deleted successfully")
                    Task {
                        await sessionManager.signOut()
                        navPath = NavigationPath()
                    }
                } else {
                    deleteAccountError = result.errorMessage ?? "Unknown error occurred"
                }
            }
        } catch {
            await MainActor.run {
                isDeletingAccount = false
                deleteAccountError = "Failed to delete account: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Required Models and Structs

struct FriendUser: Decodable, Identifiable {
    let user_id: String
    let username: String
    let identifier: String
    var id: String { user_id }
}

struct FriendRequest: Decodable {
    let id: Int64
    let user_id: String
    let friend_id: String
    let status: String
    let created_at: String
}

// FriendWithImage Model (for the simplified friends display)
struct FriendWithImage: Identifiable {
    let id: String
    let username: String
    let profileImageURL: URL?
}

// Party models needed for party invitations
struct Party1: Decodable, Identifiable {
    let id: Int64?
    let party_name: String?
    let status: String?
}

struct PartyInvite1: Codable {
    let party_id: Int64
    let inviter_user_id: String
    let invitee_user_id: String
    let status: String
}

struct AsyncProfileImage: View {
    let userId: String
    let supabaseClient: SupabaseClient
    @State private var image: Image? = nil
    
    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFill()
                    .foregroundColor(.blue)
            }
        }
        .onAppear {
            Task {
                image = await fetchProfileImage(forUserId: userId, supabaseClient: supabaseClient)
            }
        }
    }
}

// A reusable view for displaying static info
struct InfoRow: View {
    let icon: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 24)
            
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

// A reusable view for editable fields
struct EditableInfoRow: View {
    let title: String
    @Binding var value: String
    @Binding var isEditing: Bool
    let onSave: (String) -> Void
    var identifier: String? = nil
    
    @State private var draftValue: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)

            if isEditing {
                TextField(title, text: $draftValue)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    onSave(draftValue)
                    isEditing = false
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                Button(action: {
                    isEditing = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            } else {
                if title == "Email" {
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let identifier = identifier, !identifier.isEmpty {
                    Text("\(value)#\(identifier)")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(value)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
                Button(action: {
                    draftValue = value
                    isEditing = true
                }) {
                    Text("Edit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

// A reusable view for an editable password field
struct EditablePasswordRow: View {
    @Binding var isEditing: Bool
    @Binding var password: String
    let onSave: (String) -> Void
    
    @State private var isPasswordVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Text("Password")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)

            if isEditing {
                if isPasswordVisible {
                    TextField("New Password", text: $password)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineLimit(1)
                } else {
                    SecureField("New Password", text: $password)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                Button(action: { isPasswordVisible.toggle() }) {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()

                Button(action: {
                    onSave(password)
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }
                
                Button(action: {
                    isEditing = false
                    password = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                }
            } else {
                Text("••••••••••")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    password = ""
                    isEditing = true
                }) {
                    Text("Edit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

struct UsernameRow: Codable {
    let username: String?
    let identifier: String?
}
