import CoreHaptics
import UIKit

/// テニスの手応えを再現する振動デザイン。
///
/// 考え方
/// - 打球は「インパクト（一瞬のコツン）」＋「ガットの余韻（すぐ消えるブーン）」の2層で作る。
///   - 強く振るほどインパクトが強い。
///   - スイートスポットに近いほど、鋭く短くキレのある余韻。外れるほど、鈍く長く、フレームのカタカタが混ざる。
/// - 試合の出来事（バウンド・ネット・空振り）は、打球より弱く控えめにして、打球の手応えを邪魔しない。
/// - 得点・失点は、リズムと強弱の変化（上がる／しぼむ）で気持ちを表す。
final class Haptics {
    static let shared = Haptics()

    /// racket.html から送られてくる名前と同じ
    enum Kind: String, CaseIterable {
        case hit        // 打球（強さ・当たりの良さで変化）
        case miss       // 空振り：空気を切る「スッ」
        case bounce     // 相手の球が自分のコートで弾む「トッ」
        case net        // 自分の球がネットに掛かる「ボスッ」
        case fault      // フォルト
        case cue        // タイミング補助（打ちごろの合図）
        case win        // ポイント獲得
        case lose       // 失点
        case gameWin    // ゲーム獲得
        case gameLose   // ゲームを取られた
        case matchWin   // 試合に勝った
        case matchLose  // 試合に負けた
    }

    /// 打球の細かい情報
    struct Params {
        var power: Float = 0.6      // 0...1 スイングの強さ
        var quality: Int = 1        // 0=ミスヒット 1=ナイス 2=パーフェクト
        var offCenter: Float = 0.3  // 0=スイートスポット … 1=フレームぎりぎり
        var scale: Float = 1        // 全体の振動の強さ（設定）

        init() {}

        init(_ dict: [String: Any]) {
            if let v = dict["p"] as? NSNumber { power = v.floatValue }
            if let v = dict["q"] as? NSNumber { quality = v.intValue }
            if let v = dict["o"] as? NSNumber { offCenter = v.floatValue }
            if let v = dict["scale"] as? NSNumber { scale = v.floatValue }
            power = min(max(power, 0), 1)
            offCenter = min(max(offCenter, 0), 1)
            scale = min(max(scale, 0.2), 1)
        }
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

    /// racket.html からのメッセージ（"hit" のような文字列、または {kind:"hit", p:0.8, q:2, o:0.1}）を再生
    func play(message: Any) {
        if let name = message as? String, let kind = Kind(rawValue: name) {
            play(kind)
        } else if let dict = message as? [String: Any],
                  let name = dict["kind"] as? String,
                  let kind = Kind(rawValue: name) {
            play(kind, Params(dict))
        }
    }

    func play(_ kind: Kind, _ params: Params = Params()) {
        guard let engine else {
            fallback(kind, params)
            return
        }
        do {
            var b = PatternBuilder(scale: params.scale)
            build(kind, params, into: &b)
            let pattern = try CHHapticPattern(events: b.events, parameterCurves: b.curves)
            let player = try engine.makePlayer(with: pattern)
            try engine.start()   // バックグラウンドから戻ると止まっているので毎回起こす（動作中なら何もしない）
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback(kind, params)
        }
    }

    // MARK: - 振動のデザイン

    private func build(_ kind: Kind, _ p: Params, into b: inout PatternBuilder) {
        switch kind {
        case .hit:
            buildHit(p, into: &b)

        case .miss:
            // 空気を切る「スッ」：細く（シャープネス高め）ふくらんで消える
            b.buzz(0, 0.17, 0.32, 0.95)
            b.intensityCurve(0, [(0, 0), (0.06, 1), (0.17, 0)])

        case .bounce:
            // 相手の球が手前で弾む「トッ」：小さく、打つ前の合図として
            b.tap(0, 0.26, 0.45)

        case .net:
            // ネットに掛かる「ボスッ」：にぶく、こもった感じ
            b.tap(0, 0.6, 0.05)
            b.buzz(0.005, 0.14, 0.45, 0.0)
            b.intensityCurve(0.005, [(0, 1), (0.14, 0)])

        case .fault:
            b.tap(0, 0.42, 0.2)
            b.tap(0.15, 0.42, 0.2)

        case .cue:
            // 打ちごろの合図：小さく鋭い「チッ」
            b.tap(0, 0.3, 0.9)

        case .win:
            // だんだん間隔が詰まって強くなり、最後に明るく抜ける
            b.tap(0, 0.35, 0.5)
            b.tap(0.11, 0.55, 0.65)
            b.tap(0.19, 0.8, 0.8)
            b.buzz(0.2, 0.09, 0.6, 0.9)
            b.intensityCurve(0.2, [(0, 1), (0.09, 0)])

        case .lose:
            // 空気が抜けるように、しぼみながら低くなる
            b.buzz(0, 0.45, 0.6, 0.35)
            b.intensityCurve(0, [(0, 1), (0.45, 0.1)])
            b.sharpnessCurve(0, [(0, 0), (0.45, -0.3)])

        case .gameWin:
            // 「タ・タ・ターン」
            b.tap(0, 0.6, 0.7)
            b.tap(0.13, 0.6, 0.7)
            b.tap(0.26, 1.0, 0.85)
            b.buzz(0.265, 0.32, 0.75, 0.55)
            b.intensityCurve(0.265, [(0, 1), (0.08, 0.8), (0.32, 0)])

        case .gameLose:
            // ため息2回
            b.buzz(0, 0.25, 0.5, 0.25)
            b.intensityCurve(0, [(0, 1), (0.25, 0)])
            b.buzz(0.36, 0.42, 0.4, 0.1)
            b.intensityCurve(0.36, [(0, 1), (0.42, 0)])

        case .matchWin:
            // ドラムロールから大きなフィニッシュ
            for i in 0..<10 {
                let t = Double(i) * 0.05
                b.tap(t, 0.2 + 0.05 * Float(i), 0.6)
            }
            b.tap(0.58, 1.0, 1.0)
            b.buzz(0.585, 0.55, 0.9, 0.6)
            b.intensityCurve(0.585, [(0, 1), (0.15, 0.7), (0.55, 0)])

        case .matchLose:
            // ゆっくりした鼓動が弱まっていく
            for (i, t) in [0.0, 0.75].enumerated() {
                let k: Float = i == 0 ? 1 : 0.65
                b.tap(t, 0.5 * k, 0.1)
                b.tap(t + 0.16, 0.35 * k, 0.1)
            }
        }
    }

