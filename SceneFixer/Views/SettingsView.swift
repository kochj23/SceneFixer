//
//  SettingsView.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var aiAssistant: AIAssistant
    @EnvironmentObject var homeKitManager: HomeKitManager

    @State private var anthropicKey = ""
    @State private var openAIKey = ""

    var body: some View {
        NavigationStack {
            Form {
                // Home Info
                Section("HomeKit") {
                    if let home = homeKitManager.home {
                        HStack {
                            Text("Current Home")
                            Spacer()
                            Text(home.name)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Devices")
                            Spacer()
                            Text("\(homeKitManager.devices.count)")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Scenes")
                            Spacer()
                            Text("\(homeKitManager.scenes.count)")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("No HomeKit home connected")
                        }
                    }

                    Button {
                        homeKitManager.requestAuthorization()
                    } label: {
                        Label("Refresh HomeKit Access", systemImage: "arrow.clockwise")
                    }
                }

                // AI Backend
                Section("AI Backend") {
                    Picker("Backend", selection: $aiAssistant.currentBackend) {
                        ForEach(AIBackend.allCases, id: \.self) { backend in
                            Text(backend.rawValue).tag(backend)
                        }
                    }

                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(aiAssistant.isBackendAvailable ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(aiAssistant.isBackendAvailable ? "Connected" : "Disconnected")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        Task {
                            await aiAssistant.checkBackendAvailability()
                        }
                    } label: {
                        Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }

                // Ollama Settings
                Section("Ollama Settings") {
                    TextField("Host URL", text: $aiAssistant.ollamaHost)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    TextField("Model Name", text: $aiAssistant.ollamaModel)
                        .textInputAutocapitalization(.never)
                }

                // OpenWebUI
                Section("OpenWebUI Settings") {
                    TextField("Host URL", text: $aiAssistant.openWebUIHost)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                // Cloud API Keys
                Section("Cloud API Keys") {
                    SecureField("Anthropic API Key", text: $anthropicKey)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            if !anthropicKey.isEmpty {
                                UserDefaults.standard.set(anthropicKey, forKey: "AnthropicAPIKey")
                            }
                        }

                    SecureField("OpenAI API Key", text: $openAIKey)
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            if !openAIKey.isEmpty {
                                UserDefaults.standard.set(openAIKey, forKey: "OpenAIAPIKey")
                            }
                        }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Jordan Koch")
                            .foregroundColor(.secondary)
                    }
                }

                // Actions
                Section {
                    Button(role: .destructive) {
                        aiAssistant.clearConversation()
                    } label: {
                        Label("Clear AI Conversation", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AIAssistant.shared)
        .environmentObject(HomeKitManager.shared)
}
