import SwiftUI
import Supabase
import AVFoundation

// MARK: - Audio Recording
class AudioRecorder: NSObject, ObservableObject {
    var recorder: AVAudioRecorder?
    @Published var isRecording = false
    var audioURL: URL?
    private let audioSession = AVAudioSession.sharedInstance()

    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            // Request microphone permission first
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    print("[AudioRecorder] Microphone permission granted: \(granted)")
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    print("[AudioRecorder] Microphone permission granted: \(granted)")
                }
            }
            
            // Configure session for recording and playback
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            
            print("[AudioRecorder] Audio session setup successful")
            print("[AudioRecorder] Available inputs: \(audioSession.availableInputs?.map { $0.portType.rawValue } ?? [])")
            print("[AudioRecorder] Current route: \(audioSession.currentRoute.inputs.map { $0.portType.rawValue })")
        } catch {
            print("[AudioRecorder] Failed to setup audio session: \(error)")
        }
    }

    func startRecording() {
        let fileName = UUID().uuidString + ".m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // Ensure audio session is active for recording
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            print("[AudioRecorder] Starting recording to: \(url)")
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
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

// MARK: - Audio Recorder Delegate
extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("[AudioRecorder] Recording finished successfully: \(flag)")
        if !flag {
            print("[AudioRecorder] Recording failed")
        }
    }
}

