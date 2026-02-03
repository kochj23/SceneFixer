//
//  DeviceListView.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject var homeKitManager: HomeKitManager
    @EnvironmentObject var deviceTester: DeviceTester

    @State private var searchText = ""
    @State private var sortBy: SortOption = .name
    @State private var filterStatus: DeviceHealthStatus? = nil

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case status = "Status"
        case room = "Room"
        case manufacturer = "Manufacturer"
        case reliability = "Reliability"
    }

    var filteredDevices: [DeviceInfo] {
        var devices = homeKitManager.devices

        // Search filter
        if !searchText.isEmpty {
            devices = devices.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.room?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                $0.manufacturer.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Status filter
        if let status = filterStatus {
            devices = devices.filter { $0.healthStatus == status }
        }

        // Sort
        switch sortBy {
        case .name:
            devices.sort { $0.name < $1.name }
        case .status:
            devices.sort { $0.healthStatus.rawValue < $1.healthStatus.rawValue }
        case .room:
            devices.sort { ($0.room ?? "ZZZ") < ($1.room ?? "ZZZ") }
        case .manufacturer:
            devices.sort { $0.manufacturer.rawValue < $1.manufacturer.rawValue }
        case .reliability:
            devices.sort { $0.reliabilityScore > $1.reliabilityScore }
        }

        return devices
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredDevices) { device in
                    NavigationLink(destination: DeviceDetailView(device: device)) {
                        DeviceRow(device: device)
                    }
                }
            }
            .listStyle(.plain)
            #if !os(tvOS)
            .searchable(text: $searchText, prompt: "Search devices...")
            #endif
            .navigationTitle("Devices")
            #if !os(tvOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sortBy) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }

                        Divider()

                        Picker("Status", selection: $filterStatus) {
                            Text("All Statuses").tag(nil as DeviceHealthStatus?)
                            ForEach(DeviceHealthStatus.allCases, id: \.self) { status in
                                Text(status.rawValue).tag(status as DeviceHealthStatus?)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await deviceTester.runFullHealthCheck()
                        }
                    } label: {
                        if deviceTester.isTesting {
                            ProgressView()
                        } else {
                            Image(systemName: "heart.text.square")
                        }
                    }
                    .disabled(deviceTester.isTesting)
                }
            }
            #endif
        }
    }
}

struct DeviceRow: View {
    let device: DeviceInfo

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: device.category.icon)
                .font(.system(size: 22))
                .foregroundColor(statusColor)
                .frame(width: 32)

            // Device info
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 15, weight: .medium))

                HStack(spacing: 6) {
                    if let room = device.room {
                        Text(room)
                    }
                    Text("•")
                    Text(device.manufacturer.rawValue)
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }

            Spacer()

            // Status & reliability
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(device.healthStatus.rawValue)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(statusColor)

                Text("\(String(format: "%.0f", device.reliabilityScore))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(device.reliabilityScore >= 90 ? .green : (device.reliabilityScore >= 70 ? .yellow : .red))
            }
        }
        .padding(.vertical, 4)
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

struct DeviceDetailView: View {
    let device: DeviceInfo
    @EnvironmentObject var deviceTester: DeviceTester

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    Image(systemName: device.category.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack(spacing: 8) {
                            StatusBadge(status: device.healthStatus)
                            if let room = device.room {
                                Text(room)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Quick actions
                HStack(spacing: 12) {
                    Button {
                        Task {
                            _ = await deviceTester.testDevice(device)
                        }
                    } label: {
                        Label("Test Device", systemImage: "heart.text.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task {
                            _ = await deviceTester.toggleTest(device)
                        }
                    } label: {
                        Label("Toggle", systemImage: "power")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                // Info sections
                PlatformGroupBox("Device Information") {
                    VStack(alignment: .leading, spacing: 10) {
                        DeviceInfoRow(label: "Category", value: device.category.rawValue)
                        DeviceInfoRow(label: "Manufacturer", value: device.manufacturer.rawValue)
                        DeviceInfoRow(label: "Protocol", value: device.protocolType.rawValue)
                        if let model = device.model {
                            DeviceInfoRow(label: "Model", value: model)
                        }
                        if let firmware = device.firmwareVersion {
                            DeviceInfoRow(label: "Firmware", value: firmware)
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                PlatformGroupBox("Health Metrics") {
                    VStack(alignment: .leading, spacing: 10) {
                        DeviceInfoRow(label: "Reachable", value: device.isReachable ? "Yes" : "No")
                        DeviceInfoRow(label: "Reliability", value: String(format: "%.1f%%", device.reliabilityScore))
                        if let avgResponse = device.averageResponseTime {
                            DeviceInfoRow(label: "Avg Response", value: String(format: "%.0f ms", avgResponse))
                        }
                        if let lastSeen = device.lastSeen {
                            DeviceInfoRow(label: "Last Seen", value: formatDate(lastSeen))
                        }
                        DeviceInfoRow(label: "Tests Run", value: "\(device.testHistory.count)")
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                if !device.sceneNames.isEmpty {
                    PlatformGroupBox("Scenes (\(device.sceneCount))") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(device.sceneNames, id: \.self) { name in
                                HStack {
                                    Image(systemName: "play.rectangle.on.rectangle")
                                        .foregroundColor(.secondary)
                                    Text(name)
                                }
                                .font(.system(size: 14))
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle("Device Details")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DeviceInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.system(size: 14))
    }
}

struct StatusBadge: View {
    let status: DeviceHealthStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(status.rawValue)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(4)
        .foregroundColor(statusColor)
    }

    var statusColor: Color {
        switch status {
        case .healthy: return .green
        case .degraded: return .yellow
        case .unreachable: return .red
        case .unknown: return .gray
        case .testing: return .blue
        }
    }
}

#Preview {
    DeviceListView()
        .environmentObject(HomeKitManager.shared)
        .environmentObject(DeviceTester.shared)
}
