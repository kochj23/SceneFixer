//
//  ContentView.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var homeKitManager: HomeKitManager
    @EnvironmentObject var deviceTester: DeviceTester
    @EnvironmentObject var sceneAnalyzer: SceneAnalyzer
    @EnvironmentObject var aiAssistant: AIAssistant

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }

            AIAssistantView()
                .tabItem {
                    Label("AI Assistant", systemImage: "brain")
                }

            DeviceListView()
                .tabItem {
                    Label("Devices", systemImage: "cpu")
                }

            SceneListView()
                .tabItem {
                    Label("Scenes", systemImage: "play.rectangle.on.rectangle")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            homeKitManager.requestAuthorization()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(HomeKitManager.shared)
        .environmentObject(DeviceTester.shared)
        .environmentObject(SceneAnalyzer.shared)
        .environmentObject(AIAssistant.shared)
}
