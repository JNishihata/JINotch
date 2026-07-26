//
//  NotchHoverWindow.swift
//  JINotch
//
//  Created by Jintaro Nishihata on 2026/07/26.
//

import Cocoa

class NotchHoverWindow: NSWindow {
    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.level = .statusBar // メニューバーより手前に表示
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false // ホバー検知のためfalseにする
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let hoverView = NotchHoverView(frame: NSRect(origin: .zero, size: frame.size))
        self.contentView = hoverView
    }
}

class NotchHoverView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }
}

func getNotchFrame(for screen: NSScreen) -> CGRect? {
    guard screen.safeAreaInsets.top > 0 else {
        // ノッチがない画面(外部ディスプレイなど)
        return nil
    }
    
    // ノッチの左右の境界を取得
    guard let leftArea = screen.auxiliaryTopLeftArea,
          let rightArea = screen.auxiliaryTopRightArea else {
        return nil
    }
    
    let notchWidth = screen.frame.width - leftArea.width - rightArea.width
    let notchHeight = screen.safeAreaInsets.top
    
    let notchFrame = CGRect(
        x: leftArea.maxX,
        y: screen.frame.maxY - notchHeight,
        width: notchWidth,
        height: notchHeight
    )
    
    return notchFrame
}
