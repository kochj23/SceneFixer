//
//  AIAssistant.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import Foundation
import Combine

/// AI-powered assistant for natural language queries and pattern analysis
@MainActor
class AIAssistant: ObservableObject {
    static let shared = AIAssistant()

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var currentBackend: AIBackend = .ollama
    @Published var isBackendAvailable = false
    @Published var lastResponse: String = ""
    @Published var conversationHistory: [ChatMessage] = []
    @Published var analysisInsights: [AIInsight] = []

    // MARK: - Configuration

    @Published var ollamaHost = "http://localhost:11434"
    @Published var ollamaModel = "llama3.2"
    @Published var openWebUIHost = "http://localhost:3000"
    @Published var useCloudBackup = false

    // MARK: - Private Properties

    private var homeKitManager: HomeKitManager { HomeKitManager.shared }
    private var sceneAnalyzer: SceneAnalyzer { SceneAnalyzer.shared }
    private let systemPrompt: String

    // MARK: - Initialization

    private init() {
        self.systemPrompt = """
        You are SceneFixer AI, an expert HomeKit assistant that helps users diagnose and fix issues with their smart home devices and scenes.

        You have access to the following information about the user's HomeKit setup:
        - List of all devices with their health status, manufacturer, room, and reliability scores
        - List of all scenes with their device membership and health status
        - Device test results and historical reliability data
        - Hub/bridge information (Hue, Lutron, etc.)

        Your capabilities:
        1. Answer questions about device and scene status
        2. Identify patterns in device failures
        3. Suggest troubleshooting steps
        4. Recommend devices that may need replacement
        5. Explain which devices are causing scene failures
        6. Provide manufacturer-specific advice

        Always be concise, helpful, and provide actionable recommendations.
        When discussing specific devices or scenes, mention them by name.
        If you identify a pattern, explain it clearly and suggest fixes.
        """

        Task {
            await checkBackendAvailability()
        }
    }

    // MARK: - Backend Management

    func checkBackendAvailability() async {
        switch currentBackend {
        case .ollama:
            isBackendAvailable = await checkOllamaAvailability()
        case .openWebUI:
            isBackendAvailable = await checkOpenWebUIAvailability()
        case .mlx:
            isBackendAvailable = await checkMLXAvailability()
        case .claude, .gpt4:
            isBackendAvailable = hasCloudAPIKey()
        }
    }