// MARK: - Audio Player
struct AudioPlayerView: View {
    let audioURL: URL
    @StateObject private var audioManager = AudioPlaybackManager()
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var progressTimer: Timer?

    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(errorMessage != nil ? .red : .blue)
            }
            .disabled(isLoading || errorMessage != nil)
            
            VStack(alignment: .leading, spacing: 4) {
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let error = errorMessage {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    // Progress Bar
                    ProgressView(value: duration > 0 ? currentTime / duration : 0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(height: 4)
                    
                    // Time Labels
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatTime(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Audio Wave Icon
            Image(systemName: "waveform")
                .foregroundColor(.blue)
                .font(.system(size: 16))
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .frame(minWidth: 180)
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private func cleanup() {
        progressTimer?.invalidate()
        progressTimer = nil
        audioManager.stop()
    }
    
    private func setupAudioPlayer() {
        print("[AudioPlayerView] Setting up audio player for URL: \(audioURL)")
        
        Task {
            do {
                try await audioManager.setupPlayer(with: audioURL)
                await MainActor.run {
                    self.duration = audioManager.duration
                    self.isLoading = false
                    print("[AudioPlayerView] ✅ Audio player setup successful, duration: \(self.duration)")
                }
            } catch {
                await MainActor.run {
                    // Provide more specific error message
                    if let audioError = error as? AudioPlayerError {
                        self.errorMessage = audioError.localizedDescription
                    } else {
                        self.errorMessage = "Load failed: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                    
                    print("[AudioPlayerView] ❌ Audio player setup failed:")
                    print("[AudioPlayerView] Error type: \(type(of: error))")
                    print("[AudioPlayerView] Error description: \(error.localizedDescription)")
                    
                    // Log device-specific info for debugging
                    print("[AudioPlayerView] Device model: \(UIDevice.current.model)")
                    print("[AudioPlayerView] iOS version: \(UIDevice.current.systemVersion)")
                    print("[AudioPlayerView] URL: \(self.audioURL)")
                }
            }
        }
    }
    
    private func startProgressTimer() {
        // Invalidate existing timer
        progressTimer?.invalidate()
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            Task { @MainActor in
                if audioManager.isPlaying {
                    currentTime = audioManager.currentTime
                    
                    // Check if playback finished
                    if currentTime >= duration && duration > 0 {
                        isPlaying = false
                        currentTime = 0
                        timer.invalidate()
                        progressTimer = nil
                    }
                } else if !isPlaying {
                    timer.invalidate()
                    progressTimer = nil
                }
            }
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioManager.pause()
            progressTimer?.invalidate()
            progressTimer = nil
        } else {
            do {
                try audioManager.play()
                startProgressTimer()
            } catch {
                errorMessage = "Playback failed"
                print("[AudioPlayer] Play failed: \(error)")
                return
            }
        }
        isPlaying.toggle()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Playback Manager
@MainActor
class AudioPlaybackManager: ObservableObject {
    private var player: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()
    
    var isPlaying: Bool {
        player?.isPlaying ?? false
    }
    
    var duration: TimeInterval {
        player?.duration ?? 0
    }
    
    var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }
    
    func setupPlayer(with url: URL) async throws {
        print("[AudioPlaybackManager] === DETAILED SETUP DEBUG ===")
        print("[AudioPlaybackManager] Setting up player for URL: \(url)")
        print("[AudioPlaybackManager] Device: \(UIDevice.current.model)")
        print("[AudioPlaybackManager] iOS Version: \(UIDevice.current.systemVersion)")
        print("[AudioPlaybackManager] URL scheme: \(url.scheme ?? "none")")
        print("[AudioPlaybackManager] URL host: \(url.host ?? "none")")
        
        // Get audio data with extensive debugging
        let audioData: Data
        do {
            if url.isFileURL {
                print("[AudioPlaybackManager] Loading local file...")
                let fileExists = FileManager.default.fileExists(atPath: url.path)
                print("[AudioPlaybackManager] File exists: \(fileExists)")
                
                if fileExists {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    print("[AudioPlaybackManager] File size on disk: \(attributes[.size] ?? "unknown") bytes")
                }
                
                audioData = try Data(contentsOf: url)
                print("[AudioPlaybackManager] Successfully loaded local file, size: \(audioData.count) bytes")
            } else {
                print("[AudioPlaybackManager] Downloading remote audio from: \(url)")
                
                // Test basic connectivity first
                print("[AudioPlaybackManager] Testing basic connectivity...")
                let (testData, testResponse) = try await URLSession.shared.data(from: url)
                print("[AudioPlaybackManager] Basic test successful, received \(testData.count) bytes")
                
                if let httpResponse = testResponse as? HTTPURLResponse {
                    print("[AudioPlaybackManager] HTTP Status: \(httpResponse.statusCode)")
                    print("[AudioPlaybackManager] Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "none")")
                    print("[AudioPlaybackManager] Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "none")")
                    
                    guard httpResponse.statusCode == 200 else {
                        throw AudioPlayerError.downloadFailed(statusCode: httpResponse.statusCode)
                    }
                }
                
                audioData = testData
                print("[AudioPlaybackManager] Successfully downloaded remote file, size: \(audioData.count) bytes")
            }
        } catch {
            print("[AudioPlaybackManager] ❌ FAILED to get audio data: \(error)")
            print("[AudioPlaybackManager] Error type: \(type(of: error))")
            if let urlError = error as? URLError {
                print("[AudioPlaybackManager] URLError code: \(urlError.code.rawValue)")
                print("[AudioPlaybackManager] URLError description: \(urlError.localizedDescription)")
            }
            throw AudioPlayerError.dataLoadFailed(error)
        }
        
        // Extensive data validation
        print("[AudioPlaybackManager] Validating audio data...")
        guard audioData.count > 0 else {
            print("[AudioPlaybackManager] ❌ Audio data is completely empty!")
            throw AudioPlayerError.invalidAudioData
        }
        
        guard audioData.count > 44 else {
            print("[AudioPlaybackManager] ❌ Audio data too small: \(audioData.count) bytes")
            throw AudioPlayerError.invalidAudioData
        }
        
        // Detailed header analysis
        let headerBytes = audioData.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " ")
        print("[AudioPlaybackManager] Audio header (16 bytes): \(headerBytes)")
        
        // Check for common audio format signatures
        if audioData.count >= 4 {
            let signature = audioData.prefix(4)
            if signature.starts(with: [0x66, 0x74, 0x79, 0x70]) { // "ftyp"
                print("[AudioPlaybackManager] ✅ Detected MP4/M4A format")
            } else if signature.starts(with: [0x49, 0x44, 0x33]) { // "ID3"
                print("[AudioPlaybackManager] ✅ Detected MP3 format")
            } else {
                print("[AudioPlaybackManager] ⚠️ Unknown audio format signature")
            }
        }
        
        // Configure audio session with multiple fallback strategies
        print("[AudioPlaybackManager] Configuring audio session...")
        do {
            // Don't immediately set active - just configure the category
            try audioSession.setCategory(.playback, mode: .default, options: [])
            print("[AudioPlaybackManager] ✅ Basic audio session category set")
        } catch {
            print("[AudioPlaybackManager] ⚠️ Basic category setting failed: \(error)")
            // Continue anyway - we'll try again during play()
        }
        
        // Log detailed audio route info
        let currentRoute = audioSession.currentRoute
        print("[AudioPlaybackManager] Audio route details:")
        print("[AudioPlaybackManager] - Input count: \(currentRoute.inputs.count)")
        print("[AudioPlaybackManager] - Output count: \(currentRoute.outputs.count)")
        for (index, output) in currentRoute.outputs.enumerated() {
            print("[AudioPlaybackManager] - Output \(index): \(output.portType.rawValue) - \(output.portName)")
        }
        
        // Create temporary file strategy for remote URLs
        var playerData = audioData
        var tempFileURL: URL?
        
        if !url.isFileURL {
            print("[AudioPlaybackManager] Creating temporary file for remote audio...")
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileName = UUID().uuidString + ".m4a"
            tempFileURL = tempDir.appendingPathComponent(tempFileName)
            
            do {
                try audioData.write(to: tempFileURL!)
                print("[AudioPlaybackManager] ✅ Temporary file created: \(tempFileURL!.path)")
                print("[AudioPlaybackManager] Temp file size: \(try Data(contentsOf: tempFileURL!).count) bytes")
            } catch {
                print("[AudioPlaybackManager] ⚠️ Failed to create temp file: \(error)")
                // Continue with data approach
            }
        }
        
        // Try multiple player creation strategies
        print("[AudioPlaybackManager] Creating AVAudioPlayer...")
        var playerCreationError: Error?
        
        // Strategy 1: Try with temporary file if available
        if let tempURL = tempFileURL {
            do {
                print("[AudioPlaybackManager] Attempting player creation with temp file...")
                player = try AVAudioPlayer(contentsOf: tempURL)
                print("[AudioPlaybackManager] ✅ Player created successfully with temp file")
            } catch {
                print("[AudioPlaybackManager] ⚠️ Temp file player creation failed: \(error)")
                playerCreationError = error
            }
        }
        
        // Strategy 2: Try with original URL if local
        if player == nil && url.isFileURL {
            do {
                print("[AudioPlaybackManager] Attempting player creation with original URL...")
                player = try AVAudioPlayer(contentsOf: url)
                print("[AudioPlaybackManager] ✅ Player created successfully with original URL")
            } catch {
                print("[AudioPlaybackManager] ⚠️ Original URL player creation failed: \(error)")
                playerCreationError = error
            }
        }
        
        // Strategy 3: Try with data
        if player == nil {
            do {
                print("[AudioPlaybackManager] Attempting player creation with data...")
                player = try AVAudioPlayer(data: playerData)
                print("[AudioPlaybackManager] ✅ Player created successfully with data")
            } catch {
                print("[AudioPlaybackManager] ❌ Data player creation failed: \(error)")
                playerCreationError = error
            }
        }
        
        // Final validation
        guard let finalPlayer = player else {
            print("[AudioPlaybackManager] ❌ All player creation strategies failed")
            if let error = playerCreationError {
                print("[AudioPlaybackManager] Last error: \(error)")
            }
            throw AudioPlayerError.playerCreationFailed
        }
        
        // Prepare and validate player
        let prepareResult = finalPlayer.prepareToPlay()
        print("[AudioPlaybackManager] prepareToPlay() result: \(prepareResult)")
        print("[AudioPlaybackManager] Player duration: \(finalPlayer.duration)")
        print("[AudioPlaybackManager] Player URL: \(finalPlayer.url?.absoluteString ?? "none")")
        print("[AudioPlaybackManager] Player format description: \(finalPlayer.format)")
        
        guard finalPlayer.duration > 0 else {
            print("[AudioPlaybackManager] ❌ Player has invalid duration: \(finalPlayer.duration)")
            throw AudioPlayerError.playerCreationFailed
        }
        
        print("[AudioPlaybackManager] ✅ Player setup completed successfully!")
        print("[AudioPlaybackManager] Final duration: \(finalPlayer.duration) seconds")
        print("[AudioPlaybackManager] === END SETUP DEBUG ===")
    }
    
    func play() throws {
        guard let player = player else {
            print("[AudioPlaybackManager] No player available")
            throw AudioPlayerError.playerNotSetup
        }
        
        // Smart audio session management - only reconfigure if needed
        print("[AudioPlaybackManager] Checking current audio session state...")
        let currentCategory = audioSession.category
        let currentOptions = audioSession.categoryOptions
        print("[AudioPlaybackManager] Current category: \(currentCategory)")
        print("[AudioPlaybackManager] Current options: \(currentOptions)")
        
        // Only reconfigure if we're not already in playback mode
        if currentCategory != .playback {
            print("[AudioPlaybackManager] Reconfiguring audio session for playback...")
            do {
                // Try progressive audio session configuration
                try configureAudioSessionForPlayback()
            } catch {
                print("[AudioPlaybackManager] Failed to configure audio session: \(error)")
                // Try to continue anyway - sometimes it works even after configuration failure
                print("[AudioPlaybackManager] Attempting playback despite configuration error...")
            }
        } else {
            print("[AudioPlaybackManager] Audio session already configured for playback")
        }
        
        // Ensure session is active (this is safer than full reconfiguration)
        do {
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true)
                print("[AudioPlaybackManager] Audio session activated successfully")
            } else {
                print("[AudioPlaybackManager] Other audio is playing, using mix mode")
                try audioSession.setCategory(.playback, options: [.mixWithOthers])
                try audioSession.setActive(true)
            }
        } catch {
            print("[AudioPlaybackManager] Warning: Failed to activate audio session: \(error)")
            // Continue anyway - playback might still work
        }
        
        // Set volume and attempt playback
        player.volume = 1.0
        print("[AudioPlaybackManager] Starting playback... Volume: \(player.volume)")
        print("[AudioPlaybackManager] Player ready: \(player.isPlaying)")
        
        // Try playback with fallback strategies
        var playbackSuccess = false
        
        // Strategy 1: Normal play
        playbackSuccess = player.play()
        print("[AudioPlaybackManager] Initial play() result: \(playbackSuccess)")
        
        // Strategy 2: If failed, try after brief delay
        if !playbackSuccess {
            print("[AudioPlaybackManager] Initial playback failed, trying after delay...")
            
            // Use a different approach for the delay that doesn't require async
            Thread.sleep(forTimeInterval: 0.1)
            playbackSuccess = player.play()
            print("[AudioPlaybackManager] Delayed play() result: \(playbackSuccess)")
        }
        
        guard playbackSuccess || player.isPlaying else {
            print("[AudioPlaybackManager] ❌ All playback strategies failed")
            print("[AudioPlaybackManager] Player URL: \(player.url?.absoluteString ?? "none")")
            print("[AudioPlaybackManager] Player duration: \(player.duration)")
            print("[AudioPlaybackManager] Player format: \(player.format)")
            print("[AudioPlaybackManager] Player volume: \(player.volume)")
            print("[AudioPlaybackManager] Player is playing: \(player.isPlaying)")
            
            throw AudioPlayerError.playbackFailed
        }
        
        print("[AudioPlaybackManager] ✅ Playback started successfully")
    }
    
    private func configureAudioSessionForPlayback() throws {
        // Progressive configuration - try most permissive first, then fall back
        let configurations: [(AVAudioSession.Category, AVAudioSession.CategoryOptions)] = [
            (.playback, []),                                    // Most basic
            (.playback, [.defaultToSpeaker]),                   // Route to speaker
            (.playback, [.allowBluetooth]),                     // Allow bluetooth
            (.playback, [.defaultToSpeaker, .allowBluetooth]),  // Both
            (.playAndRecord, [.defaultToSpeaker])               // Fallback to record mode
        ]
        
        var lastError: Error?
        
        for (category, options) in configurations {
            do {
                print("[AudioPlaybackManager] Trying category: \(category), options: \(options)")
                try audioSession.setCategory(category, options: options)
                print("[AudioPlaybackManager] ✅ Successfully set category: \(category)")
                return // Success!
            } catch {
                print("[AudioPlaybackManager] ⚠️ Failed category \(category): \(error)")
                lastError = error
                continue
            }
        }
        
        // If all configurations failed, throw the last error
        if let error = lastError {
            throw error
        }
    }
    
    func pause() {
        print("[AudioPlaybackManager] Pausing playback")
        player?.pause()
    }
    
    func stop() {
        print("[AudioPlaybackManager] Stopping playback")
        player?.stop()
        player?.currentTime = 0
        
        // Safely deactivate audio session
        do {
            // Only deactivate if we're not recording or playing other audio
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                print("[AudioPlaybackManager] Audio session deactivated")
            } else {
                print("[AudioPlaybackManager] Other audio playing, keeping session active")
            }
        } catch {
            print("[AudioPlaybackManager] Note: Audio session deactivation failed: \(error)")
            // This is often not critical - other apps may be using audio
        }
    }
}

