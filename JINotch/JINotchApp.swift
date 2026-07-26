//
//  JINotchApp.swift
//  JINotch
//
//  Created by Jintaro Nishihata on 2026/07/26.
//

import SwiftUI
import DynamicNotchKit
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
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var notchWindow: NotchHoverWindow?
    let notch = DynamicNotch{NotchView()}

    private var cancellable: AnyCancellable?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // MARK: ノッチ判定用
        guard let screen = NSScreen.main,
              let notchFrame = getNotchFrame(for: screen) else {
            print("この画面にはノッチがありません")
            return
        }
        
        let window = NotchHoverWindow(frame: notchFrame)
        window.orderFrontRegardless()
        
        if let hoverView = window.contentView as? NotchHoverView {
            hoverView.onHoverChanged = { hovering in
                if hovering {
                    Task{
                        await self.notch.expand()
                    }
                    // ここでポップオーバーを開く、拡張UIを表示するなど
                } else {
                    Task{
                        await self.notch.hide()
                    }
                }
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
