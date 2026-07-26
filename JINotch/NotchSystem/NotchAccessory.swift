//
//  NotchAccessory.swift
//  JINotch
//
//  ノッチ下パネル(自作)を管理するコントローラ。
//  パネルは縦2段構成:
//    ・heading bar … ノッチの高さぶんの帯。中央にノッチ幅の空きを作り、
//                    左右の項目をノッチのすぐ脇に寄せる。
//    ・本体        … ノッチ真下のメイン領域(バッテリー詳細など)。
//  ホバー展開に連動して、ノッチサイズから中身の実寸へ広がる。
//
//  使い方:
//    NotchAccessoryController.shared.configure()
//    NotchAccessoryController.shared.setBottomContent { NotchView() }          // 本体
//    NotchAccessoryController.shared.setHeadingContent(.leading) { NotchClockWidget() } // 左脇
//    NotchAccessoryController.shared.setHeadingContent(.trailing) { ... }              // 右脇
//

import SwiftUI
import Cocoa
import Combine

// MARK: - 表示する辺

enum NotchEdge: Hashable {
    case leading   // ノッチ左側
    case trailing  // ノッチ右側
}

// MARK: - 各エリアのフレーム計算

struct NotchFrames {
    let leading: CGRect   // ノッチ左の帯
    let trailing: CGRect  // ノッチ右の帯
    let notch: CGRect     // ノッチ中央
}

/// 画面からノッチ左右／中央それぞれのグローバル座標フレームを算出する。
/// ノッチのない画面では nil を返す。
func notchAccessoryFrames(for screen: NSScreen) -> NotchFrames? {
    let inset = screen.safeAreaInsets.top
    guard inset > 0,
          let leftArea = screen.auxiliaryTopLeftArea,
          let rightArea = screen.auxiliaryTopRightArea else {
        // ノッチがない画面(外部ディスプレイなど)
        return nil
    }

    let topY = screen.frame.maxY - inset
    let notchWidth = screen.frame.width - leftArea.width - rightArea.width

    let leading = CGRect(
        x: screen.frame.minX,
        y: topY,
        width: leftArea.width,
        height: inset
    )
    let trailing = CGRect(
        x: screen.frame.maxX - rightArea.width,
        y: topY,
        width: rightArea.width,
        height: inset
    )
    let notch = CGRect(
        x: screen.frame.minX + leftArea.width,
        y: topY,
        width: notchWidth,
        height: inset
    )
    return NotchFrames(leading: leading, trailing: trailing, notch: notch)
}

// MARK: - コントローラ

/// ノッチ下パネルの開閉と中身を司る。
@MainActor
final class NotchAccessoryController {
    static let shared = NotchAccessoryController()

    private let model = NotchExpandedModel()
    private var window: NotchExpandedWindow?
    private var targetScreen: NSScreen?
    private var pendingCollapse: DispatchWorkItem?

    /// パネル用ウィンドウのサイズ(中身より広めに確保。中でパネルが伸縮する)。
    private let windowSize = CGSize(width: 680, height: 460)

    /// 現在 expand(ホバー展開)中かどうか。
    private(set) var isExpanded = false

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        model.onHover = { [weak self] hovering in
            self?.setHovering(hovering)
        }
    }

    /// 対象スクリーン・最低横幅・本体まわりの余白の設定。省略時はメイン画面・最低幅/余白なし。
    func configure(on screen: NSScreen? = NSScreen.main, minWidth: CGFloat = 0, contentPadding: CGFloat = 0) {
        self.targetScreen = screen ?? NSScreen.main
        model.minWidth = minWidth
        model.contentPadding = contentPadding
    }

    /// 展開時パネルの最低横幅を設定する(中身が小さくてもこれ以上は縮まない)。
    func setMinWidth(_ width: CGFloat) {
        model.minWidth = width
    }

    /// 本体(ノッチ真下)まわりの余白を設定する。
    func setContentPadding(_ padding: CGFloat) {
        model.contentPadding = padding
    }

    // MARK: 中身の登録

    /// ノッチ真下のメイン領域に出す内容(旧 DynamicNotch のポップオーバー相当)。
    func setBottomContent<Content: View>(@ViewBuilder content: () -> Content) {
        model.content = AnyView(content())
    }

    /// ノッチ両脇(heading bar)に出す内容。左右それぞれノッチに寄り添う。
    func setHeadingContent<Content: View>(_ edge: NotchEdge, @ViewBuilder content: () -> Content) {
        switch edge {
        case .leading:  model.headingLeading = AnyView(content())
        case .trailing: model.headingTrailing = AnyView(content())
        }
    }

    // MARK: 開閉

    /// ホバーの ON/OFF を1本化して受ける。少し遅延させてから畳むことで、
    /// ノッチ→パネルへマウスが移動しても閉じないようにする。
    func setHovering(_ hovering: Bool) {
        pendingCollapse?.cancel()
        pendingCollapse = nil
        if hovering {
            expand()
        } else {
            let work = DispatchWorkItem { [weak self] in self?.collapse() }
            pendingCollapse = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }
    }

    func expand() {
        isExpanded = true
        if let window = ensureWindow() {
            window.orderFrontRegardless()
            model.isExpanded = true
        }
    }

    func collapse() {
        isExpanded = false
        model.isExpanded = false
        // アニメーションが終わってからウィンドウを外す(再展開されたら残す)
        let window = self.window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, !self.isExpanded else { return }
            window?.orderOut(nil)
        }
    }

    // MARK: 内部

    @objc private func screenParametersChanged() {
        guard let window,
              let screen = targetScreen ?? NSScreen.main,
              let frames = notchAccessoryFrames(for: screen) else {
            return
        }
        model.collapsedSize = frames.notch.size
        window.setFrame(windowFrame(screen: screen, frames: frames), display: true)
    }

    private func windowFrame(screen: NSScreen, frames: NotchFrames) -> CGRect {
        // 最低横幅を大きく設定してもパネルが収まるようウィンドウ幅を確保する
        let width = max(windowSize.width, model.minWidth + 80)
        return CGRect(
            x: frames.notch.midX - width / 2,
            y: screen.frame.maxY - windowSize.height,
            width: width,
            height: windowSize.height
        )
    }

    private func ensureWindow() -> NotchExpandedWindow? {
        if let window { return window }
        guard let screen = targetScreen ?? NSScreen.main,
              let frames = notchAccessoryFrames(for: screen) else {
            return nil
        }
        // 畳んだ状態のサイズ＝実際のノッチサイズ。ここから広がる。
        model.collapsedSize = frames.notch.size
        let hosting = NSHostingView(rootView: NotchExpandedRoot(model: model))
        let window = NotchExpandedWindow(
            frame: windowFrame(screen: screen, frames: frames),
            hosting: hosting
        )
        self.window = window
        return window
    }
}

// MARK: - すぐ使えるウィジェット例

/// バッテリー残量ウィジェット。
struct NotchBatteryWidget: View {
    @ObservedObject var battery = BatteryMonitor.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: battery.isCharging ? "battery.100.bolt" : batterySymbol)
            Text("\(battery.batteryLevel)%")
                .monospacedDigit()
        }
    }

    private var batterySymbol: String {
        switch battery.batteryLevel {
        case ..<10:  return "battery.0"
        case ..<35:  return "battery.25"
        case ..<60:  return "battery.50"
        case ..<85:  return "battery.75"
        default:     return "battery.100"
        }
    }
}

/// 時計ウィジェット。1秒ごとに更新。
struct NotchClockWidget: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(now, format: .dateTime.hour().minute())
            .monospacedDigit()
            .onReceive(timer) { now = $0 }
    }
}