// MARK: - Enhanced Audio Player Errors
enum AudioPlayerError: LocalizedError {
    case playerNotSetup
    case playbackFailed
    case invalidAudioData
    case downloadFailed(statusCode: Int)
    case dataLoadFailed(Error)
    case playerCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .playerNotSetup:
            return "Audio player is not properly setup"
        case .playbackFailed:
            return "Failed to start audio playback"
        case .invalidAudioData:
            return "Invalid or corrupted audio data"
        case .downloadFailed(let statusCode):
            return "Failed to download audio (HTTP \(statusCode))"
        case .dataLoadFailed(let error):
            return "Failed to load audio data: \(error.localizedDescription)"
        case .playerCreationFailed:
            return "Failed to create audio player"
        }
    }
}

// MARK: - Error Handling
struct UploadError: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - Enhanced Media Upload Helper
struct MediaUploadHelper {
    let supabaseClient: SupabaseClient
    
    func uploadImage(data: Data) async throws -> String {
        let fileName = UUID().uuidString + ".jpg"
        let bucket = "chat-media"
        let path = "images/\(fileName)"
        
        try await supabaseClient.storage
            .from(bucket)
            .upload(path: path, file: data)
        
        return "https://wwqbjakkuprsyvwxlgch.supabase.co/storage/v1/object/public/\(bucket)/\(path)"
    }
    
