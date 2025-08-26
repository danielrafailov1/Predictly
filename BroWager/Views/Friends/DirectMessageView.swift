import SwiftUI
import Supabase
import PhotosUI
import AVFoundation

struct DirectMessageInsert: Codable {
    let sender_id: String
    let receiver_id: String
    let message: String?
    let media_url: String?
    let media_type: String?
    let created_at: String
    let read: Bool
}

struct DirectMessageView: View {
    let friend: FriendUser
    let currentUserId: String
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var messages: [DirectMessage] = []
    @State private var newMessage: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var timer: Timer? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem? = nil
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var uploadStates: [String: UploadState] = [:] // Track individual upload states
    @State private var pendingMessages: [DirectMessage] = []
    @State private var hasInitiallyScrolled = false
    @State private var lastKnownMessageCount = 0
    
    enum UploadState {
        case uploading
        case completed
        case failed(String)
    }
    
    var allMessages: [DirectMessage] {
        (messages + pendingMessages).sorted { ($0.created_at ?? "") < ($1.created_at ?? "") }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(friend.username)
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
                                let isSelf = message.sender_id == currentUserId
                                let uploadState = uploadStates[message.idValue] ?? .completed
                                MessageBubbleView(
                                    message: message,
                                    isSelf: isSelf,
                                    uploadState: uploadState
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
            loadMessages()
            startPeriodicRefresh()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private var canSendMessage: Bool {
        !newMessage.trimmingCharacters(in: .whitespaces).isEmpty
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
        // Reduced frequency to 5 seconds instead of 3
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
                .from("DirectMessages")
                .select()
                .or("and(sender_id.eq.\(currentUserId),receiver_id.eq.\(friend.user_id)),and(sender_id.eq.\(friend.user_id),receiver_id.eq.\(currentUserId))")
                .order("created_at", ascending: true)
                .execute()
            
            let msgs = try JSONDecoder().decode([DirectMessage].self, from: resp.data)
            
            await MainActor.run {
                let previousCount = self.messages.count
                
                // Check for new messages from the other person
                if !showLoading && msgs.count > self.lastKnownMessageCount {
                    let newMessages = Array(msgs.suffix(msgs.count - self.lastKnownMessageCount))
                    let newMessagesFromFriend = newMessages.filter { $0.sender_id == friend.user_id }
                    
                    for message in newMessagesFromFriend {
                        let notificationBody: String
                        if let mediaType = message.media_type {
                            notificationBody = mediaType == "image" ? "📷 Sent a photo" : "🎵 Sent an audio message"
                        } else {
                            notificationBody = message.message ?? "New message"
                        }
                        
                        NotificationManager.shared.scheduleLocalNotification(
                            title: friend.username,
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
                    let hasNewMessagesFromOther = newMessages.contains { $0.sender_id != currentUserId }
                    
                    if hasNewMessagesFromOther {
                        NotificationCenter.default.post(name: NSNotification.Name("NewMessageReceived"), object: nil)
                    }
                }
                
                if showLoading {
                    self.isLoading = false
                }
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
    
    private func cleanupCompletedUploads(confirmedMessages: [DirectMessage]) {
        // Remove pending messages that are now confirmed
        pendingMessages.removeAll { pending in
            confirmedMessages.contains { confirmed in
                // Match by content and sender for more robust matching
                if let pendingMsg = pending.message, let confirmedMsg = confirmed.message {
                    return pendingMsg == confirmedMsg && confirmed.sender_id == pending.sender_id
                }
                // For media messages, match by type and sender
                if let pendingType = pending.media_type, let confirmedType = confirmed.media_type,
                   let confirmedTime = confirmed.created_at, let pendingTime = pending.created_at {
                    return pendingType == confirmedType &&
                           confirmed.sender_id == pending.sender_id &&
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
        guard !trimmed.isEmpty else { return }
        
        let messageId = UUID().uuidString
        let optimisticMessage = DirectMessage(
            id: nil,
            sender_id: currentUserId,
            receiver_id: friend.user_id,
            message: trimmed,
            created_at: ISO8601DateFormatter().string(from: Date()),
            read: false,
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
    
    private func sendMessageToServer(_ message: DirectMessage, messageId: String) async {
        do {
            _ = try await supabaseClient
                .from("DirectMessages")
                .insert(message)
                .execute()
            
            await MainActor.run {
                uploadStates[message.idValue] = .completed
            }
            
            // Immediate refresh for sent messages
            await loadMessagesInBackground()
        } catch {
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
        let messageId = UUID().uuidString
        let optimisticMessage = DirectMessage(
            id: nil,
            sender_id: currentUserId,
            receiver_id: friend.user_id,
            message: nil,
            created_at: ISO8601DateFormatter().string(from: Date()),
            read: false,
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
            
            let messageInsert = DirectMessageInsert(
                sender_id: currentUserId,
                receiver_id: friend.user_id,
                message: nil,
                media_url: publicUrl,
                media_type: "image",
                created_at: ISO8601DateFormatter().string(from: Date()),
                read: false
            )
            
            _ = try await supabaseClient
                .from("DirectMessages")
                .insert(messageInsert)
                .execute()
            
            await MainActor.run {
                uploadStates[optimisticMessage.idValue] = .completed
            }
            
            await loadMessagesInBackground()
            
        } catch {
            await MainActor.run {
                uploadStates[optimisticMessage.idValue] = .failed("Failed to upload image: \(error.localizedDescription)")
            }
        }
    }

    private func uploadAndSendAudio(url: URL) async {
        let messageId = UUID().uuidString
        let optimisticMessage = DirectMessage(
            id: nil,
            sender_id: currentUserId,
            receiver_id: friend.user_id,
            message: nil,
            created_at: ISO8601DateFormatter().string(from: Date()),
            read: false,
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
            
            let messageInsert = DirectMessageInsert(
                sender_id: currentUserId,
                receiver_id: friend.user_id,
                message: nil,
                media_url: publicUrl,
                media_type: "audio",
                created_at: ISO8601DateFormatter().string(from: Date()),
                read: false
            )
            
            _ = try await supabaseClient
                .from("DirectMessages")
                .insert(messageInsert)
                .execute()
            
            await MainActor.run {
                uploadStates[optimisticMessage.idValue] = .completed
            }
            
            await loadMessagesInBackground()
            
        } catch {
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
}

// MARK: - Improved Message Bubble Component

struct MessageBubbleView: View {
    let message: DirectMessage
    let isSelf: Bool
    let uploadState: DirectMessageView.UploadState
    
    var body: some View {
        HStack {
            if isSelf { Spacer() }
            
            VStack(alignment: isSelf ? .trailing : .leading, spacing: 4) {
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
            
            if !isSelf { Spacer() }
        }
    }
    
    @ViewBuilder
    private var messageContentView: some View {
        // Check if message contains an image URL
        if let messageText = message.message,
           messageText.hasPrefix("https://") &&
           (messageText.contains("/images/") || messageText.contains("supabase") ||
            messageText.lowercased().hasSuffix(".jpg") || messageText.lowercased().hasSuffix(".png") ||
            messageText.lowercased().hasSuffix(".jpeg")) {
            
            if let url = URL(string: messageText) {
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
            }
        } else if let mediaType = message.media_type {
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
        } else if let messageText = message.message {
            Text(messageText)
                .padding(8)
                .background(isSelf ? Color.blue : Color(.sRGB, white: 0.15, opacity: 1.0))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
}

// MARK: - DirectMessage Extensions

extension DirectMessage {
    var idValue: String {
        if let id = id {
            return String(id)
        }
        return UUID().uuidString // Generate consistent ID for pending messages
    }
}

extension String {
    var timeIntervalSince1970: TimeInterval {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: self)?.timeIntervalSince1970 ?? 0
    }
}

struct DirectMessage: Codable, Identifiable {
    let id: Int64?
    let sender_id: String
    let receiver_id: String
    let message: String?
    let created_at: String?
    let read: Bool?
    let media_type: String?
    let media_url: String?
}
