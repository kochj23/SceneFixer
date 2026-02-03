//
//  CardDetailView.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/3/26.
//

import SwiftUI

// MARK: - Card Type Enum

enum DashboardCardType: String, Identifiable, CaseIterable {
    case totalDevices = "Total Devices"
    case healthyDevices = "Healthy Devices"
    case unreachableDevices = "Unreachable Devices"
    case brokenScenes = "Broken Scenes"
    case allScenes = "All Scenes"
    case roomSummary = "Rooms"
    case manufacturerSummary = "Manufacturers"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .totalDevices: return "cpu"
        case .healthyDevices: return "checkmark.circle.fill"
        case .unreachableDevices: return "xmark.circle.fill"
        case .brokenScenes: return "exclamationmark.triangle.fill"
        case .allScenes: return "play.rectangle.on.rectangle"
        case .roomSummary: return "house.fill"
        case .manufacturerSummary: return "building.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .totalDevices: return .blue
        case .healthyDevices: return .green
        case .unreachableDevices: return .red
        case .brokenScenes: return .orange
        case .allScenes: return .purple
        case .roomSummary: return .cyan
        case .manufacturerSummary: return .indigo
        }
    }
}

// MARK: - Card Detail View

struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var homeKitManager: HomeKitManager
    @EnvironmentObject var deviceTester: DeviceTester
    @EnvironmentObject var sceneAnalyzer: SceneAnalyzer

    let cardType: DashboardCardType

    @State private var selectedDevice: DeviceInfo?
    @State private var selectedScene: SceneInfo?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header stats
                    headerSection

                    Divider()
                        .padding(.horizontal)

                    // Content based on card type
                    contentSection
                }
                .padding(.vertical)
            }
            .navigationTitle(cardType.rawValue)
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            #endif
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

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: cardType.icon)
                .font(.system(size: 40))
                .foregroundColor(cardType.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(headerValue)
                    .font(.system(size: 36, weight: .bold))
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(cardType.color.opacity(0.1))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var headerValue: String {
        switch cardType {
        case .totalDevices:
            return "\(homeKitManager.devices.count)"
        case .healthyDevices:
            return "\(homeKitManager.devices.filter { $0.healthStatus == .healthy }.count)"
        case .unreachableDevices:
            return "\(homeKitManager.devices.filter { $0.healthStatus == .unreachable }.count)"
        case .brokenScenes:
            return "\(homeKitManager.scenes.filter { $0.healthStatus == .broken || $0.healthStatus == .degraded }.count)"
        case .allScenes:
            return "\(homeKitManager.scenes.count)"
        case .roomSummary:
            return "\(Set(homeKitManager.devices.compactMap { $0.room }).count)"
        case .manufacturerSummary:
            return "\(Set(homeKitManager.devices.map { $0.manufacturer }).count)"
        }
    }

    private var headerSubtitle: String {
        switch cardType {
        case .totalDevices:
            return "devices in your home"
        case .healthyDevices:
            return "devices responding normally"
        case .unreachableDevices:
            return "devices need attention"
        case .brokenScenes:
            return "scenes with issues"
        case .allScenes:
            return "total scenes"
        case .roomSummary:
            return "rooms configured"
        case .manufacturerSummary:
            return "different brands"
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        switch cardType {
        case .totalDevices:
            deviceList(filter: nil)
        case .healthyDevices:
            deviceList(filter: .healthy)
        case .unreachableDevices:
            deviceList(filter: .unreachable)
        case .brokenScenes:
            sceneList(filterBroken: true)
        case .allScenes:
            sceneList(filterBroken: false)
        case .roomSummary:
            roomSummaryList
        case .manufacturerSummary:
            manufacturerSummaryList
        }
    }

    // MARK: - Device List

    @ViewBuilder
    private func deviceList(filter: DeviceHealthStatus?) -> some View {
        let devices = filter == nil
            ? homeKitManager.devices
            : homeKitManager.devices.filter { $0.healthStatus == filter }

        if devices.isEmpty {
            emptyState(message: "No devices found")
        } else {
            LazyVStack(spacing: 8) {
                ForEach(devices) { device in
                    DeviceRowCard(device: device)
                        .onTapGesture {
                            selectedDevice = device
                        }
                        .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Scene List

    @ViewBuilder
    private func sceneList(filterBroken: Bool) -> some View {
        let scenes = filterBroken
            ? homeKitManager.scenes.filter { $0.healthStatus == .broken || $0.healthStatus == .degraded }
            : homeKitManager.scenes

        if scenes.isEmpty {
            emptyState(message: filterBroken ? "All scenes are healthy!" : "No scenes found")
        } else {
            LazyVStack(spacing: 8) {
                ForEach(scenes) { scene in
                    SceneRowCard(scene: scene)
                        .onTapGesture {
                            selectedScene = scene
                        }
                        .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Room Summary List

    @ViewBuilder
    private var roomSummaryList: some View {
        let roomGroups = Dictionary(grouping: homeKitManager.devices) { $0.room ?? "No Room" }
        let sortedRooms = roomGroups.keys.sorted()

        if sortedRooms.isEmpty {
            emptyState(message: "No rooms found")
        } else {
            LazyVStack(spacing: 8) {
                ForEach(sortedRooms, id: \.self) { roomName in
                    let devices = roomGroups[roomName] ?? []
                    RoomSummaryCard(
                        roomName: roomName,
                        devices: devices
                    )
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Manufacturer Summary List

    @ViewBuilder
    private var manufacturerSummaryList: some View {
        let mfgGroups = Dictionary(grouping: homeKitManager.devices) { $0.manufacturer }
        let sortedMfgs = mfgGroups.keys.sorted { $0.rawValue < $1.rawValue }

        if sortedMfgs.isEmpty {
            emptyState(message: "No manufacturers found")
        } else {
            LazyVStack(spacing: 8) {
                ForEach(sortedMfgs, id: \.self) { manufacturer in
                    let devices = mfgGroups[manufacturer] ?? []
                    ManufacturerSummaryCard(
                        manufacturer: manufacturer,
                        devices: devices
                    )
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Device Row Card

struct DeviceRowCard: View {
    let device: DeviceInfo

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: device.category.icon)
                .font(.system(size: 22))
                .foregroundColor(statusColor)
                .frame(width: 36, height: 36)
                .background(statusColor.opacity(0.15))
                .cornerRadius(8)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.system(size: 15, weight: .semibold))
                HStack(spacing: 6) {
                    if let room = device.room {
                        Text(room)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(device.manufacturer.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Status badge
            Text(device.healthStatus.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.15))
                .cornerRadius(6)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.platformBackground)
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch device.healthStatus {
        case .healthy: return .green
        case .degraded: return .yellow
        case .unreachable: return .red
        case .unknown: return .gray
        case .testing: return .blue
        }
    }
}

// MARK: - Scene Row Card

struct SceneRowCard: View {
    let scene: SceneInfo

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 22))
                .foregroundColor(statusColor)
                .frame(width: 36, height: 36)
                .background(statusColor.opacity(0.15))
                .cornerRadius(8)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(scene.name)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(scene.reachableDevices)/\(scene.totalDevices) devices working")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Health bar mini
            HealthBarMini(percentage: scene.healthPercentage, color: statusColor)

            // Status badge
            Text(scene.healthStatus.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.15))
                .cornerRadius(6)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.platformBackground)
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch scene.healthStatus {
        case .healthy: return .green
        case .degraded: return .yellow
        case .broken: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Health Bar Mini

struct HealthBarMini: View {
    let percentage: Double
    let color: Color

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 40, height: 6)
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 40 * (percentage / 100), height: 6)
        }
    }
}

// MARK: - Room Summary Card

struct RoomSummaryCard: View {
    let roomName: String
    let devices: [DeviceInfo]

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "door.left.hand.closed")
                .font(.system(size: 22))
                .foregroundColor(.cyan)
                .frame(width: 36, height: 36)
                .background(Color.cyan.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 3) {
                Text(roomName)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(devices.count) devices")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Health breakdown
            HStack(spacing: 8) {
                let healthy = devices.filter { $0.healthStatus == .healthy }.count
                let unhealthy = devices.count - healthy

                if healthy > 0 {
                    HStack(spacing: 3) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("\(healthy)").font(.system(size: 12, weight: .medium))
                    }
                }
                if unhealthy > 0 {
                    HStack(spacing: 3) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("\(unhealthy)").font(.system(size: 12, weight: .medium))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.platformBackground)
        .cornerRadius(12)
    }
}

// MARK: - Manufacturer Summary Card

struct ManufacturerSummaryCard: View {
    let manufacturer: DeviceManufacturer
    let devices: [DeviceInfo]

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: manufacturer.icon)
                .font(.system(size: 22))
                .foregroundColor(.indigo)
                .frame(width: 36, height: 36)
                .background(Color.indigo.opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 3) {
                Text(manufacturer.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(devices.count) devices")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Reliability score
            let avgReliability = devices.map { $0.reliabilityScore }.reduce(0, +) / Double(max(devices.count, 1))
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f%%", avgReliability))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(avgReliability > 90 ? .green : avgReliability > 70 ? .yellow : .red)
                Text("reliability")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Health breakdown
            HStack(spacing: 8) {
                let healthy = devices.filter { $0.healthStatus == .healthy }.count
                let unhealthy = devices.count - healthy

                if healthy > 0 {
                    HStack(spacing: 3) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("\(healthy)").font(.system(size: 12, weight: .medium))
                    }
                }
                if unhealthy > 0 {
                    HStack(spacing: 3) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("\(unhealthy)").font(.system(size: 12, weight: .medium))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.platformBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    CardDetailView(cardType: .totalDevices)
        .environmentObject(HomeKitManager.shared)
        .environmentObject(DeviceTester.shared)
        .environmentObject(SceneAnalyzer.shared)
}
