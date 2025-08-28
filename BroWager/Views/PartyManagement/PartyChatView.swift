import SwiftUI
import Supabase
import PhotosUI
import AVFoundation

struct PartyChatInsert: Codable {
    let party_id: Int64
    let user_id: String
    let username: String
    let message: String // Changed from String? to String since the DB column is NOT NULL
    let media_url: String?
    let media_type: String?
    let created_at: String
}

struct PartyChatView: View {
    let partyId: Int64
    let partyName: String
    @Environment(\.supabaseClient) private var supabaseClient
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var newMessage: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var timer: Timer? = nil
    @State private var selectedItem: PhotosPickerItem? = nil
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var uploadStates: [String: UploadState] = [:] // Track individual upload states
    @State private var pendingMessages: [ChatMessage] = []
    @State private var hasInitiallyScrolled = false
    @State private var lastKnownMessageCount = 0
    @State private var username: String = ""
    @State private var userId: String? = nil
    @State private var profileImages: [String: Image?] = [:]
    
    enum UploadState {
        case uploading
        case completed
        case failed(String)
    }
    
    struct ChatMessage: Identifiable, Codable, Equatable {
        let id: Int64?
        let party_id: Int64
        let user_id: String
        let username: String
        let message: String?
        let created_at: String?
        let media_type: String?
        let media_url: String?
    }
    
