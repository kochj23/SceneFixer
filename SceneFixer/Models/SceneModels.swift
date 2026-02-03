//
//  SceneModels.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import Foundation
import HomeKit

// MARK: - Scene Health Status

enum SceneHealthStatus: String, CaseIterable, Codable {
    case healthy = "Healthy"
    case degraded = "Degraded"
    case broken = "Broken"
    case unknown = "Unknown"
}

// MARK: - Scene Info

struct SceneInfo: Identifiable, Hashable {
    let id: UUID
    var name: String

    // HomeKit reference
    var actionSetUUID: UUID?

    // Device counts
    var totalDevices: Int = 0
    var reachableDevices: Int = 0
    var unreachableDevices: Int = 0

    // Device names
    var reachableDeviceNames: [String] = []
    var unreachableDeviceNames: [String] = []

    // Health
    var healthStatus: SceneHealthStatus = .unknown
    var healthPercentage: Double {
        guard totalDevices > 0 else { return 100 }
        return (Double(reachableDevices) / Double(totalDevices)) * 100
    }

    // Audit info
    var lastAudit: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SceneInfo, rhs: SceneInfo) -> Bool {
        lhs.id == rhs.id
    }

    static func from(actionSet: HMActionSet, accessories: [HMAccessory]) -> SceneInfo {
        var info = SceneInfo(
            id: UUID(),
            name: actionSet.name,
            actionSetUUID: actionSet.uniqueIdentifier
        )

        // Get all accessories involved in this scene
        let actionAccessories = actionSet.actions.compactMap { action -> HMAccessory? in
            // Use KVC to access characteristic without generic type inference issues
            guard let characteristic = (action as? NSObject)?.value(forKey: "characteristic") as? HMCharacteristic else {
                return nil
            }
            return characteristic.service?.accessory
        }

        let uniqueAccessories = Array(Set(actionAccessories))
        info.totalDevices = uniqueAccessories.count

        let reachable = uniqueAccessories.filter { $0.isReachable }
        let unreachable = uniqueAccessories.filter { !$0.isReachable }

        info.reachableDevices = reachable.count
        info.unreachableDevices = unreachable.count
        info.reachableDeviceNames = reachable.map { $0.name }
        info.unreachableDeviceNames = unreachable.map { $0.name }

        // Determine health status
        if info.unreachableDevices == 0 {
            info.healthStatus = .healthy
        } else if info.unreachableDevices >= info.totalDevices / 2 {
            info.healthStatus = .broken
        } else {
            info.healthStatus = .degraded
        }

        return info
    }
}

// MARK: - Scene Audit Result

struct SceneAuditResult: Identifiable {
    let id: UUID
    let scene: SceneInfo
    let auditDate: Date
    let reachableDevices: [String]
    let unreachableDevices: [String]
    let recommendations: [String]

    var healthPercentage: Double {
        let total = reachableDevices.count + unreachableDevices.count
        guard total > 0 else { return 100 }
        return (Double(reachableDevices.count) / Double(total)) * 100
    }

    init(id: UUID = UUID(), scene: SceneInfo, auditDate: Date = Date(), reachableDevices: [String] = [], unreachableDevices: [String] = [], recommendations: [String] = []) {
        self.id = id
        self.scene = scene
        self.auditDate = auditDate
        self.reachableDevices = reachableDevices
        self.unreachableDevices = unreachableDevices
        self.recommendations = recommendations
    }
}

// MARK: - Scene Backup

struct SceneBackup: Identifiable, Codable {
    let id: UUID
    let sceneId: UUID
    let sceneName: String
    let backupDate: Date
    let deviceNames: [String]
    let configuration: [String: String]

    init(id: UUID = UUID(), sceneId: UUID, sceneName: String, backupDate: Date = Date(), deviceNames: [String] = [], configuration: [String: String] = [:]) {
        self.id = id
        self.sceneId = sceneId
        self.sceneName = sceneName
        self.backupDate = backupDate
        self.deviceNames = deviceNames
        self.configuration = configuration
    }
}

// MARK: - Scene Repair Action

struct SceneRepairAction: Identifiable {
    let id: UUID
    let sceneId: UUID
    let sceneName: String
    let actionType: RepairActionType
    let deviceName: String?
    let timestamp: Date
    let success: Bool
    let message: String?

    enum RepairActionType: String {
        case removeDevice = "Remove Device"
        case restoreDevice = "Restore Device"
        case updateConfiguration = "Update Configuration"
        case fullRestore = "Full Restore"
    }

    init(id: UUID = UUID(), sceneId: UUID, sceneName: String, actionType: RepairActionType, deviceName: String? = nil, timestamp: Date = Date(), success: Bool, message: String? = nil) {
        self.id = id
        self.sceneId = sceneId
        self.sceneName = sceneName
        self.actionType = actionType
        self.deviceName = deviceName
        self.timestamp = timestamp
        self.success = success
        self.message = message
    }
}
