//
//  SceneAnalyzer.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import Foundation
import HomeKit
import Combine

/// Analyzes and repairs HomeKit scenes
@MainActor
class SceneAnalyzer: ObservableObject {
    static let shared = SceneAnalyzer()

    // MARK: - Published Properties

    @Published var isAnalyzing = false
    @Published var analyzeProgress: Double = 0
    @Published var auditResults: [SceneAuditResult] = []
    @Published var backups: [SceneBackup] = []
    @Published var repairHistory: [SceneRepairAction] = []

    // MARK: - Private Properties

    private var homeKitManager: HomeKitManager { HomeKitManager.shared }

    // MARK: - Initialization

    private init() {
        loadBackups()
    }

    // MARK: - Scene Audit

    func auditAllScenes() async {
        guard !isAnalyzing else { return }

        isAnalyzing = true
        analyzeProgress = 0
        auditResults = []

        NSLog("[SceneAnalyzer] Starting audit of %d scenes", homeKitManager.scenes.count)

        for (index, scene) in homeKitManager.scenes.enumerated() {
            analyzeProgress = Double(index) / Double(homeKitManager.scenes.count)

            let result = await auditScene(scene)
            auditResults.append(result)

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        analyzeProgress = 1.0
        isAnalyzing = false

        let brokenCount = auditResults.filter { $0.healthPercentage < 100 }.count
        NSLog("[SceneAnalyzer] Audit complete. %d scenes have issues", brokenCount)
    }

    func auditScene(_ scene: SceneInfo) async -> SceneAuditResult {
        // Re-check device reachability
        guard let actionSet = homeKitManager.getActionSet(for: scene),
              let home = homeKitManager.home else {
            return SceneAuditResult(
                scene: scene,
                recommendations: ["Scene not found in HomeKit"]
            )
        }

        // Get fresh device status
        let actionAccessories = actionSet.actions.compactMap { action -> HMAccessory? in
            guard let characteristic = (action as? NSObject)?.value(forKey: "characteristic") as? HMCharacteristic else {
                return nil
            }
            return characteristic.service?.accessory
        }

        let uniqueAccessories = Array(Set(actionAccessories))
        let reachable = uniqueAccessories.filter { $0.isReachable }
        let unreachable = uniqueAccessories.filter { !$0.isReachable }

        var recommendations: [String] = []

        if !unreachable.isEmpty {
            recommendations.append("Remove \(unreachable.count) unreachable device(s)")
            for accessory in unreachable {
                recommendations.append("  - \(accessory.name) is not responding")
            }
        }

        let healthPercentage = uniqueAccessories.isEmpty ? 100 : (Double(reachable.count) / Double(uniqueAccessories.count)) * 100

        if healthPercentage < 50 {
            recommendations.append("Consider rebuilding this scene - more than half of devices are unavailable")
        }

        // Update scene in manager
        if let index = homeKitManager.scenes.firstIndex(where: { $0.id == scene.id }) {
            homeKitManager.scenes[index].lastAudit = Date()
            homeKitManager.scenes[index].reachableDevices = reachable.count
            homeKitManager.scenes[index].unreachableDevices = unreachable.count
            homeKitManager.scenes[index].reachableDeviceNames = reachable.map { $0.name }
            homeKitManager.scenes[index].unreachableDeviceNames = unreachable.map { $0.name }

            if unreachable.isEmpty {
                homeKitManager.scenes[index].healthStatus = .healthy
            } else if unreachable.count >= uniqueAccessories.count / 2 {
                homeKitManager.scenes[index].healthStatus = .broken
            } else {
                homeKitManager.scenes[index].healthStatus = .degraded
            }
        }

        return SceneAuditResult(
            scene: scene,
            reachableDevices: reachable.map { $0.name },
            unreachableDevices: unreachable.map { $0.name },
            recommendations: recommendations
        )
    }

    // MARK: - Scene Repair

    func repairAllBrokenScenes() async {
        let brokenScenes = homeKitManager.scenes.filter { scene in
            scene.healthStatus == .broken || scene.healthStatus == .degraded
        }

        NSLog("[SceneAnalyzer] Repairing %d broken scenes", brokenScenes.count)

        for scene in brokenScenes {
            _ = await repairScene(scene, removingUnreachable: true)
        }
    }

    func repairScene(_ scene: SceneInfo, removingUnreachable: Bool) async -> Bool {
        guard !scene.unreachableDeviceNames.isEmpty else {
            NSLog("[SceneAnalyzer] Scene '%@' has no unreachable devices", scene.name)
            return true
        }

        // First, create a backup
        await backupScene(scene)

        guard let actionSet = homeKitManager.getActionSet(for: scene),
              let home = homeKitManager.home else {
            NSLog("[SceneAnalyzer] Failed to get action set for scene '%@'", scene.name)
            return false
        }

        if removingUnreachable {
            #if os(tvOS)
            // Scene repair (removing actions) is not available on tvOS
            // HomeKit's removeAction API is unavailable on this platform
            let repairAction = SceneRepairAction(
                sceneId: scene.id,
                sceneName: scene.name,
                actionType: .removeDevice,
                success: false,
                message: "Scene repair is not available on Apple TV. Use iPhone or iPad to repair scenes."
            )
            repairHistory.append(repairAction)
            NSLog("[SceneAnalyzer] Scene repair not available on tvOS for scene '%@'", scene.name)
            return false
            #else
            // Find actions associated with unreachable devices
            let actionsToRemove = actionSet.actions.filter { action in
                guard let characteristic = (action as? NSObject)?.value(forKey: "characteristic") as? HMCharacteristic,
                      let accessory = characteristic.service?.accessory else {
                    return false
                }
                return !accessory.isReachable
            }

            // Remove each action
            for action in actionsToRemove {
                do {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        actionSet.removeAction(action) { error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                } catch {
                    NSLog("[SceneAnalyzer] Failed to remove action: %@", error.localizedDescription)
                }
            }

            // Log repair action
            let repairAction = SceneRepairAction(
                sceneId: scene.id,
                sceneName: scene.name,
                actionType: .removeDevice,
                success: true,
                message: "Removed \(actionsToRemove.count) actions for unreachable devices"
            )
            repairHistory.append(repairAction)

            // Refresh scene data
            await homeKitManager.refreshAll()

            NSLog("[SceneAnalyzer] Repaired scene '%@' - removed %d actions", scene.name, actionsToRemove.count)
            return true
            #endif
        }

        return false
    }

    // MARK: - Backup & Restore

    func backupScene(_ scene: SceneInfo) async {
        let backup = SceneBackup(
            sceneId: scene.id,
            sceneName: scene.name,
            deviceNames: scene.reachableDeviceNames + scene.unreachableDeviceNames
        )

        backups.append(backup)
        saveBackups()

        NSLog("[SceneAnalyzer] Created backup for scene '%@'", scene.name)
    }

    func restoreScene(from backup: SceneBackup) async -> Bool {
        // Note: Full restore would require recreating actions in HomeKit
        // This is a complex operation that requires knowing the original characteristic values
        // For now, we log the attempt

        let action = SceneRepairAction(
            sceneId: backup.sceneId,
            sceneName: backup.sceneName,
            actionType: .fullRestore,
            success: false,
            message: "Full restore requires manual recreation of scene actions"
        )
        repairHistory.append(action)

        NSLog("[SceneAnalyzer] Restore requested for scene '%@' - manual intervention required", backup.sceneName)
        return false
    }

    // MARK: - Persistence

    private var backupsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scene_backups.json")
    }

    private func loadBackups() {
        do {
            let data = try Data(contentsOf: backupsURL)
            backups = try JSONDecoder().decode([SceneBackup].self, from: data)
            NSLog("[SceneAnalyzer] Loaded %d scene backups", backups.count)
        } catch {
            backups = []
        }
    }

    private func saveBackups() {
        do {
            let data = try JSONEncoder().encode(backups)
            try data.write(to: backupsURL)
        } catch {
            NSLog("[SceneAnalyzer] Failed to save backups: %@", error.localizedDescription)
        }
    }
}