    var allMessages: [ChatMessage] {
        (messages + pendingMessages).sorted { ($0.created_at ?? "") < ($1.created_at ?? "") }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Party Chat: \(partyName)")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            Divider()
            
            // Messages area
            if isLoading {
                Spacer()
                ProgressView("Loading messages...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack {
                    Text(error)
                        .foregroundColor(.red)
                    Button("Retry") {
                        loadMessages()
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(allMessages) { message in
                                let isSelf = message.user_id == (userId ?? "")
                                let uploadState = uploadStates[message.idValue] ?? .completed
                                PartyChatBubbleView(
                                    message: message,
                                    isSelf: isSelf,
                                    uploadState: uploadState,
                                    profileImage: profileImages[message.user_id] ?? nil
                                )
                                .id(message.idValue)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: allMessages.count) { newCount in
                        if hasInitiallyScrolled {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToBottom(proxy: proxy)
                            hasInitiallyScrolled = true
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewMessageReceived"))) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            
            Divider()
            
            // Input area
            HStack {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .onChange(of: selectedItem) { newItem in
                    handleImageSelection(newItem)
                }

                Button(action: handleAudioButtonTap) {
                    Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic")
                        .font(.title2)
                        .foregroundColor(audioRecorder.isRecording ? .red : .primary)
                }
                .padding(.horizontal)

                TextField("Message...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 36)
                    .onSubmit {
                        sendTextMessage()
                    }
                
                Button(action: sendTextMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22))
                        .foregroundColor(canSendMessage ? .blue : .gray)
                }
                .disabled(!canSendMessage)
            }
            .padding()
            .background(Color(.sRGB, white: 0.10, opacity: 1.0))
        }
        .onAppear {
            Task {
                await initializeUserIdAndUsername()
                loadMessages()
                startPeriodicRefresh()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private var canSendMessage: Bool {
        !newMessage.trimmingCharacters(in: .whitespaces).isEmpty && !username.isEmpty
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = allMessages.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.idValue, anchor: .bottom)
            }
        }
    }
    
    // MARK: - Message Loading (Optimized)
    
    private func startPeriodicRefresh() {
        // Reduced frequency to 5 seconds instead of 1.5
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await loadMessagesInBackground()
            }
        }
    }
    
    private func loadMessages() {
        Task {
            await loadMessagesWithErrorHandling(showLoading: true)
        }
    }
    
    private func loadMessagesInBackground() async {
        await loadMessagesWithErrorHandling(showLoading: false)
    }
    
    private func loadMessagesWithErrorHandling(showLoading: Bool) async {
        do {
            let resp = try await supabaseClient
                .from("PartyChatMessages")
                .select()
                .eq("party_id", value: Int(partyId))
                .order("created_at", ascending: true)
                .execute()
            
            let decoder = JSONDecoder()
            let msgs = try decoder.decode([ChatMessage].self, from: resp.data)
            
            await MainActor.run {
                let previousCount = self.messages.count
                
                // Check for new messages from other users
                if !showLoading && msgs.count > self.lastKnownMessageCount {
                    let newMessages = Array(msgs.suffix(msgs.count - self.lastKnownMessageCount))
                    let newMessagesFromOthers = newMessages.filter { $0.user_id != (self.userId ?? "") }
                    
                    for message in newMessagesFromOthers {
                        let notificationBody: String
                        if let messageText = message.message {
                            if messageText.hasPrefix("https://") && (messageText.contains("/images/") || messageText.contains("/audio/")) {
                                if messageText.contains("/images/") {
                                    notificationBody = "📷 Sent a photo"
                                } else {
                                    notificationBody = "🎵 Sent an audio message"
                                }
                            } else {
                                notificationBody = messageText
                            }
                        } else {
                            notificationBody = "New message"
                        }
                        
                        NotificationManager.shared.scheduleLocalNotification(
                            title: "\(message.username) in \(partyName)",
                            body: notificationBody
                        )
                    }
                }
                
                self.messages = msgs
                self.lastKnownMessageCount = msgs.count
                
                // Clean up completed uploads and pending messages
                self.cleanupCompletedUploads(confirmedMessages: msgs)
                
                if hasInitiallyScrolled && msgs.count > previousCount {
                    let newMessages = Array(msgs.suffix(msgs.count - previousCount))
                    let hasNewMessagesFromOther = newMessages.contains { $0.user_id != (userId ?? "") }
                    
                    if hasNewMessagesFromOther {
                        NotificationCenter.default.post(name: NSNotification.Name("NewMessageReceived"), object: nil)
                    }
                }
                
                if showLoading {
                    self.isLoading = false
                }
                
                // Load profile images
                Task { await loadProfileImagesForMessages() }
            }
        } catch {
            await MainActor.run {
                if showLoading {
                    self.errorMessage = "Failed to load messages: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func cleanupCompletedUploads(confirmedMessages: [ChatMessage]) {
        // Remove pending messages that are now confirmed
        pendingMessages.removeAll { pending in
            confirmedMessages.contains { confirmed in
                // Match by content and sender for more robust matching
                if let pendingMsg = pending.message, let confirmedMsg = confirmed.message {
                    return pendingMsg == confirmedMsg && confirmed.user_id == pending.user_id
                }
                // For media messages, match by type and sender
                if let pendingType = pending.media_type, let confirmedType = confirmed.media_type,
                   let confirmedTime = confirmed.created_at, let pendingTime = pending.created_at {
                    return pendingType == confirmedType &&
                           confirmed.user_id == pending.user_id &&
                           abs(confirmedTime.timeIntervalSince1970 - pendingTime.timeIntervalSince1970) < 10 // Within 10 seconds
                }
                return false
            }
        }
        
        // Clean up completed upload states
        uploadStates = uploadStates.filter { key, state in
            switch state {
            case .completed:
                return !confirmedMessages.contains { $0.idValue == key }
            case .failed, .uploading:
                return true
            }
        }
    }
    
    // MARK: - Message Sending (Improved)
    
    private func sendTextMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let userId = self.userId, !username.isEmpty else { return }
        
        let messageId = UUID().uuidString
        let optimisticMessage = ChatMessage(
            id: nil,
            party_id: partyId,
            user_id: userId,
            username: username,
            message: trimmed,
            created_at: ISO8601DateFormatter().string(from: Date()),
            media_type: nil,
            media_url: nil
        )
        
        pendingMessages.append(optimisticMessage)
        uploadStates[optimisticMessage.idValue] = .uploading
        newMessage = ""
        
        Task {
            await sendMessageToServer(optimisticMessage, messageId: messageId)
        }
    }
    
    private func sendMessageToServer(_ message: ChatMessage, messageId: String) async {
        do {
            let messageInsert = PartyChatInsert(
                party_id: message.party_id,
                user_id: message.user_id,
                username: message.username,
                message: message.message ?? "", // Use empty string if nil
                media_url: message.media_url,
                media_type: message.media_type,
                created_at: message.created_at ?? ISO8601DateFormatter().string(from: Date())
            )
            
            print("Inserting party chat message: \(messageInsert)")
            
            let result = try await supabaseClient
                .from("PartyChatMessages")
                .insert(messageInsert)
                .execute()
            
            print("Insert result: \(String(data: result.data, encoding: .utf8) ?? "nil")")
            
            await MainActor.run {
                uploadStates[message.idValue] = .completed
            }
            
            // Immediate refresh for sent messages
            await loadMessagesInBackground()
        } catch {
            print("Error inserting party chat message: \(error)")
            await MainActor.run {
                uploadStates[message.idValue] = .failed(error.localizedDescription)
                // Keep the message in pending with failed state for retry option
            }
        }
    }
    
    // MARK: - Media Handling (Improved)
    
    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        
        Task {
            do {
                if let data = try await newItem.loadTransferable(type: Data.self) {
                    await uploadAndSendImage(data: data)
                }
            } catch {
                // Handle error appropriately
                print("Failed to load image: \(error)")
            }
        }
    }
    
    private func handleAudioButtonTap() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            if let url = audioRecorder.audioURL {
                Task {
                    await uploadAndSendAudio(url: url)
                }
            }
        } else {
            audioRecorder.startRecording()
        }
    }
    
