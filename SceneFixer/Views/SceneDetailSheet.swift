//
//  SceneDetailSheet.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/3/26.
//

import SwiftUI

struct SceneDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var homeKitManager: HomeKitManager
    @EnvironmentObject var sceneAnalyzer: SceneAnalyzer

    let scene: SceneInfo

    @State private var isExecuting = false
    @State private var isAuditing = false
    @State private var isRepairing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection

                    // Quick Actions
                    quickActionsSection

                    Divider().padding(.horizontal)

                    // Health Overview
                    healthOverviewSection

                    // Working Devices
                    if scene.reachableDevices > 0 {
                        workingDevicesSection
                    }

                    // Problem Devices
                    if scene.unreachableDevices > 0 {
                        problemDevicesSection
                    }

                    // Audit Info
                    if scene.lastAudit != nil {
                        auditInfoSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Scene Details")
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
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 16) {
            // Large icon
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 44))
                .foregroundColor(statusColor)
                .frame(width: 80, height: 80)
                .background(statusColor.opacity(0.15))
                .cornerRadius(16)

            VStack(alignment: .leading, spacing: 6) {
                Text(scene.name)
                    .font(.system(size: 22, weight: .bold))

                Text("\(scene.totalDevices) devices")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                // Status badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(scene.healthStatus.rawValue)
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
        HStack(spacing: 12) {
            // Execute Scene button
            Button {
                executeScene()
            } label: {
                VStack(spacing: 6) {
                    if isExecuting {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                    }
                    Text("Run Scene")
                        .font(.system(size: 12))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isExecuting)

            // Audit button
            Button {
                auditScene()
            } label: {
                VStack(spacing: 6) {
                    if isAuditing {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 20))
                    }
                    Text("Audit")
                        .font(.system(size: 12))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isAuditing)

            // Repair button (only if broken)
            #if !os(tvOS)
            if scene.unreachableDevices > 0 {
                Button {
                    repairScene()
                } label: {
                    VStack(spacing: 6) {
                        if isRepairing {
                            ProgressView()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 20))
                        }
                        Text("Repair")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isRepairing)
            }
            #endif
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Health Overview

    @ViewBuilder
    private var healthOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Overview")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 16) {
                // Health bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Scene Health")
                        Spacer()
                        Text(String(format: "%.0f%%", scene.healthPercentage))
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .cornerRadius(6)
                            Rectangle()
                                .fill(statusColor)
                                .frame(width: geometry.size.width * (scene.healthPercentage / 100))
                                .cornerRadius(6)
                        }
                    }
                    .frame(height: 16)
                }

                // Stats grid
                HStack(spacing: 16) {
                    VStack {
                        Text("\(scene.totalDevices)")
                            .font(.system(size: 28, weight: .bold))
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 50)

                    VStack {
                        Text("\(scene.reachableDevices)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.green)
                        Text("Working")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 50)

                    VStack {
                        Text("\(scene.unreachableDevices)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(scene.unreachableDevices > 0 ? .red : .secondary)
                        Text("Broken")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color.platformBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Working Devices

    @ViewBuilder
    private var workingDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Working Devices")
                    .font(.headline)
                Spacer()
                Text("\(scene.reachableDevices)")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(scene.reachableDeviceNames, id: \.self) { deviceName in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(deviceName)
                        Spacer()
                    }
                    .padding()
                    if deviceName != scene.reachableDeviceNames.last {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color.platformBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Problem Devices

    @ViewBuilder
    private var problemDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Unreachable Devices")
                    .font(.headline)
                Spacer()
                Text("\(scene.unreachableDevices)")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(scene.unreachableDeviceNames, id: \.self) { deviceName in
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(deviceName)
                        Spacer()
                        Text("Offline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    if deviceName != scene.unreachableDeviceNames.last {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Color.platformBackground)
            .cornerRadius(12)
            .padding(.horizontal)

            // Warning message
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("These devices will not respond when this scene is executed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Audit Info

    @ViewBuilder
    private var auditInfoSection: some View {
        if let lastAudit = scene.lastAudit {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last Audit")
                    .font(.headline)
                    .padding(.horizontal)

                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(formatDate(lastAudit))
                    Spacer()
                    Text(formatRelativeDate(lastAudit))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.platformBackground)
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch scene.healthStatus {
        case .healthy: return .green
        case .degraded: return .yellow
        case .broken: return .red
        case .unknown: return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func executeScene() {
        isExecuting = true
        Task {
            do {
                try await homeKitManager.executeScene(scene)
            } catch {
                NSLog("[SceneDetailSheet] Failed to execute scene: %@", error.localizedDescription)
            }
            isExecuting = false
        }
    }

    private func auditScene() {
        isAuditing = true
        Task {
            _ = await sceneAnalyzer.auditScene(scene)
            isAuditing = false
        }
    }

    private func repairScene() {
        isRepairing = true
        Task {
            _ = await sceneAnalyzer.repairScene(scene, removingUnreachable: true)
            isRepairing = false
        }
    }
}

// MARK: - Preview

#Preview {
    SceneDetailSheet(scene: SceneInfo(
        id: UUID(),
        name: "Movie Night",
        totalDevices: 5,
        reachableDevices: 3,
        unreachableDevices: 2,
        reachableDeviceNames: ["Living Room Light", "TV Backlight", "Ceiling Fan"],
        unreachableDeviceNames: ["Lamp 1", "Lamp 2"],
        healthStatus: .degraded
    ))
    .environmentObject(HomeKitManager.shared)
    .environmentObject(SceneAnalyzer.shared)
}
