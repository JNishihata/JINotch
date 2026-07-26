//
//  NotchHeading.swift
//  JINotch
//
//  Created by Jintaro Nishihata on 2026/07/26.
//

import SwiftUI

struct NotchHeading: View{
    var body: some View {
        HStack{
            
            Spacer()
            Button("Settings"){
                DispatchQueue.main.async {
                    SettingsWindowController.shared.showWindow()
                }
            }
        }
    }
}
