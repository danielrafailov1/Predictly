import SwiftUI
import Supabase
import PhotosUI
import AVFoundation

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
    @State private var selectedImageData: Data? = nil
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var isUploading = false
    @State private var uploadError: UploadError? = nil
    @State private var pendingMessages: [DirectMessage] = [] // For optimistic updates
    @State private var lastMessageCount = 0
    @State private var hasInitiallyScrolled = false
    @State private var lastKnownMessageCount = 0
    
    var allMessages: [DirectMessage] {
        (messages + pendingMessages).sorted { ($0.created_at ?? "") < ($1.created_at ?? "") }
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
            
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                Text(error)
                    .foregroundColor(.red)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) { // Use LazyVStack for better performance
                            ForEach(allMessages) { message in
                                let isSelf = message.sender_id == currentUserId
                                MessageBubbleView(
                                    message: message,
                                    isSelf: isSelf,
                                    isPending: pendingMessages.contains { $0.idValue == message.idValue }
                                )
                                .id(message.idValue)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: allMessages.count) { newCount in
                        // Auto-scroll when new messages arrive (but not on initial load)
                        if hasInitiallyScrolled && newCount > lastMessageCount {
                            scrollToBottom(proxy: proxy)
                        }
                        lastMessageCount = newCount
                    }
                    .onAppear {
                        // Scroll to bottom when chat opens
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToBottom(proxy: proxy)
                            hasInitiallyScrolled = true
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewMessageReceived"))) { _ in
                        // Auto-scroll when receiving new messages from others
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
                    Image(systemName: isUploading ? "photo.fill" : "photo")
                        .font(.title2)
                        .foregroundColor(isUploading ? .gray : .primary)
                }
                .disabled(isUploading)
                .onChange(of: selectedItem) { newItem in
                    handleImageSelection(newItem)
                }

                Button(action: handleAudioButtonTap) {
                    Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic")
                        .font(.title2)
                        .foregroundColor(audioRecorder.isRecording ? .red : .primary)
                }
                .disabled(isUploading)
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
        .alert(item: $uploadError) { error in
            Alert(title: Text("Upload Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
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
        !newMessage.trimmingCharacters(in: .whitespaces).isEmpty && !isUploading
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = allMessages.last {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.idValue, anchor: .bottom)
            }
        }
    }
    
    private func startPeriodicRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
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
                    
                    // Show notification for new messages from friend
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
                
                // Remove pending messages that are now confirmed
                self.pendingMessages.removeAll { pending in
                    msgs.contains { $0.message == pending.message && $0.sender_id == pending.sender_id }
                }
                
                // If we received new messages from others (not initial load), trigger scroll
                if hasInitiallyScrolled && msgs.count > previousCount {
                    // Check if the new messages are from the other person
                    let newMessages = Array(msgs.suffix(msgs.count - previousCount))
                    let hasNewMessagesFromOther = newMessages.contains { $0.sender_id != currentUserId }
                    
                    if hasNewMessagesFromOther {
                        // Post notification to trigger scroll
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
                    self.errorMessage = "Failed to load messages."
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Message Sending
    
    private func sendTextMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Optimistic update
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
        newMessage = ""
        
        Task {
            await sendMessageToServer(optimisticMessage)
        }
    }
    
    private func sendMessageToServer(_ message: DirectMessage) async {
        do {
            _ = try await supabaseClient
                .from("DirectMessages")
                .insert(message)
                .execute()
            
            // Message will be removed from pending when we refresh
            await loadMessagesInBackground()
        } catch {
            await MainActor.run {
                // Remove failed message from pending
                pendingMessages.removeAll { $0.idValue == message.idValue }
                uploadError = UploadError(message: "Failed to send message.")
            }
        }
    }
    
    // MARK: - Media Handling
    
    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else { return }
        
        Task {
            do {
                if let data = try await newItem.loadTransferable(type: Data.self) {
                    await uploadAndSendImage(data: data)
                }
            } catch {
                await MainActor.run {
                    uploadError = UploadError(message: "Failed to load image.")
                }
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
        await MainActor.run { isUploading = true }
        
        // Create optimistic message
        let optimisticMessage = DirectMessage(
            id: nil,
            sender_id: currentUserId,
            receiver_id: friend.user_id,
            message: nil,
            created_at: ISO8601DateFormatter().string(from: Date()),
            read: false,
            media_type: "image",
            media_url: "pending" // Placeholder
        )
        
        await MainActor.run {
            pendingMessages.append(optimisticMessage)
        }
        
        do {
            let helper = MediaUploadHelper(supabaseClient: supabaseClient)
            let publicUrl = try await helper.uploadImage(data: data)
            
            let message = [
                "sender_id": currentUserId,
                "receiver_id": friend.user_id,
                "message": nil,
                "media_url": publicUrl,
                "media_type": "image"
            ]
            
            _ = try await supabaseClient.from("DirectMessages").insert(message).execute()
            
            await MainActor.run {
                // Remove optimistic message
                pendingMessages.removeAll { $0.idValue == optimisticMessage.idValue }
                isUploading = false
            }
            
            await loadMessagesInBackground()
            
        } catch {
            await MainActor.run {
                pendingMessages.removeAll { $0.idValue == optimisticMessage.idValue }
                uploadError = UploadError(message: "Failed to upload image: \(error.localizedDescription)")
                isUploading = false
            }
        }
    }

    private func uploadAndSendAudio(url: URL) async {
        await MainActor.run { isUploading = true }
        
        // Create optimistic message
        let optimisticMessage = DirectMessage(
            id: nil,
            sender_id: currentUserId,
            receiver_id: friend.user_id,
            message: nil,
            created_at: ISO8601DateFormatter().string(from: Date()),
            read: false,
            media_type: "audio",
            media_url: "pending" // Placeholder
        )
        
        await MainActor.run {
            pendingMessages.append(optimisticMessage)
        }
        
        do {
            let helper = MediaUploadHelper(supabaseClient: supabaseClient)
            let publicUrl = try await helper.uploadAudio(url: url)
            
            let message = [
                "sender_id": currentUserId,
                "receiver_id": friend.user_id,
                "message": nil,
                "media_url": publicUrl,
                "media_type": "audio"
            ]
            
            _ = try await supabaseClient.from("DirectMessages").insert(message).execute()
            
            await MainActor.run {
                // Remove optimistic message
                pendingMessages.removeAll { $0.idValue == optimisticMessage.idValue }
                isUploading = false
            }
            
            await loadMessagesInBackground()
            
        } catch {
            await MainActor.run {
                pendingMessages.removeAll { $0.idValue == optimisticMessage.idValue }
                uploadError = UploadError(message: "Failed to upload audio: \(error.localizedDescription)")
                isUploading = false
            }
        }
    }
}

// MARK: - Message Bubble Component

struct MessageBubbleView: View {
    let message: DirectMessage
    let isSelf: Bool
    let isPending: Bool
    
    var body: some View {
        HStack {
            if isSelf { Spacer() }
            
            VStack(alignment: isSelf ? .trailing : .leading) {
                if let mediaType = message.media_type, let urlString = message.media_url {
                    if urlString == "pending" {
                        // Show placeholder for pending media
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: mediaType == "image" ? 150 : 50)
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                            }
                    } else if mediaType == "image", let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 150)
                                .overlay {
                                    ProgressView()
                                        .tint(.white)
                                }
                        }
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                    } else if mediaType == "audio", let url = URL(string: urlString) {
                        AudioPlayerView(audioURL: url)
                    }
                } else if let messageText = message.message {
                    Text(messageText)
                        .padding(8)
                        .background(isSelf ? Color.blue : Color(.sRGB, white: 0.15, opacity: 1.0))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .opacity(isPending ? 0.7 : 1.0)
                }
            }
            
            if !isSelf { Spacer() }
        }
    }
}

// MARK: - DirectMessage Extension

extension DirectMessage {
    var idValue: Int64 {
        id ?? Int64(abs((message ?? media_url ?? "").hashValue ^ sender_id.hashValue ^ receiver_id.hashValue))
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
