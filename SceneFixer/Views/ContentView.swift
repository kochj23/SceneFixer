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

    #if os(tvOS)
    @State private var selectedTab: NavigationTab = .dashboard
    #endif

    var body: some View {
        #if os(tvOS)
        // tvOS: Use TabView for simpler navigation with Siri Remote
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
                .tag(NavigationTab.dashboard)

            DeviceListView()
                .tabItem {
                    Label("Devices", systemImage: "cpu")
                }
                .tag(NavigationTab.devices)

            SceneListView()
                .tabItem {
                    Label("Scenes", systemImage: "play.rectangle.on.rectangle")
                }
                .tag(NavigationTab.scenes)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(NavigationTab.settings)
        }
        .onAppear {
            homeKitManager.requestAuthorization()
        }
        #else
        // iOS/iPadOS: Use TabView
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
        #endif
    }
}

// MARK: - Navigation Tab Enum (for tvOS)

enum NavigationTab: String, CaseIterable {
    case dashboard
    case devices
    case scenes
    case settings
    // Note: AI Assistant excluded on tvOS due to text input limitations

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .devices: return "Devices"
        case .scenes: return "Scenes"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .devices: return "cpu"
        case .scenes: return "play.rectangle.on.rectangle"
        case .settings: return "gear"
        }
    }

    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .dashboard: DashboardView()
        case .devices: DeviceListView()
        case .scenes: SceneListView()
        case .settings: SettingsView()
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
