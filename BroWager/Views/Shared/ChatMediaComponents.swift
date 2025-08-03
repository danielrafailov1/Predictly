import SwiftUI
import Supabase
import AVFoundation

// MARK: - Audio Recording
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

// MARK: - Audio Player
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
                    .font(.title2)
                    .foregroundColor(.white)
            }
            Text(isPlaying ? "Playing..." : "Play Audio")
                .foregroundColor(.white)
                .font(.caption)
        }
    }
}

// MARK: - Error Handling
struct UploadError: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - Media Upload Helper
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
        
        let data = try Data(contentsOf: url)
        try await supabaseClient.storage
            .from(bucket)
            .upload(path: path, file: data)
        
        return "https://wwqbjakkuprsyvwxlgch.supabase.co/storage/v1/object/public/\(bucket)/\(path)"
    }
}
