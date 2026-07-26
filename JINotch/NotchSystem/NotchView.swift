//
//  NotchView.swift
//  JINotch
//
//  Created by Jintaro Nishihata on 2026/07/26.
//

import SwiftUI
import Combine

struct NotchView: View {
    @ObservedObject var batteryModel = BatteryMonitor.shared
    @State private var isHoveringIcon = false
    
    var body: some View {
        VStack{
            HStack(alignment: .top, spacing: 20) {
                if !batteryModel.isloaded {
                    Text("Loading...")
                }
                CircularProgressBar(progress: CGFloat(batteryModel.batteryLevel))
                VStack{
                    BatteryInfoView(
                        isPluggedIn: batteryModel.powerConnected,
                        isCharging: batteryModel.isCharging,
                        levelBattery: batteryModel.batteryLevel,
                        timeToFullCharge: batteryModel.timeRemaining,
                        lowPowerMode: batteryModel.isLowPowerMode
                    )
                }
            }
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
    }
}

struct CircularProgressBar: View {
    var progress: CGFloat
    
    var body: some View {
        ZStack {
            // 背景の円
            Circle()
            // ボーダーラインを描画するように指定
                .stroke(lineWidth: 10.0)
                .opacity(0.3)
                .foregroundColor(.green)
            
            // 進捗を示す円
            Circle()
            // 始点/終点を指定して円を描画する
            // 始点/終点には0.0-1.0の範囲に正規化した値を指定する
                .trim(from: 0.0, to: progress * 0.01)
            // 線の端の形状などを指定
                .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                .foregroundColor(.green)
            // デフォルトの原点は時計の12時の位置ではないので回転させる
                .rotationEffect(Angle(degrees: 270.0))
            
            // 進捗率のテキスト
            Text(String(format: "%.0f%%", progress))
                .font(.title)
                .bold()
        }
    }
}

struct BatteryInfoView: View {
    
    var isPluggedIn: Bool
    var isCharging: Bool
    var levelBattery: Int
    var timeToFullCharge: Int
    var lowPowerMode: Bool
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack{
                    Label("Low Power Mode", systemImage: "bolt.circle")
                    Spacer()
                    Text(lowPowerMode ? "ON":"OFF")
                }.font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(lowPowerMode ? .yellow : .primary)
                HStack{
                    Label("Battery Charging: ", systemImage: isCharging ? "bolt.fill" : "bolt.slash.fill")
                    Spacer()
                    Text(isCharging ? "Charging" : "Not Charging")
                }.font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(isCharging ? .green : .primary)
                HStack{
                    Label("Power Plug: ", systemImage: "powerplug.fill")
                    Spacer()
                    Text(isPluggedIn ? "Plugged In" : "Not Plugged In")
                }.font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(isPluggedIn ? .green : .primary)
                
                if timeToFullCharge > 0 {
                    HStack{
                        Label(isCharging ? "Time to Full Charge: " :"Estimated Remining Time: ", systemImage: "clock")
                        Spacer()
                        Text("\(timeToFullCharge) min")
                    }.font(.subheadline)
                        .fontWeight(.regular)
                }
                if !isCharging && isPluggedIn && levelBattery >= 80 {
                    HStack{
                        Label("Charging on Hold: ", systemImage: "desktopcomputer")
                        Spacer()
                        Text("Desktop Mode")
                    }
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(.orange)
                }
                
            }
        }
        .frame(width: 280)
        .foregroundColor(.white)
    }
    
    private func openBatteryPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
            openURL(url)
        }
    }
}
