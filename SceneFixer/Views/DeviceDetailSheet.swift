//
//  DeviceDetailSheet.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/3/26.
//

import SwiftUI
import Charts

struct DeviceDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var homeKitManager: HomeKitManager
    @EnvironmentObject var deviceTester: DeviceTester

    let device: DeviceInfo

    @State private var isToggling = false
    @State private var isTesting = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var showDeleteError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection

                    // Quick Actions
                    quickActionsSection

                    Divider().padding(.horizontal)

                    // Device Info
                    deviceInfoSection

                    // Health Metrics
                    healthMetricsSection

                    // Response Time Chart
                    if !device.testHistory.isEmpty {
                        responseTimeChartSection
                    }

                    // Test History
                    if !device.testHistory.isEmpty {
                        testHistorySection
                    }

                    // Scene Membership
                    if !device.sceneNames.isEmpty {
                        sceneMembershipSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Device Details")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
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
        #if !os(tvOS)
        .alert("Remove Device", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                deleteDevice()
            }
        } message: {
            Text("Are you sure you want to remove \"\(device.name)\" from your home? This action cannot be undone and you will need to re-pair the device to add it back.")
        }
        .alert("Error Removing Device", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteError ?? "An unknown error occurred while removing the device.")
        }
        #endif
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 16) {
            // Large icon
            Image(systemName: device.category.icon)
                .font(.system(size: 44))
                .foregroundColor(statusColor)
                .frame(width: 80, height: 80)
                .background(statusColor.opacity(0.15))
                .cornerRadius(16)

            VStack(alignment: .leading, spacing: 6) {
                Text(device.name)
                    .font(.system(size: 22, weight: .bold))

                if let room = device.room {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                        Text(room)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }

                // Status badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(device.healthStatus.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(statusColor)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.platformBackground)
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Quick Actions

    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Toggle button
                Button {
                    toggleDevice()
                } label: {
                    VStack(spacing: 6) {
                        if isToggling {
                            ProgressView()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "power")
                                .font(.system(size: 20))
                        }
                        Text("Toggle")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isToggling || device.category.isDangerous)
                .opacity(device.category.isDangerous ? 0.5 : 1)

                // Test button
                Button {
                    testDevice()
                } label: {
                    VStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 20))
                        }
                        Text("Test")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isTesting)

                // Refresh button
                Button {
                    Task {
                        await homeKitManager.refreshAll()
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20))
                        Text("Refresh")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }

            // Delete button (not available on tvOS)
            #if !os(tvOS)
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 8) {
                    if isDeleting {
                        ProgressView()
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16))
                    }
                    Text("Remove Device from Home")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)
                .cornerRadius(10)
            }
            .disabled(isDeleting)
            #endif
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Device Info Section

    @ViewBuilder
    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Information")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                InfoRow(label: "Category", value: device.category.rawValue)
                Divider().padding(.leading, 16)
                InfoRow(label: "Manufacturer", value: device.manufacturer.rawValue)
                Divider().padding(.leading, 16)
                InfoRow(label: "Protocol", value: device.protocolType.rawValue)
                if let model = device.model {
                    Divider().padding(.leading, 16)
                    InfoRow(label: "Model", value: model)
                }
                if let firmware = device.firmwareVersion {
                    Divider().padding(.leading, 16)
                    InfoRow(label: "Firmware", value: firmware)
                }
                if let hub = device.hubName {
                    Divider().padding(.leading, 16)
                    InfoRow(label: "Hub", value: hub)
                }
            }
            .background(Color.platformBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Health Metrics Section

    @ViewBuilder
    private var healthMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Metrics")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Reliability",
                    value: String(format: "%.1f%%", device.reliabilityScore),
                    icon: "chart.line.uptrend.xyaxis",
                    color: device.reliabilityScore > 90 ? .green : device.reliabilityScore > 70 ? .yellow : .red
                )

                MetricCard(
                    title: "Reachable",
                    value: device.isReachable ? "Yes" : "No",
                    icon: device.isReachable ? "wifi" : "wifi.slash",
                    color: device.isReachable ? .green : .red
                )

                if let avgResponse = device.averageResponseTime {
                    MetricCard(
                        title: "Avg Response",
                        value: String(format: "%.0f ms", avgResponse),
                        icon: "speedometer",
                        color: avgResponse < 500 ? .green : avgResponse < 1000 ? .yellow : .red
                    )
                }

                MetricCard(
                    title: "Tests Run",
                    value: "\(device.testHistory.count)",
                    icon: "checkmark.circle",
                    color: .blue
                )

                if let lastSeen = device.lastSeen {
                    MetricCard(
                        title: "Last Seen",
                        value: formatRelativeDate(lastSeen),
                        icon: "clock",
                        color: .secondary
                    )
                }

                MetricCard(
                    title: "In Scenes",
                    value: "\(device.sceneCount)",
                    icon: "play.rectangle.on.rectangle",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Response Time Chart

    @ViewBuilder
    private var responseTimeChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Response Time History")
                .font(.headline)
                .padding(.horizontal)

            let chartData = device.testHistory
                .filter { $0.responseTime != nil }
                .suffix(20)

            if chartData.isEmpty {
                Text("No response time data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Chart {
                    ForEach(Array(chartData)) { result in
                        if let responseTime = result.responseTime {
                            LineMark(
                                x: .value("Time", result.timestamp),
                                y: .value("Response (ms)", responseTime)
                            )
                            .foregroundStyle(Color.blue)

                            PointMark(
                                x: .value("Time", result.timestamp),
                                y: .value("Response (ms)", responseTime)
                            )
                            .foregroundStyle(result.success ? Color.green : Color.red)
                        }
                    }
                }
                .chartYAxisLabel("ms")
                .frame(height: 180)
                .padding()
                .background(Color.platformBackground)
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Test History Section

    @ViewBuilder
    private var testHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Test History")
                    .font(.headline)
                Spacer()
                Text("\(device.testHistory.count) tests")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(device.testHistory.suffix(10).reversed()) { result in
                    TestResultRow(result: result)
                    if result.id != device.testHistory.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color.platformBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Scene Membership

    @ViewBuilder
    private var sceneMembershipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scene Membership")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(device.sceneNames, id: \.self) { sceneName in
                    HStack {
                        Image(systemName: "play.rectangle.on.rectangle")
                            .foregroundColor(.purple)
                        Text(sceneName)
                        Spacer()
                    }
                    .padding()
                    if sceneName != device.sceneNames.last {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color.platformBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch device.healthStatus {
        case .healthy: return .green
        case .degraded: return .yellow
        case .unreachable: return .red
        case .unknown: return .gray
        case .testing: return .blue
        }
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func toggleDevice() {
        isToggling = true
        Task {
            _ = await deviceTester.toggleTest(device)
            isToggling = false
        }
    }

    private func testDevice() {
        isTesting = true
        Task {
            _ = await deviceTester.testDevice(device)
            isTesting = false
        }
    }

    #if !os(tvOS)
    private func deleteDevice() {
        isDeleting = true
        Task {
            do {
                try await homeKitManager.removeDevice(device)
                // Dismiss the sheet after successful deletion
                dismiss()
            } catch {
                deleteError = error.localizedDescription
                showDeleteError = true
                NSLog("[DeviceDetailSheet] Failed to delete device: %@", error.localizedDescription)
            }
            isDeleting = false
        }
    }
    #endif
}

// MARK: - Info Row

struct InfoRow: View {
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
        .padding()
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 20, weight: .bold))

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.platformBackground)
        .cornerRadius(10)
    }
}

// MARK: - Test Result Row

struct TestResultRow: View {
    let result: DeviceTestResult

    var body: some View {
        HStack {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(result.timestamp))
                    .font(.system(size: 13, weight: .medium))
                if let error = result.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let responseTime = result.responseTime {
                Text(String(format: "%.0f ms", responseTime))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    DeviceDetailSheet(device: DeviceInfo(
        id: UUID(),
        name: "Living Room Light",
        room: "Living Room",
        manufacturer: .philipsHue,
        category: .light,
        protocolType: .zigbee,
        healthStatus: .healthy,
        reliabilityScore: 98.5,
        testHistory: [
            DeviceTestResult(success: true, responseTime: 150),
            DeviceTestResult(success: true, responseTime: 180),
            DeviceTestResult(success: false, responseTime: nil, errorMessage: "Timeout")
        ]
    ))
    .environmentObject(HomeKitManager.shared)
    .environmentObject(DeviceTester.shared)
}
