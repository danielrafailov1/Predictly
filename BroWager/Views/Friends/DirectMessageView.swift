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
                        VStack(spacing: 8) {
                            ForEach(messages) { message in
                                let isSelf = message.sender_id == currentUserId
                                HStack {
                                    if isSelf { Spacer() }
                                    VStack(alignment: isSelf ? .trailing : .leading) {
                                        if let mediaType = message.media_type, let urlString = message.media_url, let url = URL(string: urlString) {
                                            if mediaType == "image" {
                                                AsyncImage(url: url) { image in
                                                    image.resizable().scaledToFit()
                                                } placeholder: {
                                                    ProgressView()
                                                }
                                                .frame(maxHeight: 200)
                                            } else if mediaType == "audio" {
                                                AudioPlayerView(audioURL: url)
                                            }
                                        } else {
                                            Text(message.message ?? "")
                                                .padding(8)
                                                .background(isSelf ? Color.blue : Color(.sRGB, white: 0.15, opacity: 1.0))
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                    }
                                    if !isSelf { Spacer() }
                                }
                                .padding(.horizontal)
                                .id(message.id)
                            }
                        }
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last?.id {
                            withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if let last = messages.last?.id {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
            Divider()
            HStack {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Image(systemName: "photo").font(.title2)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                            await uploadAndSendImage(data: data)
                        }
                    }
                }

                Button(action: {
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                        if let url = audioRecorder.audioURL {
                            Task { await uploadAndSendAudio(url: url) }
                        }
                    } else {
                        audioRecorder.startRecording()
                    }
                }) {
                    Image(systemName: audioRecorder.isRecording ? "stop.circle" : "mic").font(.title2)
                }
                .padding(.horizontal)

                TextField("Message...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 36)
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22))
                        .foregroundColor(newMessage.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color(.sRGB, white: 0.10, opacity: 1.0))
        }
        .alert(item: $uploadError) { error in
            Alert(title: Text("Upload Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            loadMessages()
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in loadMessages() }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    private func loadMessages() {
        Task {
            do {
                let resp = try await supabaseClient
                    .from("DirectMessages")
                    .select()
                    .or("and(sender_id.eq.\(currentUserId),receiver_id.eq.\(friend.user_id)),and(sender_id.eq.\(friend.user_id),receiver_id.eq.\(currentUserId))")
                    .order("created_at", ascending: true)
                    .execute()
                let msgs = try JSONDecoder().decode([DirectMessage].self, from: resp.data)
                await MainActor.run {
                    self.messages = msgs
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load messages."
                    self.isLoading = false
                }
            }
        }
    }
    
    private func sendMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let msg = DirectMessage(
            id: nil,
            sender_id: currentUserId,
            receiver_id: friend.user_id,
            message: trimmed,
            created_at: nil,
            read: false,
            media_type: nil,
            media_url: nil
        )
        Task {
            do {
                _ = try await supabaseClient
                    .from("DirectMessages")
                    .insert(msg)
                    .execute()
                await MainActor.run {
                    newMessage = ""
                    loadMessages()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to send message."
                }
            }
        }
    }

    func uploadAndSendImage(data: Data) async {
        isUploading = true
        let fileName = UUID().uuidString + ".jpg"
        let bucket = "chat-media"
        let path = "images/\(fileName)"
        do {
            print("[ImageUpload] Starting upload to path: \(path)")
            try await supabaseClient.storage
                .from(bucket)
                .upload(path: path, file: data)
            let publicUrl = "https://wwqbjakkuprsyvwxlgch.supabase.co/storage/v1/object/public/\(bucket)/\(path)"
            print("[ImageUpload] Uploaded. Public URL: \(publicUrl)")
            let message = [
                "sender_id": currentUserId,
                "receiver_id": friend.user_id,
                "message": nil,
                "media_url": publicUrl,
                "media_type": "image"
            ]
            print("[ImageUpload] Inserting message: \(message)")
            _ = try await supabaseClient.from("DirectMessages").insert(message).execute()
            print("[ImageUpload] Message inserted. Reloading messages.")
            await MainActor.run {
                loadMessages()
                if let last = messages.last?.id {
                    NotificationCenter.default.post(name: NSNotification.Name("ScrollToBottom"), object: last)
                }
            }
        } catch {
            print("[ImageUpload] Error: \(error)")
            uploadError = UploadError(message: error.localizedDescription)
        }
        isUploading = false
    }

    func uploadAndSendAudio(url: URL) async {
        isUploading = true
        let fileName = UUID().uuidString + ".m4a"
        let bucket = "chat-media"
        let path = "audio/\(fileName)"
        do {
            print("[AudioUpload] Starting upload to path: \(path)")
            let data = try Data(contentsOf: url)
            try await supabaseClient.storage
                .from(bucket)
                .upload(path: path, file: data)
            let publicUrl = "https://wwqbjakkuprsyvwxlgch.supabase.co/storage/v1/object/public/\(bucket)/\(path)"
            print("[AudioUpload] Uploaded. Public URL: \(publicUrl)")
            let message = [
                "sender_id": currentUserId,
                "receiver_id": friend.user_id,
                "message": nil,
                "media_url": publicUrl,
                "media_type": "audio"
            ]
            print("[AudioUpload] Inserting message: \(message)")
            _ = try await supabaseClient.from("DirectMessages").insert(message).execute()
            print("[AudioUpload] Message inserted. Reloading messages.")
            await MainActor.run {
                loadMessages()
                if let last = messages.last?.id {
                    NotificationCenter.default.post(name: NSNotification.Name("ScrollToBottom"), object: last)
                }
            }
        } catch {
            print("[AudioUpload] Error: \(error)")
            uploadError = UploadError(message: error.localizedDescription)
        }
        isUploading = false
    }

    func sendTextMessage() async {
        let message = [
            "sender_id": currentUserId,
            "receiver_id": friend.user_id,
            "message": newMessage,
            "media_url": nil,
            "media_type": nil
        ]
        do {
            _ = try await supabaseClient.from("DirectMessages").insert(message).execute()
        } catch {
            uploadError = UploadError(message: error.localizedDescription)
        }
    }
}

