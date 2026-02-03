//
//  DashboardView.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var homeKitManager: HomeKitManager
    @EnvironmentObject var deviceTester: DeviceTester
    @EnvironmentObject var sceneAnalyzer: SceneAnalyzer

    // Sheet state
    @State private var selectedCardType: DashboardCardType?
    @State private var selectedDevice: DeviceInfo?
    @State private var selectedScene: SceneInfo?

    // Adaptive column count based on platform
    private var gridColumns: [GridItem] {
        #if os(tvOS)
        return [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        #else
        return [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        #endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with home name
                    if let home = homeKitManager.home {
                        Text(home.name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    // Progress indicator
                    if deviceTester.isTesting {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: deviceTester.testProgress)
                            Text("Testing: \(deviceTester.currentTestDevice)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    // Stats cards - ALL CLICKABLE
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        StatsCard(
                            title: "Total Devices",
                            value: "\(homeKitManager.devices.count)",
                            icon: "cpu",
                            color: .blue
                        )
                        .onTapGesture {
                            selectedCardType = .totalDevices
                        }

                        let healthy = homeKitManager.devices.filter { $0.healthStatus == .healthy }.count
                        StatsCard(
                            title: "Healthy",
                            value: "\(healthy)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                        .onTapGesture {
                            selectedCardType = .healthyDevices
                        }

                        let unreachable = homeKitManager.devices.filter { $0.healthStatus == .unreachable }.count
                        StatsCard(
                            title: "Unreachable",
                            value: "\(unreachable)",
                            icon: "xmark.circle.fill",
                            color: unreachable > 0 ? .red : .gray
                        )
                        .onTapGesture {
                            selectedCardType = .unreachableDevices
                        }

                        let brokenScenes = homeKitManager.scenes.filter { $0.healthStatus == .broken || $0.healthStatus == .degraded }.count
                        StatsCard(
                            title: "Broken Scenes",
                            value: "\(brokenScenes)",
                            icon: "exclamationmark.triangle.fill",
                            color: brokenScenes > 0 ? .orange : .gray
                        )
                        .onTapGesture {
                            selectedCardType = .brokenScenes
                        }
                    }
                    .padding(.horizontal)

                    // Additional summary cards
                    HStack(spacing: 12) {
                        MiniStatsCard(
                            title: "Rooms",
                            value: "\(Set(homeKitManager.devices.compactMap { $0.room }).count)",
                            icon: "house.fill",
                            color: .cyan
                        )
                        .onTapGesture {
                            selectedCardType = .roomSummary
                        }

                        MiniStatsCard(
                            title: "Scenes",
                            value: "\(homeKitManager.scenes.count)",
                            icon: "play.rectangle.on.rectangle",
                            color: .purple
                        )
                        .onTapGesture {
                            selectedCardType = .allScenes
                        }

                        MiniStatsCard(
                            title: "Brands",
                            value: "\(Set(homeKitManager.devices.map { $0.manufacturer }).count)",
                            icon: "building.2.fill",
                            color: .indigo
                        )
                        .onTapGesture {
                            selectedCardType = .manufacturerSummary
                        }
                    }
                    .padding(.horizontal)

                    // Quick actions
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ActionButton(
                                title: "Health Check",
                                icon: "heart.text.square",
                                color: .blue
                            ) {
                                Task {
                                    await deviceTester.runFullHealthCheck()
                                }
                            }
                            .disabled(deviceTester.isTesting)

                            ActionButton(
                                title: "Audit Scenes",
                                icon: "play.rectangle.on.rectangle",
                                color: .purple
                            ) {
                                Task {
                                    await sceneAnalyzer.auditAllScenes()
                                }
                            }
                            .disabled(sceneAnalyzer.isAnalyzing)
                        }

                        HStack(spacing: 12) {
                            ActionButton(
                                title: "Toggle Test",
                                icon: "power",
                                color: .orange
                            ) {
                                Task {
                                    _ = await deviceTester.testAllDevicesToggle()
                                }
                            }
                            .disabled(deviceTester.isTesting)

                            ActionButton(
                                title: "Refresh",
                                icon: "arrow.clockwise",
                                color: .green
                            ) {
                                Task {
                                    await homeKitManager.refreshAll()
                                }
                            }
                            .disabled(homeKitManager.isLoading)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Devices needing attention
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Devices Needing Attention")
                                .font(.headline)
                            Spacer()
                            if !problemDevices.isEmpty {
                                Button("View All") {
                                    selectedCardType = .unreachableDevices
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.horizontal)

                        if problemDevices.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("All devices are healthy!")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        } else {
                            ForEach(problemDevices.prefix(5)) { device in
                                DeviceStatusRow(device: device)
                                    .onTapGesture {
                                        selectedDevice = device
                                    }
                                    .padding(.horizontal)
                            }

                            if problemDevices.count > 5 {
                                Button {
                                    selectedCardType = .unreachableDevices
                                } label: {
                                    Text("+ \(problemDevices.count - 5) more...")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Scenes with issues
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Scenes with Issues")
                                .font(.headline)
                            Spacer()
                            if !problemScenes.isEmpty {
                                Button("View All") {
                                    selectedCardType = .brokenScenes
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.horizontal)

                        if problemScenes.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("All scenes are healthy!")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        } else {
                            ForEach(problemScenes.prefix(5)) { scene in
                                SceneStatusRow(scene: scene)
                                    .onTapGesture {
                                        selectedScene = scene
                                    }
                                    .padding(.horizontal)
                            }

                            if problemScenes.count > 5 {
                                Button {
                                    selectedCardType = .brokenScenes
                                } label: {
                                    Text("+ \(problemScenes.count - 5) more...")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            #if !os(tvOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if homeKitManager.isLoading || deviceTester.isTesting || sceneAnalyzer.isAnalyzing {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                await homeKitManager.refreshAll()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            #endif
        }
        // Sheet modals
        .sheet(item: $selectedCardType) { cardType in
            CardDetailView(cardType: cardType)
                .environmentObject(homeKitManager)
                .environmentObject(deviceTester)
                .environmentObject(sceneAnalyzer)
        }
        .sheet(item: $selectedDevice) { device in
            DeviceDetailSheet(device: device)
                .environmentObject(homeKitManager)
                .environmentObject(deviceTester)
        }
        .sheet(item: $selectedScene) { scene in
            SceneDetailSheet(scene: scene)
                .environmentObject(homeKitManager)
                .environmentObject(sceneAnalyzer)
        }
    }

    // MARK: - Computed Properties

    private var problemDevices: [DeviceInfo] {
        homeKitManager.devices.filter {
            $0.healthStatus == .unreachable || $0.healthStatus == .degraded
        }
    }

    private var problemScenes: [SceneInfo] {
        homeKitManager.scenes.filter {
            $0.healthStatus == .broken || $0.healthStatus == .degraded
        }
    }
}

// MARK: - Supporting Views

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold))

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle()) // Makes entire card tappable
    }
}

struct MiniStatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
            )
            .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}

struct DeviceStatusRow: View {
    let device: DeviceInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.category.icon)
                .font(.system(size: 18))
                .foregroundColor(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 14, weight: .medium))
                Text("\(device.room ?? "No Room") - \(device.manufacturer.rawValue)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(device.healthStatus.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .cornerRadius(4)

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.platformBackground)
        )
        .contentShape(Rectangle())
    }

    var statusColor: Color {
        switch device.healthStatus {
        case .healthy: return .green
        case .degraded: return .yellow
        case .unreachable: return .red
        case .unknown: return .gray
        case .testing: return .blue
        }
    }
}

struct SceneStatusRow: View {
    let scene: SceneInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 18))
                .foregroundColor(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(scene.name)
                    .font(.system(size: 14, weight: .medium))
                Text("\(scene.reachableDevices)/\(scene.totalDevices) devices working")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(scene.healthStatus.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .cornerRadius(4)

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.platformBackground)
        )
        .contentShape(Rectangle())
    }

    var statusColor: Color {
        switch scene.healthStatus {
        case .healthy: return .green
        case .degraded: return .yellow
        case .broken: return .red
        case .unknown: return .gray
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(HomeKitManager.shared)
        .environmentObject(DeviceTester.shared)
        .environmentObject(SceneAnalyzer.shared)
}
