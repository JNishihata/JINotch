//
//  SettingsWindowController.swift
//  JINotch
//
//  Created by Jintaro Nishihata on 2026/11/22.
//

import SwiftUI

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600), styleMask: [.titled, .closable, .miniaturizable, .resizable ,.fullSizeContentView], backing: .buffered, defer: false
            )
        
        super.init(window:window)
        
        setupWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "JINotch Settings"
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
        
        window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenAuxiliary]
        
        window.hidesOnDeactivate = false
        window.isExcludedFromWindowsMenu = false
        window.isRestorable = true
        window.identifier = NSUserInterfaceItemIdentifier("JINotchSettingsWindow")
        
        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        
        window.contentView = hostingView
        window.delegate = self
        
    }
    
    func showWindow() {
        NSApp.setActivationPolicy(.regular)
        
        if window?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            window?.orderFrontRegardless()
            window?.makeKeyAndOrderFront(nil)
            return
        }
        
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        window?.center()
        
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeKeyAndOrderFront(nil)
        }
    }
    
    override func close() {
        super.close()
        relinquishFocus()
    }
    
    private func relinquishFocus() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        relinquishFocus()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
    func windowDidResignKey(_ notification: Notification) {
    }
}
