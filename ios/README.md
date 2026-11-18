# スマラケット（iPhoneアプリ版）

スマホラケット・テニスのスマホ側を iPhone アプリにしたものです。
中身はWeb版の `racket.html` を表示していて、**振動だけ iPhone 本体の機能（Core Haptics）で鳴らします**。

| 出来事 | 振動 |
|---|---|
| パーフェクト | 強い衝撃＋余韻 |
| ナイスショット | しっかり1回 |
| ミスヒット | 鈍く弱い |
| 空振り・フォルト | コツコツ |
| ポイント獲得 | だんだん強く3回 |
| 失点 | 低く長いブーン |

## 必要なもの
- Mac（Xcode 16 以降）
- iPhone（iOS 16 以降）と USB ケーブル
- Apple ID（無料でOK。無料の場合、入れたアプリは7日で起動しなくなるので入れ直してください）

## iPhoneに入れる手順
1. Mac でこのリポジトリをダウンロードし、`ios/SmaRacket.xcodeproj` をダブルクリックして Xcode で開く
2. Xcode の「Settings…」→「Accounts」で自分の Apple ID を追加
3. 左のリストで一番上の **SmaRacket** → TARGETS の **SmaRacket** →「Signing & Capabilities」タブを開く
   - **Team**：自分の名前（Personal Team）を選ぶ
   - **Bundle Identifier**：`com.example.SmaRacket` を世界で1つだけの名前に変える（例：`com.自分の名前.SmaRacket`、英数字のみ）
4. iPhone を USB で Mac につなぎ、Xcode 上部の実行先で自分の iPhone を選ぶ
5. iPhone で「設定」→「プライバシーとセキュリティ」→「デベロッパモード」をオンにする（再起動されます）
6. Xcode の ▶（Run）ボタンを押す
7. 初回は iPhone で「設定」→「一般」→「VPNとデバイス管理」→ 自分の Apple ID を「信頼」してから、もう一度 ▶

## 遊び方
1. PC で `tennis.html`（GitHub Pages の https のURL）を開く
2. iPhone で「スマラケット」アプリを開き、「QRコードを読み取る」で PC 画面のQRコードを読む
   （iPhone の標準カメラで読むと Safari で開いてしまうので、**アプリ内で読み取ってください**）
3. 「スタート（センサーON）」をタップして、あとはWeb版と同じ

ホーム画面の「振動テスト」で振動を確かめられます。振動しないときは「設定」→「サウンドと触覚」→「システムの触覚」がオンか確認してください。

## ファイル
- `SmaRacket/ContentView.swift` … ホーム画面・ゲーム画面
- `SmaRacket/GameWebView.swift` … racket.html を表示し、ページからの振動の合図を受け取る
- `SmaRacket/Haptics.swift` … 振動パターン
- `SmaRacket/QRScannerView.swift` … QRコード読み取り
