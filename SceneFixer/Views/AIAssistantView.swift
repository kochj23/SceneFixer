//
//  AIAssistantView.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject var aiAssistant: AIAssistant
    @EnvironmentObject var homeKitManager: HomeKitManager

    @State private var userInput = ""
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            // Welcome message
                            if aiAssistant.conversationHistory.isEmpty {
                                WelcomeCard()
                            }

                            // Conversation
                            ForEach(aiAssistant.conversationHistory) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            // Processing indicator
                            if aiAssistant.isProcessing {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Thinking...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: aiAssistant.conversationHistory.count) { _, _ in
                        if let last = aiAssistant.conversationHistory.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Quick suggestions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SuggestionChip(text: "Which devices are offline?") {
                            sendQuery("Which devices are offline?")
                        }
                        SuggestionChip(text: "What scenes are broken?") {
                            sendQuery("What scenes are broken?")
                        }
                        SuggestionChip(text: "Manufacturer issues?") {
                            sendQuery("Which manufacturer has the most issues?")
                        }
                        SuggestionChip(text: "Fix Hue devices?") {
                            sendQuery("How do I fix my Hue devices?")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                #if !os(tvOS)
                // Input area (not available on tvOS - no keyboard)
                HStack(spacing: 12) {
                    TextField("Ask about your smart home...", text: $userInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            sendCurrentQuery()
                        }

                    Button {
                        sendCurrentQuery()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                    }
                    .disabled(userInput.isEmpty || aiAssistant.isProcessing)
                }
                .padding(16)
                .background(Color.platformBackground)
                #else
                // tvOS: Show message that text input is not available
                HStack {
                    Image(systemName: "keyboard")
                        .foregroundColor(.secondary)
                    Text("Use suggestion buttons above or control from iPhone/iPad")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.platformBackground)
                #endif
            }
            .navigationTitle("AI Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(aiAssistant.isBackendAvailable ? Color.green : Color.red)
                            .frame(width: 10, height: 10)

                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                AISettingsSheet()
                    .environmentObject(aiAssistant)
            }
            .onAppear {
                Task {
                    await aiAssistant.checkBackendAvailability()
                }
            }
        }
    }

    private func sendCurrentQuery() {
        guard !userInput.isEmpty else { return }
        let query = userInput
        userInput = ""
        sendQuery(query)
    }

    private func sendQuery(_ query: String) {
        Task {
            _ = await aiAssistant.processQuery(query)
        }
    }
}

// MARK: - Supporting Views

struct WelcomeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain")
                    .font(.system(size: 32))
                    .foregroundColor(.purple)
                VStack(alignment: .leading) {
                    Text("SceneFixer AI")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Your smart home diagnostic assistant")
                        .foregroundColor(.secondary)
                }
            }

            Text("I can help you with:")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "cpu", text: "Finding offline devices")
                FeatureRow(icon: "play.rectangle.on.rectangle", text: "Identifying broken scenes")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Analyzing failure patterns")
                FeatureRow(icon: "wrench.and.screwdriver", text: "Troubleshooting tips")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
        )
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14))
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                Image(systemName: "brain")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
                    .frame(width: 32, height: 32)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(16)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(message.role == .user ? Color.blue : Color.platformBackground)
                    )
                    .foregroundColor(message.role == .user ? .white : .primary)

                Text(formatTime(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.1))
                )
                .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
    }
}

struct AISettingsSheet: View {
    @EnvironmentObject var aiAssistant: AIAssistant
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend") {
                    Picker("AI Backend", selection: $aiAssistant.currentBackend) {
                        ForEach(AIBackend.allCases, id: \.self) { backend in
                            Label(backend.rawValue, systemImage: backend.icon)
                                .tag(backend)
                        }
                    }
                }

                Section("Ollama") {
                    TextField("Host", text: $aiAssistant.ollamaHost)
                    TextField("Model", text: $aiAssistant.ollamaModel)
                }

                Section("OpenWebUI") {
                    TextField("Host", text: $aiAssistant.openWebUIHost)
                }
            }
            .navigationTitle("AI Settings")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AIAssistantView()
        .environmentObject(AIAssistant.shared)
        .environmentObject(HomeKitManager.shared)
}
