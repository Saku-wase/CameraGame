import CoreHaptics
import UIKit

/// ゲームの出来事ごとの振動パターン
final class Haptics {
    static let shared = Haptics()

    /// racket.html から送られてくる名前と同じ
    enum Kind: String {
        case perfect   // パーフェクトショット：強く鋭い衝撃＋余韻
        case good      // ナイスショット
        case weak      // ミスヒット：鈍く弱い
        case miss      // 空振り・フォルト：コツコツ
        case win       // ポイント獲得：だんだん強く3回
        case lose      // 失点：低く長いブーン
    }

    private var engine: CHHapticEngine?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = false
            engine.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func play(_ kind: Kind) {
        guard let engine else {
            fallback(kind)
            return
        }
        do {
            let pattern = try CHHapticPattern(events: events(for: kind), parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()   // バックグラウンドから戻ると止まっているので毎回起こす（動作中なら何もしない）
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback(kind)
        }
    }

    // MARK: - パターン

    private func events(for kind: Kind) -> [CHHapticEvent] {
        switch kind {
        case .perfect:
            return [tap(0, 1.0, 1.0), buzz(0.01, 0.16, 1.0, 0.5), tap(0.2, 0.8, 0.9)]
        case .good:
            return [tap(0, 1.0, 0.7), buzz(0.01, 0.1, 0.7, 0.4)]
        case .weak:
            return [tap(0, 0.5, 0.1), buzz(0.01, 0.18, 0.35, 0.05)]
        case .miss:
            return [tap(0, 0.45, 0.3), tap(0.12, 0.45, 0.3)]
        case .win:
            return [tap(0, 0.5, 0.5), tap(0.1, 0.75, 0.7), tap(0.2, 1.0, 0.9)]
        case .lose:
            return [buzz(0, 0.35, 0.55, 0.1)]
        }
    }

    /// 一瞬の「コツン」
    private func tap(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient,
                      parameters: [
                          CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                          CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                      ],
                      relativeTime: time)
    }

    /// 続く「ブーン」
    private func buzz(_ time: TimeInterval, _ duration: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous,
                      parameters: [
                          CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                          CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                      ],
                      relativeTime: time,
                      duration: duration)
    }

    /// Core Haptics が使えない端末向け
    private func fallback(_ kind: Kind) {
        switch kind {
        case .perfect, .good:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .weak:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .miss:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .win:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .lose:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
