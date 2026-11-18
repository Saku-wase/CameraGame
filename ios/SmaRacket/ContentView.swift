import SwiftUI

/// ホーム画面（QRコード読み取り）とゲーム画面を切り替える
struct ContentView: View {
    @State private var gameURL: URL?
    @State private var showScanner = false
    @State private var manualText = ""
    @State private var errorText: String?

    var body: some View {
        if let url = gameURL {
            GameView(url: url) { gameURL = nil }
        } else {
            home
        }
    }

    private var home: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("🎾").font(.system(size: 84)).padding(.top, 40)
                Text("スマホラケット").font(.largeTitle.bold())
                Text("PCで tennis.html を開き、\n画面のQRコードを読み取ってください。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button {
                    showScanner = true
                } label: {
                    Label("QRコードを読み取る", systemImage: "qrcode.viewfinder")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                VStack(alignment: .leading, spacing: 6) {
                    Text("または、QRコードのURLを貼り付け")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("https://…/racket.html?id=…", text: $manualText)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("開く") { open(manualText) }
                            .buttonStyle(.bordered)
                    }
                }

                if let errorText {
                    Text(errorText).font(.footnote).foregroundStyle(.red)
                }

                Button {
                    Haptics.shared.play(.perfect)
                } label: {
                    Label("振動テスト", systemImage: "iphone.radiowaves.left.and.right")
                }
                .buttonStyle(.bordered)
                .padding(.top, 10)

                Text("iPhoneの「設定」→「サウンドと触覚」→「システムの触覚」がオフだと振動しません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { code in
                showScanner = false
                open(code)
            } onCancel: {
                showScanner = false
            }
            .ignoresSafeArea()
        }
    }

    private func open(_ text: String) {
        guard let url = Self.gameURL(from: text) else {
            errorText = "ゲームのQRコードではないようです。PCの tennis.html に表示されたQRコードを読み取ってください。"
            return
        }
        errorText = nil
        gameURL = url
    }

    /// https で racket.html を指し、接続先の id が付いた URL だけを受け付ける
    static func gameURL(from text: String) -> URL? {
        guard let comps = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              comps.scheme == "https",
              comps.path.hasSuffix("racket.html"),
              comps.queryItems?.contains(where: { $0.name == "id" && !($0.value ?? "").isEmpty }) == true
        else { return nil }
        return comps.url
    }
}

/// racket.html を表示するゲーム画面
struct GameView: View {
    let url: URL
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(red: 0.063, green: 0.149, blue: 0.227).ignoresSafeArea()
            GameWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.trailing, 14)
            .padding(.top, 6)
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }   // 遊んでいる間は画面を消さない
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
