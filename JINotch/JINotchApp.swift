//
//  JINotchApp.swift
//  JINotch
//
//  Created by Jintaro Nishihata on 2026/07/26.
//

import SwiftUI
import Cocoa
import Combine

@main
struct JINotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var showMenuBarIcon: Bool = true

    var body: some Scene {
        MenuBarExtra("boring.notch", systemImage: "sparkle", isInserted: $showMenuBarIcon) {
            Button("Settings") {
                DispatchQueue.main.async {
                    SettingsWindowController.shared.showWindow()
                }
            }
            .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            Divider()
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(self)
            }
            .keyboardShortcut(KeyEquivalent("Q"), modifiers: .command)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    @ObservedObject var batteryModel = BatteryMonitor.shared
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var notchWindow: NotchHoverWindow?

    private var cancellable: AnyCancellable?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        batteryModel.updateBatteryInfo()
        // MARK: ノッチ判定用
        guard let screen = NSScreen.main,
              let notchFrame = getNotchFrame(for: screen) else {
            print("この画面にはノッチがありません")
            return
        }
        
        let window = NotchHoverWindow(frame: notchFrame)
        window.orderFrontRegardless()
        
        // MARK: パネルの中身を登録
        //   ・本体(ノッチ真下) = バッテリー詳細
        //   ・heading 左(ノッチ左脇) = 時計
        //   ・heading 右(ノッチ右脇) = 今は未使用(必要になれば setHeadingContent(.trailing) で追加)
        NotchAccessoryController.shared.configure(minWidth: 600, contentPadding: 24)
        NotchAccessoryController.shared.setBottomContent {
            NotchView()
        }
        NotchAccessoryController.shared.setHeadingContent(.trailing) {
            SettingsIcon()
        }

        if let hoverView = window.contentView as? NotchHoverView {
            hoverView.onHoverChanged = { hovering in
                // ホバー判定は controller が一本化(ノッチ→パネルへ移動しても閉じない)
                NotchAccessoryController.shared.setHovering(hovering)
            }
        }

        self.notchWindow = window
    }
    
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
