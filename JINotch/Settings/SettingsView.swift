//
//  SettingsView.swift
//  JINotch
//
//  Created by Jintaro Nishihata on 2026/11/22.
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "General"
    
    var body : some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                NavigationLink(value :"General") {
                    Label("General", systemImage: "gear")
                }
                NavigationLink(value: "About") {
                    Label("About", systemImage: "info.circle")
                }
            }
            .listStyle(SidebarListStyle())
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selectedTab {
                case "General":
                    GeneralSettingsView()
                case "About":
                    AboutView()
                default:
                    GeneralSettingsView()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing:.sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section("General") {
                Text("Text")
            }
        }.toolbar {
            Button("Quit") {
                NSApp.terminate(self)
            }
            .controlSize(.extraLarge)
        }
        .navigationTitle("General")
        .formStyle(.grouped)
    }
}

struct AboutView: View {
    var body: some View {
        VStack {
            Form {
                Section("Version Infomation") {
                    HStack {
                        Text("Release name")
                        Spacer()
                        Text("Name")
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.0")
                    }
                }
            }
            .formStyle(.grouped)
        }.navigationTitle("About")
    }
}

#Preview {
    SettingsView()
}
