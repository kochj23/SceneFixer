//
//  DeviceTester.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import Foundation
import HomeKit
import Combine

/// Tests device connectivity and health using HomeKit
@MainActor
class DeviceTester: ObservableObject {
    static let shared = DeviceTester()

    // MARK: - Published Properties

    @Published var isTesting = false
    @Published var testProgress: Double = 0
    @Published var currentTestDevice = ""
    @Published var testResults: [DeviceTestResult] = []

    // MARK: - Private Properties

    private var homeKitManager: HomeKitManager { HomeKitManager.shared }

    // MARK: - Initialization

    private init() {}

    // MARK: - Health Check

    func runFullHealthCheck() async {
        guard !isTesting else { return }

        isTesting = true
        testProgress = 0
        testResults = []

        NSLog("[DeviceTester] Starting full health check on %d devices", homeKitManager.devices.count)

        let devices = homeKitManager.devices
        for (index, device) in devices.enumerated() {
            currentTestDevice = device.name
            testProgress = Double(index) / Double(devices.count)

            let result = await testDevice(device)
            testResults.append(result)

            // Small delay between tests
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        testProgress = 1.0
        currentTestDevice = ""
        isTesting = false

        NSLog("[DeviceTester] Health check complete. %d/%d devices passed",
              testResults.filter { $0.success }.count, testResults.count)
    }

    // MARK: - Single Device Test

    func testDevice(_ device: DeviceInfo) async -> DeviceTestResult {
        let startTime = Date()

        // Check if device is reachable via HomeKit
        guard let accessory = homeKitManager.getAccessory(for: device) else {
            return DeviceTestResult(
                success: false,
                responseTime: nil,
                errorMessage: "Device not found in HomeKit"
            )
        }

        // Try to read device state to verify connectivity
        do {
            let powerChar = homeKitManager.getPowerCharacteristic(for: accessory)

            if let char = powerChar {
                // Read the current value
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    char.readValue { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }

            let responseTime = Date().timeIntervalSince(startTime) * 1000 // ms
            let success = accessory.isReachable

            let result = DeviceTestResult(
                success: success,
                responseTime: responseTime,
                errorMessage: success ? nil : "Device not reachable"
            )

            // Update device in manager
            updateDeviceWithResult(device, result: result, isReachable: success)

            return result

        } catch {
            let responseTime = Date().timeIntervalSince(startTime) * 1000

            let result = DeviceTestResult(
                success: false,
                responseTime: responseTime,
                errorMessage: error.localizedDescription
            )

            updateDeviceWithResult(device, result: result, isReachable: false)

            return result
        }
    }

    private func updateDeviceWithResult(_ device: DeviceInfo, result: DeviceTestResult, isReachable: Bool) {
        if let index = homeKitManager.devices.firstIndex(where: { $0.id == device.id }) {
            homeKitManager.devices[index].testHistory.append(result)
            homeKitManager.devices[index].lastSeen = isReachable ? Date() : homeKitManager.devices[index].lastSeen
            homeKitManager.devices[index].isReachable = isReachable
            homeKitManager.devices[index].healthStatus = isReachable ? .healthy : .unreachable

            // Calculate average response time
            let times = homeKitManager.devices[index].testHistory.compactMap { $0.responseTime }
            if !times.isEmpty {
                homeKitManager.devices[index].averageResponseTime = times.reduce(0, +) / Double(times.count)
            }

            // Calculate reliability score
            let allTests = homeKitManager.devices[index].testHistory
            if !allTests.isEmpty {
                let successRate = Double(allTests.filter { $0.success }.count) / Double(allTests.count) * 100
                homeKitManager.devices[index].reliabilityScore = successRate
            }
        }
    }

    // MARK: - Toggle Test

    func testAllDevicesToggle() async -> [DeviceTestResult] {
        guard !isTesting else { return [] }

        isTesting = true
        testProgress = 0
        testResults = []

        let safeDevices = homeKitManager.devices.filter { !$0.category.isDangerous }

        NSLog("[DeviceTester] Starting toggle test on %d safe devices (excluding locks/garage doors)",
              safeDevices.count)

        for (index, device) in safeDevices.enumerated() {
            currentTestDevice = device.name
            testProgress = Double(index) / Double(safeDevices.count)

            let result = await toggleTest(device)
            testResults.append(result)

            try? await Task.sleep(nanoseconds: 500_000_000) // Wait between toggles
        }

        testProgress = 1.0
        currentTestDevice = ""
        isTesting = false

        return testResults
    }

    func toggleTest(_ device: DeviceInfo) async -> DeviceTestResult {
        guard !device.category.isDangerous else {
            NSLog("[DeviceTester] Skipping dangerous device: %@", device.name)
            return DeviceTestResult(
                success: false,
                errorMessage: "Skipped: dangerous device category"
            )
        }

        let startTime = Date()

        do {
            // Read current state
            let originalState = try await homeKitManager.readDeviceState(device)

            // Toggle on
            try await homeKitManager.toggleDevice(device, on: true)
            try await Task.sleep(nanoseconds: 300_000_000)

            // Toggle off
            try await homeKitManager.toggleDevice(device, on: false)
            try await Task.sleep(nanoseconds: 300_000_000)

            // Restore original state
            try await homeKitManager.toggleDevice(device, on: originalState)

            let responseTime = Date().timeIntervalSince(startTime) * 1000

            return DeviceTestResult(
                success: true,
                responseTime: responseTime,
                errorMessage: nil
            )

        } catch {
            let responseTime = Date().timeIntervalSince(startTime) * 1000

            return DeviceTestResult(
                success: false,
                responseTime: responseTime,
                errorMessage: error.localizedDescription
            )
        }
    }

    // MARK: - Helpers

    func updateDeviceHealth(_ device: DeviceInfo, isReachable: Bool, responseTime: Double?) {
        guard let index = homeKitManager.devices.firstIndex(where: { $0.id == device.id }) else { return }

        homeKitManager.devices[index].isReachable = isReachable
        homeKitManager.devices[index].lastSeen = isReachable ? Date() : homeKitManager.devices[index].lastSeen

        if isReachable {
            let history = homeKitManager.devices[index].testHistory
            let recentTests = history.suffix(10)
            let successCount = recentTests.filter { $0.success }.count

            if successCount == recentTests.count {
                homeKitManager.devices[index].healthStatus = .healthy
            } else if successCount >= recentTests.count / 2 {
                homeKitManager.devices[index].healthStatus = .degraded
            } else {
                homeKitManager.devices[index].healthStatus = .unreachable
            }
        } else {
            homeKitManager.devices[index].healthStatus = .unreachable
        }
    }
}
