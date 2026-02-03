//
//  HomeKitManager.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import Foundation
import HomeKit
import Combine

/// Manages HomeKit integration for device and scene discovery
@MainActor
class HomeKitManager: NSObject, ObservableObject {
    static let shared = HomeKitManager()

    // MARK: - Published Properties

    @Published var devices: [DeviceInfo] = []
    @Published var scenes: [SceneInfo] = []
    @Published var home: HMHome?
    @Published var homes: [HMHome] = []
    @Published var isLoading = false
    @Published var isAuthorized = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var homeManager: HMHomeManager!

    // MARK: - Initialization

    private override init() {
        super.init()
        homeManager = HMHomeManager()
        homeManager.delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() {
        // HomeKit authorization is requested automatically when HMHomeManager is created
        // The delegate will be called with the result
        isLoading = true
        NSLog("[HomeKitManager] Requesting HomeKit authorization...")
    }

    // MARK: - Data Loading

    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }

        guard let home = home else {
            errorMessage = "No home selected"
            return
        }

        await loadDevices(from: home)
        await loadScenes(from: home)

        NSLog("[HomeKitManager] Refreshed %d devices and %d scenes", devices.count, scenes.count)
    }

    private func loadDevices(from home: HMHome) async {
        var loadedDevices: [DeviceInfo] = []

        for accessory in home.accessories {
            let room = home.rooms.first { room in
                room.accessories.contains(accessory)
            }

            var device = DeviceInfo.from(accessory: accessory, room: room)

            // Count scenes this device is in
            let deviceScenes = home.actionSets.filter { actionSet in
                actionSet.actions.contains { action in
                    guard let characteristic = (action as? NSObject)?.value(forKey: "characteristic") as? HMCharacteristic else {
                        return false
                    }
                    return characteristic.service?.accessory?.uniqueIdentifier == accessory.uniqueIdentifier
                }
            }
            device.sceneCount = deviceScenes.count
            device.sceneNames = deviceScenes.map { $0.name }

            loadedDevices.append(device)
        }

        devices = loadedDevices
    }

    private func loadScenes(from home: HMHome) async {
        var loadedScenes: [SceneInfo] = []

        for actionSet in home.actionSets {
            let scene = SceneInfo.from(actionSet: actionSet, accessories: home.accessories)
            loadedScenes.append(scene)
        }

        scenes = loadedScenes
    }

    // MARK: - Home Selection

    func selectHome(_ home: HMHome) {
        self.home = home
        Task {
            await refreshAll()
        }
    }

    // MARK: - Device Control

    func getAccessory(for device: DeviceInfo) -> HMAccessory? {
        guard let home = home, let uuid = device.accessoryUUID else { return nil }
        return home.accessories.first { $0.uniqueIdentifier == uuid }
    }

    func getPowerCharacteristic(for accessory: HMAccessory) -> HMCharacteristic? {
        for service in accessory.services {
            if let characteristic = service.characteristics.first(where: {
                $0.characteristicType == HMCharacteristicTypePowerState
            }) {
                return characteristic
            }
        }
        return nil
    }

    func toggleDevice(_ device: DeviceInfo, on: Bool) async throws {
        guard let accessory = getAccessory(for: device),
              let powerChar = getPowerCharacteristic(for: accessory) else {
            throw HomeKitError.deviceNotFound
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            powerChar.writeValue(on) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func readDeviceState(_ device: DeviceInfo) async throws -> Bool {
        guard let accessory = getAccessory(for: device),
              let powerChar = getPowerCharacteristic(for: accessory) else {
            throw HomeKitError.deviceNotFound
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            powerChar.readValue { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let isOn = powerChar.value as? Bool ?? false
                    continuation.resume(returning: isOn)
                }
            }
        }
    }

    // MARK: - Device Management

    #if !os(tvOS)
    func removeDevice(_ device: DeviceInfo) async throws {
        guard let home = home else {
            throw HomeKitError.noHomeSelected
        }

        guard let accessory = getAccessory(for: device) else {
            throw HomeKitError.deviceNotFound
        }

        NSLog("[HomeKitManager] Removing device: %@", device.name)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            home.removeAccessory(accessory) { error in
                if let error = error {
                    NSLog("[HomeKitManager] Failed to remove device: %@", error.localizedDescription)
                    continuation.resume(throwing: error)
                } else {
                    NSLog("[HomeKitManager] Successfully removed device: %@", device.name)
                    continuation.resume()
                }
            }
        }

        // Refresh the device list
        await refreshAll()
    }
    #endif

    // MARK: - Scene Control

    func getActionSet(for scene: SceneInfo) -> HMActionSet? {
        guard let home = home, let uuid = scene.actionSetUUID else { return nil }
        return home.actionSets.first { $0.uniqueIdentifier == uuid }
    }

    func executeScene(_ scene: SceneInfo) async throws {
        guard let home = home, let actionSet = getActionSet(for: scene) else {
            throw HomeKitError.sceneNotFound
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            home.executeActionSet(actionSet) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Summaries

    func getRoomSummaries() -> [RoomSummary] {
        let rooms = Set(devices.compactMap { $0.room })

        return rooms.map { roomName in
            let roomDevices = devices.filter { $0.room == roomName }
            return RoomSummary(
                name: roomName,
                totalDevices: roomDevices.count,
                healthyDevices: roomDevices.filter { $0.healthStatus == .healthy }.count,
                degradedDevices: roomDevices.filter { $0.healthStatus == .degraded }.count,
                unreachableDevices: roomDevices.filter { $0.healthStatus == .unreachable }.count
            )
        }.sorted { $0.name < $1.name }
    }

    func getManufacturerSummaries() -> [ManufacturerSummary] {
        let manufacturers = Set(devices.map { $0.manufacturer })

        return manufacturers.map { mfg in
            let mfgDevices = devices.filter { $0.manufacturer == mfg }
            let avgReliability = mfgDevices.isEmpty ? 0 : mfgDevices.map { $0.reliabilityScore }.reduce(0, +) / Double(mfgDevices.count)

            return ManufacturerSummary(
                manufacturer: mfg,
                deviceCount: mfgDevices.count,
                healthyCount: mfgDevices.filter { $0.healthStatus == .healthy }.count,
                degradedCount: mfgDevices.filter { $0.healthStatus == .degraded }.count,
                unreachableCount: mfgDevices.filter { $0.healthStatus == .unreachable }.count,
                averageReliability: avgReliability
            )
        }.sorted { $0.deviceCount > $1.deviceCount }
    }
}

// MARK: - HMHomeManagerDelegate

extension HomeKitManager: HMHomeManagerDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            homes = manager.homes
            isLoading = false

            if homes.isEmpty {
                errorMessage = "No homes found. Please set up a home in the Home app."
                isAuthorized = false
            } else {
                isAuthorized = true
                errorMessage = nil

                // Select primary home or first home
                if let primary = manager.primaryHome {
                    selectHome(primary)
                } else if let first = homes.first {
                    selectHome(first)
                }
            }

            NSLog("[HomeKitManager] Homes updated: %d homes found", homes.count)
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        Task { @MainActor in
            homes = manager.homes
            NSLog("[HomeKitManager] Home added: %@", home.name)
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        Task { @MainActor in
            homes = manager.homes
            if self.home?.uniqueIdentifier == home.uniqueIdentifier {
                self.home = homes.first
            }
            NSLog("[HomeKitManager] Home removed: %@", home.name)
        }
    }
}

// MARK: - Errors

enum HomeKitError: LocalizedError {
    case deviceNotFound
    case sceneNotFound
    case notReachable
    case unauthorized
    case noHomeSelected

    var errorDescription: String? {
        switch self {
        case .deviceNotFound: return "Device not found in HomeKit"
        case .sceneNotFound: return "Scene not found in HomeKit"
        case .notReachable: return "Device is not reachable"
        case .unauthorized: return "HomeKit access not authorized"
        case .noHomeSelected: return "No home selected"
        }
    }
}