    /// 打球の手応え
    private func buildHit(_ p: Params, into b: inout PatternBuilder) {
        let pw = 0.55 + 0.45 * p.power   // 強く振るほど強い
        let o = p.offCenter

        switch p.quality {
        case 2:
            // パーフェクト：乾いた鋭い「パコーン」＋キレのある短い余韻＋澄んだ反響
            b.tap(0, min(1, pw + 0.15), 0.95)
            b.buzz(0.004, 0.07, 0.55 * pw, 0.75)
            b.intensityCurve(0.004, [(0, 1), (0.07, 0)])
            b.tap(0.09, 0.28, 1.0)

        case 1:
            // ナイス：しっかりした「パコッ」。中心から外れるほど少し鈍く長く
            let sharp = 0.72 - 0.3 * o
            let len = 0.06 + 0.07 * Double(o)
            b.tap(0, 0.9 * pw, sharp)
            b.buzz(0.004, len, 0.6 * pw, sharp - 0.25)
            b.intensityCurve(0.004, [(0, 1), (len, 0)])
            if o > 0.5 {
                b.tap(0.055, 0.22, 0.3)   // ほんの少しフレームに掛かった感じ
            }

        default:
            // ミスヒット：にぶい「ボスッ」＋フレームのカタカタ
            b.tap(0, 0.55 * pw, 0.18)
            b.buzz(0.005, 0.2, 0.5 * pw, 0.08)
            b.intensityCurve(0.005, [(0, 1), (0.06, 0.6), (0.2, 0)])
            b.tap(0.04, 0.34, 0.15)
            b.tap(0.075, 0.24, 0.15)
            b.tap(0.105, 0.15, 0.15)
        }
    }

    // MARK: - Core Haptics が使えない端末向け

    private func fallback(_ kind: Kind, _ p: Params) {
        switch kind {
        case .hit:
            switch p.quality {
            case 2: UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: CGFloat(p.scale))
            case 1: UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: CGFloat(p.scale))
            default: UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: CGFloat(p.scale))
            }
        case .miss, .bounce, .cue:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: CGFloat(0.5 * p.scale))
        case .net, .fault:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .win, .gameWin, .matchWin:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .lose, .gameLose, .matchLose:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

/// 振動パターンを組み立てる小さな道具
private struct PatternBuilder {
    let scale: Float
    var events: [CHHapticEvent] = []
    var curves: [CHHapticParameterCurve] = []

    /// 一瞬の「コツン」
    mutating func tap(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) {
        events.append(CHHapticEvent(eventType: .hapticTransient,
                                    parameters: params(intensity, sharpness),
                                    relativeTime: time))
    }

    /// 続く「ブーン」
    mutating func buzz(_ time: TimeInterval, _ duration: TimeInterval, _ intensity: Float, _ sharpness: Float) {
        events.append(CHHapticEvent(eventType: .hapticContinuous,
                                    parameters: params(intensity, sharpness),
                                    relativeTime: time,
                                    duration: duration))
    }

    /// 強さを時間で変える（値は 0...1 の倍率）。重なっている振動すべてに効くので、余韻の区間にだけ使う
    mutating func intensityCurve(_ time: TimeInterval, _ points: [(TimeInterval, Float)]) {
        curves.append(curve(.hapticIntensityControl, time, points))
    }

    /// 鋭さを時間で変える（値は -1...1 の足し算）
    mutating func sharpnessCurve(_ time: TimeInterval, _ points: [(TimeInterval, Float)]) {
        curves.append(curve(.hapticSharpnessControl, time, points))
    }

    private func params(_ intensity: Float, _ sharpness: Float) -> [CHHapticEventParameter] {
        [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: min(max(intensity * scale, 0), 1)),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: min(max(sharpness, 0), 1)),
        ]
    }

    private func curve(_ id: CHHapticDynamicParameter.ID, _ time: TimeInterval,
                       _ points: [(TimeInterval, Float)]) -> CHHapticParameterCurve {
        CHHapticParameterCurve(parameterID: id,
                               controlPoints: points.map { .init(relativeTime: $0.0, value: $0.1) },
                               relativeTime: time)
    }
}
