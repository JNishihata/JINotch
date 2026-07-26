//
//  SettingIcon.swift
//  JINotch
//
//  Created by Jintaro Nishihata on 2026/07/26.
//

import SwiftUI

struct SettingsIcon: View{
    var body: some View {
        HStack{
            
            Spacer()
            Image(systemName:"gear")
                .onTapGesture {
                    DispatchQueue.main.async {
                        SettingsWindowController.shared.showWindow()
                    }
                }                
//            Button("Settings"){
//                DispatchQueue.main.async {
//                    SettingsWindowController.shared.showWindow()
//                }
//            }
        }
    }
}