    private func checkOllamaAvailability() async -> Bool {
        guard let url = URL(string: "\(ollamaHost)/api/tags") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            NSLog("[AIAssistant] Ollama not available: %@", error.localizedDescription)
        }
        return false
    }

    private func checkOpenWebUIAvailability() async -> Bool {
        guard let url = URL(string: "\(openWebUIHost)/api/models") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            NSLog("[AIAssistant] OpenWebUI not available: %@", error.localizedDescription)
        }
        return false
    }

    private func checkMLXAvailability() async -> Bool {
        // MLX is always available on Apple Silicon
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    private func hasCloudAPIKey() -> Bool {
        switch currentBackend {
        case .claude:
            return UserDefaults.standard.string(forKey: "AnthropicAPIKey") != nil
        case .gpt4:
            return UserDefaults.standard.string(forKey: "OpenAIAPIKey") != nil
        default:
            return false
        }
    }

    // MARK: - Natural Language Queries

    func processQuery(_ query: String) async -> String {
        isProcessing = true
        defer { isProcessing = false }

        // Add user message to history
        let userMessage = ChatMessage(role: .user, content: query)
        conversationHistory.append(userMessage)

        // Build context with current HomeKit state
        let context = buildHomeKitContext()

        // Build the full prompt
        let fullPrompt = """
        \(systemPrompt)

        Current HomeKit Status:
        \(context)

        User Query: \(query)
        """

        // Send to AI backend
        let response: String
        switch currentBackend {
        case .ollama:
            response = await queryOllama(fullPrompt)
        case .openWebUI:
            response = await queryOpenWebUI(fullPrompt)
        case .mlx:
            response = await queryMLX(fullPrompt)
        case .claude:
            response = await queryClaude(fullPrompt)
        case .gpt4:
            response = await queryGPT4(fullPrompt)
        }

        // Add assistant response to history
        let assistantMessage = ChatMessage(role: .assistant, content: response)
        conversationHistory.append(assistantMessage)

        lastResponse = response
        return response
    }

    // MARK: - Ollama Integration

    private func queryOllama(_ prompt: String) async -> String {
        guard let url = URL(string: "\(ollamaHost)/api/generate") else {
            return "Error: Invalid Ollama URL"
        }

        let requestBody: [String: Any] = [
            "model": ollamaModel,
            "prompt": prompt,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? String {
                return response
            }
        } catch {
            NSLog("[AIAssistant] Ollama error: %@", error.localizedDescription)
        }

        return "Error: Failed to get response from Ollama"
    }

    // MARK: - OpenWebUI Integration

    private func queryOpenWebUI(_ prompt: String) async -> String {
        guard let url = URL(string: "\(openWebUIHost)/api/chat/completions") else {
            return "Error: Invalid OpenWebUI URL"
        }

        let requestBody: [String: Any] = [
            "model": ollamaModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        } catch {
            NSLog("[AIAssistant] OpenWebUI error: %@", error.localizedDescription)
        }

        return "Error: Failed to get response from OpenWebUI"
    }

    // MARK: - MLX Integration

    private func queryMLX(_ prompt: String) async -> String {
        // MLX local inference placeholder
        // In production, this would use MLX Swift bindings
        return "MLX inference not yet implemented. Please use Ollama or cloud backends."
    }

    // MARK: - Cloud API Integration

    private func queryClaude(_ prompt: String) async -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "AnthropicAPIKey") else {
            return "Error: Anthropic API key not configured"
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            return "Error: Invalid API URL"
        }

        let requestBody: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                return text
            }
        } catch {
            NSLog("[AIAssistant] Claude error: %@", error.localizedDescription)
        }

        return "Error: Failed to get response from Claude"
    }

    private func queryGPT4(_ prompt: String) async -> String {
        guard let apiKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey") else {
            return "Error: OpenAI API key not configured"
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return "Error: Invalid API URL"
        }

        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 2048
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        } catch {
            NSLog("[AIAssistant] GPT-4 error: %@", error.localizedDescription)
        }

        return "Error: Failed to get response from GPT-4"
    }

    // MARK: - Context Building

    private func buildHomeKitContext() -> String {
        let devices = homeKitManager.devices
        let scenes = homeKitManager.scenes

        var context = """
        DEVICES (\(devices.count) total):
        """

        // Group devices by status
        let healthy = devices.filter { $0.healthStatus == .healthy }
        let degraded = devices.filter { $0.healthStatus == .degraded }
        let unreachable = devices.filter { $0.healthStatus == .unreachable }

        context += "\n- Healthy: \(healthy.count)"
        context += "\n- Degraded: \(degraded.count)"
        context += "\n- Unreachable: \(unreachable.count)"

        // List unreachable devices
        if !unreachable.isEmpty {
            context += "\n\nUnreachable devices:"
            for device in unreachable {
                context += "\n  - \(device.name) (\(device.manufacturer.rawValue), \(device.room ?? "No Room"))"
            }
        }

        // List degraded devices
        if !degraded.isEmpty {
            context += "\n\nDegraded devices (reliability < 90%):"
            for device in degraded {
                context += "\n  - \(device.name): \(String(format: "%.1f", device.reliabilityScore))% reliability"
            }
        }

        // Scenes summary
        context += "\n\nSCENES (\(scenes.count) total):"
        let brokenScenes = scenes.filter { $0.healthStatus == .broken }
        let degradedScenes = scenes.filter { $0.healthStatus == .degraded }

        context += "\n- Healthy: \(scenes.count - brokenScenes.count - degradedScenes.count)"
        context += "\n- Degraded: \(degradedScenes.count)"
        context += "\n- Broken: \(brokenScenes.count)"

        // List broken scenes
        if !brokenScenes.isEmpty {
            context += "\n\nBroken scenes:"
            for scene in brokenScenes {
                context += "\n  - \(scene.name): Missing \(scene.unreachableDeviceNames.joined(separator: ", "))"
            }
        }

        // Manufacturer breakdown
        let manufacturers = homeKitManager.getManufacturerSummaries()
        context += "\n\nDEVICES BY MANUFACTURER:"
        for mfg in manufacturers.prefix(5) {
            context += "\n  - \(mfg.manufacturer.rawValue): \(mfg.deviceCount) devices, \(String(format: "%.1f", mfg.averageReliability))% avg reliability"
        }

        return context
    }

    // MARK: - Pattern Analysis

    func analyzePatterns() async -> [AIInsight] {
        isProcessing = true
        defer { isProcessing = false }

        var insights: [AIInsight] = []

        // Analyze manufacturer reliability
        let manufacturers = homeKitManager.getManufacturerSummaries()
        for mfg in manufacturers where mfg.unreachableCount > 0 {
            // Get device names for this manufacturer
            let deviceNames = homeKitManager.devices
                .filter { $0.manufacturer == mfg.manufacturer && $0.healthStatus == .unreachable }
                .map { $0.name }

            let insight = AIInsight(
                id: UUID(),
                type: .manufacturerIssue,
                title: "\(mfg.manufacturer.rawValue) Devices Having Issues",
                description: "\(mfg.unreachableCount) of \(mfg.deviceCount) \(mfg.manufacturer.rawValue) devices are unreachable.",
                severity: mfg.unreachableCount > mfg.deviceCount / 2 ? .high : .medium,
                affectedDevices: deviceNames,
                recommendation: getManufacturerRecommendation(mfg.manufacturer)
            )
            insights.append(insight)
        }

        // Analyze room-based issues
        let rooms = homeKitManager.getRoomSummaries()
        for room in rooms where room.unreachableDevices > room.totalDevices / 3 {
            let insight = AIInsight(
                id: UUID(),
                type: .roomIssue,
                title: "Multiple Issues in \(room.name)",
                description: "\(room.unreachableDevices) of \(room.totalDevices) devices in \(room.name) are unreachable. This may indicate a WiFi or hub issue in that area.",
                severity: .medium,
                affectedDevices: [],
                recommendation: "Check WiFi coverage and any hubs located in or near \(room.name)."
            )
            insights.append(insight)
        }

        // Analyze scene health
        let brokenScenes = homeKitManager.scenes.filter { $0.healthStatus == .broken }
        if !brokenScenes.isEmpty {
            let insight = AIInsight(
                id: UUID(),
                type: .sceneIssue,
                title: "\(brokenScenes.count) Scenes Are Broken",
                description: "These scenes have no working devices: \(brokenScenes.map { $0.name }.joined(separator: ", "))",
                severity: .high,
                affectedDevices: [],
                recommendation: "Remove unreachable devices from these scenes or restore connectivity."
            )
            insights.append(insight)
        }

        analysisInsights = insights
        return insights
    }

    private func getManufacturerRecommendation(_ manufacturer: DeviceManufacturer) -> String {
        switch manufacturer {
        case .philipsHue:
            return "Check your Hue Bridge connection. Try power cycling the bridge and ensure it's connected to your router via Ethernet."
        case .lutron:
            return "Verify your Lutron Smart Bridge is online. Check the Lutron app for connectivity status."
        case .ikea:
            return "Check your IKEA TRADFRI Gateway. Ensure it's powered and connected to your network."
        case .aqara:
            return "Check your Aqara Hub connectivity. These devices may need to be re-paired if the hub was reset."
        case .eve:
            return "Eve devices use Thread/Bluetooth. Ensure you have a Thread border router (HomePod mini or Apple TV 4K) nearby."
        case .nanoleaf:
            return "Check WiFi connectivity for your Nanoleaf devices. They may need to reconnect if your WiFi password changed."
        default:
            return "Check the device's power supply and network connectivity. Try removing and re-adding the device to HomeKit."
        }
    }

    // MARK: - Conversation Management

    func clearConversation() {
        conversationHistory = []
    }
}

// MARK: - Supporting Types

enum AIBackend: String, CaseIterable, Codable {
    case ollama = "Ollama"
    case openWebUI = "OpenWebUI"
    case mlx = "MLX (Local)"
    case claude = "Claude"
    case gpt4 = "GPT-4"

    var icon: String {
        switch self {
        case .ollama: return "server.rack"
        case .openWebUI: return "globe"
        case .mlx: return "apple.logo"
        case .claude: return "brain"
        case .gpt4: return "sparkles"
        }
    }
}

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
}

struct AIInsight: Identifiable {
    let id: UUID
    let type: InsightType
    let title: String
    let description: String
    let severity: InsightSeverity
    let affectedDevices: [String]
    let recommendation: String

    enum InsightType {
        case manufacturerIssue
        case roomIssue
        case sceneIssue
        case reliabilityTrend
        case networkIssue
    }

    enum InsightSeverity: String {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var color: String {
            switch self {
            case .low: return "yellow"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
    }
}
