import AVFoundation
import SwiftUI

@main
struct SmaRacketApp: App {
    init() {
        // 打球音を、iPhoneがマナーモードでも鳴るようにする（ほかのアプリの音楽は止めない）
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