    private func uploadAndSendImage(data: Data) async {
        guard let userId = self.userId else { return }
        
        let messageId = UUID().uuidString
        let optimisticMessage = ChatMessage(
            id: nil,
            party_id: partyId,
            user_id: userId,
            username: username,
            message: nil,
            created_at: ISO8601DateFormatter().string(from: Date()),
            media_type: "image",
            media_url: "pending"
        )
        
        await MainActor.run {
            pendingMessages.append(optimisticMessage)
            uploadStates[optimisticMessage.idValue] = .uploading
        }
        
        do {
            // Create helper and upload in background
            let helper = MediaUploadHelper(supabaseClient: supabaseClient)
            let publicUrl = try await helper.uploadImage(data: data)
            
            print("Successfully uploaded image: \(publicUrl)")
            
            let messageInsert = PartyChatInsert(
                party_id: partyId,
                user_id: userId,
                username: username,
                message: "", // Use empty string instead of nil for media messages
                media_url: publicUrl,
                media_type: "image",
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            print("Inserting image message: \(messageInsert)")
            
            let result = try await supabaseClient
                .from("PartyChatMessages")
                .insert(messageInsert)
                .execute()
            
            print("Image insert result: \(String(data: result.data, encoding: .utf8) ?? "nil")")
            
            await MainActor.run {
                uploadStates[optimisticMessage.idValue] = .completed
            }
            
            await loadMessagesInBackground()
            
        } catch {
            print("Image upload/insert error: \(error)")
            await MainActor.run {
                uploadStates[optimisticMessage.idValue] = .failed("Failed to upload image: \(error.localizedDescription)")
            }
        }
    }

    private func uploadAndSendAudio(url: URL) async {
        guard let userId = self.userId else { return }
        
        let messageId = UUID().uuidString
        let optimisticMessage = ChatMessage(
            id: nil,
            party_id: partyId,
            user_id: userId,
            username: username,
            message: nil,
            created_at: ISO8601DateFormatter().string(from: Date()),
            media_type: "audio",
            media_url: "pending"
        )
        
        await MainActor.run {
            pendingMessages.append(optimisticMessage)
            uploadStates[optimisticMessage.idValue] = .uploading
        }
        
        do {
            // Ensure audio is in compatible format before upload
            let processedURL = try await processAudioForCompatibility(url)
            
            let helper = MediaUploadHelper(supabaseClient: supabaseClient)
            let publicUrl = try await helper.uploadAudio(url: processedURL)
            
            print("Successfully uploaded audio: \(publicUrl)")
            
            let messageInsert = PartyChatInsert(
                party_id: partyId,
                user_id: userId,
                username: username,
                message: "", // Use empty string instead of nil for media messages
                media_url: publicUrl,
                media_type: "audio",
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            print("Inserting audio message: \(messageInsert)")
            
            let result = try await supabaseClient
                .from("PartyChatMessages")
                .insert(messageInsert)
                .execute()
            
            print("Audio insert result: \(String(data: result.data, encoding: .utf8) ?? "nil")")
            
            await MainActor.run {
                uploadStates[optimisticMessage.idValue] = .completed
            }
            
            await loadMessagesInBackground()
            
        } catch {
            print("Audio upload/insert error: \(error)")
            await MainActor.run {
                uploadStates[optimisticMessage.idValue] = .failed("Failed to upload audio: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Audio Processing for Compatibility
    
    private func processAudioForCompatibility(_ inputURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            // Create output URL for processed audio
            let outputURL = inputURL.appendingPathExtension("m4a")
            
            // Remove existing file if it exists
            try? FileManager.default.removeItem(at: outputURL)
            
            // Set up AVAssetExportSession for format conversion
            let asset = AVAsset(url: inputURL)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
                return
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a
            
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? NSError(domain: "AudioProcessing", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export failed"]))
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 3, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
                default:
                    continuation.resume(throwing: NSError(domain: "AudioProcessing", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown export error"]))
                }
            }
        }
    }
    
    // MARK: - User Management
    
    func initializeUserIdAndUsername() async {
        // Try sessionManager.newUserId first
        if let sessionUserId = sessionManager.newUserId {
            print("[PartyChatView] Using userId from sessionManager: \(sessionUserId)")
            await MainActor.run { self.userId = sessionUserId }
            await fetchUsername(for: sessionUserId)
            return
        }
        // Fallback: fetch user_id from Login Information using email
        let email = sessionManager.userEmail ?? ""
        guard !email.isEmpty else {
            print("[PartyChatView] No email available for fallback userId fetch")
            await MainActor.run { self.errorMessage = "No user ID or email found in session. Please log in again." }
            return
        }
        do {
            let response = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .limit(1)
                .execute()
            struct UserIdRow: Decodable { let user_id: String }
            let rows = try JSONDecoder().decode([UserIdRow].self, from: response.data)
            if let fetchedUserId = rows.first?.user_id {
                print("[PartyChatView] Fallback loaded userId: \(fetchedUserId)")
                await MainActor.run { self.userId = fetchedUserId }
                await fetchUsername(for: fetchedUserId)
            } else {
                print("[PartyChatView] No user_id found for email: \(email)")
                await MainActor.run { self.errorMessage = "No user ID found for your account. Please log in again." }
            }
        } catch {
            print("[PartyChatView] Error fetching user_id by email: \(error)")
            await MainActor.run { self.errorMessage = "Error fetching user ID: \(error.localizedDescription)" }
        }
    }
    
    func fetchUsername(for userId: String) async {
        do {
            let response = try await supabaseClient
                .from("Username")
                .select("username")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            print("[PartyChatView] Username fetch response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            struct UsernameRow: Codable { let username: String }
            let rows = try JSONDecoder().decode([UsernameRow].self, from: response.data)
            if let uname = rows.first?.username {
                print("[PartyChatView] Username found: \(uname)")
                await MainActor.run { self.username = uname }
            } else {
                print("[PartyChatView] No username found for userId: \(userId)")
                await MainActor.run { self.errorMessage = "No username found for your account. Please set a username in your profile." }
            }
        } catch {
            print("[PartyChatView] Error fetching username: \(error)")
            await MainActor.run { self.errorMessage = "Error fetching username: \(error.localizedDescription)" }
        }
    }
    
    // MARK: - Profile Images
    
    func loadProfileImagesForMessages() async {
        for msg in allMessages {
            if profileImages[msg.user_id] == nil {
                let img = await fetchProfileImageForUserId(msg.user_id)
                await MainActor.run { profileImages[msg.user_id] = img }
            }
        }
    }
    
    func fetchProfileImageForUserId(_ userId: String) async -> Image? {
        let manager = ProfileManager(supabaseClient: supabaseClient)
        do {
            if let urlString = try await manager.fetchProfileImageURL(for: userId),
               let url = URL(string: urlString + "?t=\(Int(Date().timeIntervalSince1970))") {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    return Image(uiImage: uiImage)
                }
            }
        } catch {
            print("Failed to fetch profile image for user_id \(userId): \(error)")
        }
        return nil
    }
}

// MARK: - Improved Message Bubble Component for Party Chat

struct PartyChatBubbleView: View {
    let message: PartyChatView.ChatMessage
    let isSelf: Bool
    let uploadState: PartyChatView.UploadState
    let profileImage: Image?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isSelf {
                (profileImage ?? Image(systemName: "person.crop.circle.fill"))
                    .resizable()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            }
            
            if isSelf { Spacer(minLength: 40) }
            
            VStack(alignment: isSelf ? .trailing : .leading, spacing: 4) {
                // Username and timestamp for group chat
                if !isSelf {
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(message.username)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(shortTime(message.created_at ?? ""))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                } else {
                    HStack {
                        Spacer()
                        Text(shortTime(message.created_at ?? ""))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                // Main message content
                messageContentView
                
                // Upload state indicator
                if case .uploading = uploadState {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Sending...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if case .failed(let error) = uploadState {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption2)
                        Text("Failed to send")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            
            if isSelf {
                (profileImage ?? Image(systemName: "person.crop.circle.fill"))
                    .resizable()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            }
            
            if !isSelf { Spacer(minLength: 40) }
        }
    }
    
    @ViewBuilder
    private var messageContentView: some View {
        // Check for media messages first (when media_type exists)
        if let mediaType = message.media_type {
            if mediaType == "image" {
                if let urlString = message.media_url, urlString != "pending", let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure(_):
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .frame(height: 150)
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 150)
                                .overlay {
                                    ProgressView()
                                        .tint(.white)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                } else {
                    // Placeholder for pending image
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 150)
                        .overlay {
                            VStack {
                                Image(systemName: "photo")
                                    .foregroundColor(.white)
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                        }
                }
            } else if mediaType == "audio" {
                if let urlString = message.media_url, urlString != "pending", let url = URL(string: urlString) {
                    AudioPlayerView(audioURL: url)
                } else {
                    // Placeholder for pending audio
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 50)
                        .overlay {
                            HStack {
                                Image(systemName: "mic")
                                    .foregroundColor(.white)
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                }
            }
        }
        // Only show text message if it's not empty AND there's no media type
        else if let messageText = message.message, !messageText.isEmpty {
            Text(messageText)
                .padding(8)
                .background(isSelf ? Color.blue : Color(.sRGB, white: 0.15, opacity: 1.0))
                .foregroundColor(.white)
                .cornerRadius(8)
                .frame(maxWidth: 260, alignment: isSelf ? .trailing : .leading)
        }
    }
    
    private func shortTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: iso) {
            let output = DateFormatter()
            output.timeStyle = .short
            output.dateStyle = .none
            return output.string(from: date)
        }
        return ""
    }
}

// MARK: - ChatMessage Extensions

extension PartyChatView.ChatMessage {
    var idValue: String {
        if let id = id {
            return String(id)
        }
        return "\(party_id)-\(user_id)-\(created_at ?? "")" // More specific ID for party messages
    }
}
