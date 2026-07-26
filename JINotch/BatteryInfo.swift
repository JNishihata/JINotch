//
//  BatteryInfo.swift
//  JINotch
//
//  Created by Jintaro Nishihata on 2026/07/26.
//

import IOKit.ps
import Foundation
import Combine

final class BatteryMonitor: ObservableObject {
    static let shared = BatteryMonitor()
    
    init() {
        startMonitoring()
    }
    
    @Published var batteryLevel: Int = 0
    @Published var isCharging: Bool = false
    @Published var isCharged: Bool = false
    @Published var isLowPowerModeEnabled: Bool = false
    @Published var powerSourceState : String = ""
    @Published var timeRemaining: Int = -1
    @Published var isloaded: Bool = false
    
    private var runLoopSource: CFRunLoopSource?
    
    private func updateBatteryInfo() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            if let current = description[kIOPSCurrentCapacityKey] as? Int,
               let max = description[kIOPSMaxCapacityKey] as? Int {
                batteryLevel = Int(Double(current) / Double(max) * 100)
            }
            isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            isCharged = description[kIOPSIsChargedKey] as? Bool ?? false
            powerSourceState = description[kIOPSPowerSourceStateKey] as? String ?? ""
            timeRemaining = description[kIOPSTimeToEmptyKey] as? Int ?? -1
            if batteryLevel != 0 {
                isloaded = true
            }
        }
    }
    
    private func startMonitoring() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context = context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.updateBatteryInfo()
            }
        }
        
        if let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }
    
    private func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
    }
}