    func uploadAudio(url: URL) async throws -> String {
        let fileName = UUID().uuidString + ".m4a"
        let bucket = "chat-media"
        let path = "audio/\(fileName)"
        
        print("[MediaUploadHelper] === UPLOAD DEBUG START ===")
        print("[MediaUploadHelper] Device: \(UIDevice.current.model)")
        print("[MediaUploadHelper] iOS: \(UIDevice.current.systemVersion)")
        print("[MediaUploadHelper] Source URL: \(url)")
        
        let data = try Data(contentsOf: url)
        
        // Enhanced validation and debugging for audio data
        guard data.count > 44 else {
            print("[MediaUploadHelper] ❌ Audio file too small: \(data.count) bytes")
            throw NSError(domain: "AudioUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio file is too small or empty"])
        }
        
        // Log detailed audio file info for debugging
        let headerBytes = data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " ")
        print("[MediaUploadHelper] Audio file size: \(data.count) bytes")
        print("[MediaUploadHelper] Audio header (16 bytes): \(headerBytes)")
        
        // Test if the audio data is valid by trying to create a test player
        do {
            let testPlayer = try AVAudioPlayer(data: data)
            print("[MediaUploadHelper] ✅ Test player creation successful, duration: \(testPlayer.duration)")
        } catch {
            print("[MediaUploadHelper] ⚠️ Test player creation failed: \(error)")
            // Continue with upload anyway, might be a device-specific issue
        }
        
        print("[MediaUploadHelper] Uploading to path: \(path)")
        try await supabaseClient.storage
            .from(bucket)
            .upload(path: path, file: data)
        
        let publicURL = "https://wwqbjakkuprsyvwxlgch.supabase.co/storage/v1/object/public/\(bucket)/\(path)"
        print("[MediaUploadHelper] ✅ Upload completed: \(publicURL)")
        
        // Enhanced verification with retry logic
        print("[MediaUploadHelper] Verifying upload accessibility...")
        var verificationAttempts = 0
        let maxAttempts = 3
        
        while verificationAttempts < maxAttempts {
            do {
                var request = URLRequest(url: URL(string: publicURL)!)
                request.timeoutInterval = 10.0
                request.cachePolicy = .reloadIgnoringLocalCacheData
                
                let (verifyData, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("[MediaUploadHelper] Verification HTTP Status: \(httpResponse.statusCode)")
                    print("[MediaUploadHelper] Verification data size: \(verifyData.count) bytes")
                    
                    if httpResponse.statusCode == 200 && verifyData.count > 0 {
                        print("[MediaUploadHelper] ✅ Upload verification successful")
                        break
                    }
                }
                
                verificationAttempts += 1
                if verificationAttempts < maxAttempts {
                    print("[MediaUploadHelper] Verification attempt \(verificationAttempts) failed, retrying...")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                }
            } catch {
                verificationAttempts += 1
                print("[MediaUploadHelper] Verification attempt \(verificationAttempts) error: \(error)")
                
                if verificationAttempts < maxAttempts {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                }
            }
        }
        
        if verificationAttempts >= maxAttempts {
            print("[MediaUploadHelper] ⚠️ Upload verification failed after \(maxAttempts) attempts")
        }
        
        print("[MediaUploadHelper] === UPLOAD DEBUG END ===")
        return publicURL
    }
    
    // Add this helper function for testing audio playback capability
    static func testDeviceAudioCapability() async {
        print("[MediaUploadHelper] === DEVICE AUDIO CAPABILITY TEST ===")
        print("[MediaUploadHelper] Device: \(UIDevice.current.model)")
        print("[MediaUploadHelper] iOS: \(UIDevice.current.systemVersion)")
        
        let audioSession = AVAudioSession.sharedInstance()
        
        // Test audio session capabilities
        do {
            try audioSession.setCategory(.playback)
            try audioSession.setActive(true)
            print("[MediaUploadHelper] ✅ Basic audio session setup successful")
            
            let route = audioSession.currentRoute
            print("[MediaUploadHelper] Available outputs: \(route.outputs.map { $0.portType.rawValue })")
            print("[MediaUploadHelper] Sample rate: \(audioSession.sampleRate)")
            print("[MediaUploadHelper] Output latency: \(audioSession.outputLatency)")
        } catch {
            print("[MediaUploadHelper] ❌ Audio session setup failed: \(error)")
        }
        
        // Test with a minimal audio file
        let testAudioData = createMinimalM4AData()
        do {
            let testPlayer = try AVAudioPlayer(data: testAudioData)
            print("[MediaUploadHelper] ✅ Test M4A player creation successful")
            print("[MediaUploadHelper] Test duration: \(testPlayer.duration)")
        } catch {
            print("[MediaUploadHelper] ❌ Test M4A player creation failed: \(error)")
        }
        
        print("[MediaUploadHelper] === END CAPABILITY TEST ===")
    }
    
    // Create minimal valid M4A data for testing
    private static func createMinimalM4AData() -> Data {
        // This is a minimal M4A file header - just for testing player creation
        let minimalM4A: [UInt8] = [
            0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, // ftyp box
            0x4D, 0x34, 0x41, 0x20, 0x00, 0x00, 0x00, 0x00,
            0x4D, 0x34, 0x41, 0x20, 0x6D, 0x70, 0x34, 0x31,
            0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32
        ]
        return Data(minimalM4A)
    }
}
