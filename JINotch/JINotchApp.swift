//
//  JINotchApp.swift
//  JINotch
//
//  Created by Jintaro Nishihata on 2026/11/21.
//

import SwiftUI

@main
struct JINotchApp: App {
    @State var showMenuBarIcon = true
    
    init() {
        
    }
    
    var body: some Scene {
        MenuBarExtra("JINotch", systemImage: "sparkle", isInserted: $showMenuBarIcon) {
            Button("Settings") {
                DispatchQueue.main.async {
                    SettingsWindowController.shared.showWindow()
                }
            }
            .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(self)
            }
            .keyboardShortcut(KeyEquivalent("Q"), modifiers: .command)
        }
    }
}