struct DirectMessage: Codable, Identifiable {
    let id: Int64?
    let sender_id: String
    let receiver_id: String
    let message: String?      // <-- Make this optional!
    let created_at: String?
    let read: Bool?
    let media_type: String?
    let media_url: String?
    var idValue: Int64 { id ?? Int64(abs(sender_id.hashValue ^ receiver_id.hashValue)) }
}

class AudioRecorder: NSObject, ObservableObject {
    var recorder: AVAudioRecorder?
    @Published var isRecording = false
    var audioURL: URL?

    func startRecording() {
        let fileName = UUID().uuidString + ".m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            print("[AudioRecorder] Starting recording to: \(url)")
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            isRecording = true
            audioURL = url
        } catch {
            print("[AudioRecorder] Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        print("[AudioRecorder] Stopping recording.")
        recorder?.stop()
        isRecording = false
    }
}

struct AudioPlayerView: View {
    let audioURL: URL
    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false

    var body: some View {
        HStack {
            Button(action: {
                if isPlaying {
                    print("[AudioPlayer] Pausing audio")
                    player?.pause()
                } else {
                    if player == nil {
                        print("[AudioPlayer] Creating AVPlayer for URL: \(audioURL)")
                        player = AVPlayer(url: audioURL)
                    }
                    do {
                        print("[AudioPlayer] Setting AVAudioSession to playback")
                        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                        try AVAudioSession.sharedInstance().setActive(true)
                    } catch {
                        print("[AudioPlayer] Failed to set AVAudioSession: \(error)")
                    }
                    print("[AudioPlayer] Playing audio")
                    player?.play()
                }
                isPlaying.toggle()
            }) {
                Image(systemName: isPlaying ? "pause.circle" : "play.circle")
                    .font(.title)
            }
            Text(isPlaying ? "Playing..." : "Play Audio")
        }
    }
}

struct UploadError: Identifiable {
    let id = UUID()
    let message: String
} 
