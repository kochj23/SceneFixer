//
//  SceneFixerApp.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import SwiftUI

@main
struct SceneFixerApp: App {
    @StateObject private var homeKitManager = HomeKitManager.shared
    @StateObject private var deviceTester = DeviceTester.shared
    @StateObject private var sceneAnalyzer = SceneAnalyzer.shared
    @StateObject private var aiAssistant = AIAssistant.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(homeKitManager)
                .environmentObject(deviceTester)
                .environmentObject(sceneAnalyzer)
                .environmentObject(aiAssistant)
        }
    }
}
