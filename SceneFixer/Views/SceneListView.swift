//
//  SceneListView.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import SwiftUI

struct SceneListView: View {
    @EnvironmentObject var homeKitManager: HomeKitManager
    @EnvironmentObject var sceneAnalyzer: SceneAnalyzer

    @State private var searchText = ""
    @State private var filterStatus: SceneHealthStatus? = nil

    var filteredScenes: [SceneInfo] {
        var scenes = homeKitManager.scenes

        if !searchText.isEmpty {
            scenes = scenes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        if let status = filterStatus {
            scenes = scenes.filter { $0.healthStatus == status }
        }

        return scenes.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredScenes) { scene in
                    NavigationLink(destination: SceneDetailView(scene: scene)) {
                        SceneRow(scene: scene)
                    }
                }
            }
            .listStyle(.plain)
            #if !os(tvOS)
            .searchable(text: $searchText, prompt: "Search scenes...")
            #endif
            .navigationTitle("Scenes")
            #if !os(tvOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Status", selection: $filterStatus) {
                            Text("All Statuses").tag(nil as SceneHealthStatus?)
                            ForEach(SceneHealthStatus.allCases, id: \.self) { status in
                                Text(status.rawValue).tag(status as SceneHealthStatus?)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await sceneAnalyzer.auditAllScenes()
                        }
                    } label: {
                        if sceneAnalyzer.isAnalyzing {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark.shield")
                        }
                    }
                    .disabled(sceneAnalyzer.isAnalyzing)
                }
            }
            #endif
        }
    }
}

struct SceneRow: View {
    let scene: SceneInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.system(size: 22))
                .foregroundColor(statusColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(scene.name)
                    .font(.system(size: 15, weight: .medium))
                Text("\(scene.totalDevices) devices")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(scene.healthStatus.rawValue)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(statusColor)

                Text("\(scene.reachableDevices)/\(scene.totalDevices)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
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

struct SceneDetailView: View {
    let scene: SceneInfo
    @EnvironmentObject var homeKitManager: HomeKitManager
    @EnvironmentObject var sceneAnalyzer: SceneAnalyzer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    Image(systemName: "play.rectangle.on.rectangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(statusColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(scene.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack(spacing: 8) {
                            SceneStatusBadge(status: scene.healthStatus)
                            Text("\(scene.totalDevices) devices")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)

                // Actions
                HStack(spacing: 12) {
                    Button {
                        Task {
                            _ = await sceneAnalyzer.auditScene(scene)
                        }
                    } label: {
                        Label("Audit", systemImage: "checkmark.shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if scene.healthStatus != .healthy {
                        Button {
                            Task {
                                _ = await sceneAnalyzer.repairScene(scene, removingUnreachable: true)
                            }
                        } label: {
                            Label("Repair", systemImage: "wrench")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)

                // Stats
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    SceneStatCard(title: "Total", value: "\(scene.totalDevices)", color: .blue)
                    SceneStatCard(title: "Working", value: "\(scene.reachableDevices)", color: .green)
                    SceneStatCard(title: "Broken", value: "\(scene.unreachableDevices)", color: .red)
                }
                .padding(.horizontal)

                // Health bar
                PlatformGroupBox("Scene Health") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Health Score")
                            Spacer()
                            Text("\(String(format: "%.0f", scene.healthPercentage))%")
                                .fontWeight(.bold)
                                .foregroundColor(statusColor)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                Rectangle()
                                    .fill(statusColor)
                                    .frame(width: geometry.size.width * (scene.healthPercentage / 100))
                            }
                        }
                        .frame(height: 12)
                        .cornerRadius(6)
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                // Working devices
                if scene.reachableDevices > 0 {
                    PlatformGroupBox("Working Devices (\(scene.reachableDevices))") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(scene.reachableDeviceNames, id: \.self) { name in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(name)
                                }
                                .font(.system(size: 14))
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                }

                // Broken devices
                if scene.unreachableDevices > 0 {
                    PlatformGroupBox("Unreachable Devices (\(scene.unreachableDevices))") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(scene.unreachableDeviceNames, id: \.self) { name in
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(name)
                                }
                                .font(.system(size: 14))
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                }

                // Last audit
                if let lastAudit = scene.lastAudit {
                    PlatformGroupBox("Last Audit") {
                        HStack {
                            Text("Date")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(lastAudit))
                        }
                        .font(.system(size: 14))
                        .padding(8)
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle("Scene Details")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    var statusColor: Color {
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
}

struct SceneStatusBadge: View {
    let status: SceneHealthStatus

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
        case .broken: return .red
        case .unknown: return .gray
        }
    }
}

struct SceneStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    SceneListView()
        .environmentObject(HomeKitManager.shared)
        .environmentObject(SceneAnalyzer.shared)
}
