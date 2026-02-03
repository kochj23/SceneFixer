//
//  DeviceModels.swift
//  SceneFixer
//
//  Created by Jordan Koch on 2/2/26.
//

import Foundation
import HomeKit

// MARK: - Enums

enum DeviceHealthStatus: String, CaseIterable, Codable {
    case healthy = "Healthy"
    case degraded = "Degraded"
    case unreachable = "Unreachable"
    case unknown = "Unknown"
    case testing = "Testing"
}

enum DeviceProtocol: String, CaseIterable, Codable {
    case wifi = "WiFi"
    case zigbee = "Zigbee"
    case zwave = "Z-Wave"
    case bluetooth = "Bluetooth"
    case thread = "Thread"
    case matter = "Matter"
    case unknown = "Unknown"
}

enum DeviceManufacturer: String, CaseIterable, Codable {
    case philipsHue = "Philips Hue"
    case lutron = "Lutron"
    case ikea = "IKEA"
    case nanoleaf = "Nanoleaf"
    case ecobee = "ecobee"
    case schlage = "Schlage"
    case yale = "Yale"
    case august = "August"
    case eve = "Eve"
    case lifx = "LIFX"
    case wemo = "Wemo"
    case tp_link = "TP-Link"
    case meross = "Meross"
    case aqara = "Aqara"
    case sonos = "Sonos"
    case apple = "Apple"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .philipsHue: return "lightbulb.led.fill"
        case .lutron: return "light.recessed"
        case .ikea: return "lamp.floor.fill"
        case .nanoleaf: return "square.grid.3x3.fill"
        case .ecobee: return "thermometer"
        case .schlage, .yale, .august: return "lock.fill"
        case .eve: return "sensor.fill"
        case .lifx: return "lightbulb.fill"
        case .wemo: return "poweroutlet.type.b.fill"
        case .tp_link: return "wifi"
        case .meross: return "powerplug.fill"
        case .aqara: return "sensor.fill"
        case .sonos: return "hifispeaker.fill"
        case .apple: return "applelogo"
        case .unknown: return "questionmark.circle"
        }
    }

    static func from(manufacturer: String?) -> DeviceManufacturer {
        guard let mfg = manufacturer?.lowercased() else { return .unknown }

        if mfg.contains("philips") || mfg.contains("hue") || mfg.contains("signify") {
            return .philipsHue
        } else if mfg.contains("lutron") {
            return .lutron
        } else if mfg.contains("ikea") || mfg.contains("tradfri") {
            return .ikea
        } else if mfg.contains("nanoleaf") {
            return .nanoleaf
        } else if mfg.contains("ecobee") {
            return .ecobee
        } else if mfg.contains("schlage") {
            return .schlage
        } else if mfg.contains("yale") {
            return .yale
        } else if mfg.contains("august") {
            return .august
        } else if mfg.contains("eve") || mfg.contains("elgato") {
            return .eve
        } else if mfg.contains("lifx") {
            return .lifx
        } else if mfg.contains("wemo") || mfg.contains("belkin") {
            return .wemo
        } else if mfg.contains("tp-link") || mfg.contains("kasa") {
            return .tp_link
        } else if mfg.contains("meross") {
            return .meross
        } else if mfg.contains("aqara") || mfg.contains("xiaomi") || mfg.contains("lumi") {
            return .aqara
        } else if mfg.contains("sonos") {
            return .sonos
        } else if mfg.contains("apple") {
            return .apple
        }

        return .unknown
    }
}

enum DeviceCategory: String, CaseIterable, Codable {
    case light = "Light"
    case switchDevice = "Switch"
    case outlet = "Outlet"
    case thermostat = "Thermostat"
    case lock = "Lock"
    case garageDoor = "Garage Door"
    case sensor = "Sensor"
    case camera = "Camera"
    case doorbell = "Doorbell"
    case speaker = "Speaker"
    case fan = "Fan"
    case blind = "Blind"
    case other = "Other"

    var icon: String {
        switch self {
        case .light: return "lightbulb.fill"
        case .switchDevice: return "switch.2"
        case .outlet: return "poweroutlet.type.b.fill"
        case .thermostat: return "thermometer"
        case .lock: return "lock.fill"
        case .garageDoor: return "door.garage.closed"
        case .sensor: return "sensor.fill"
        case .camera: return "video.fill"
        case .doorbell: return "bell.fill"
        case .speaker: return "hifispeaker.fill"
        case .fan: return "fan.fill"
        case .blind: return "blinds.vertical.closed"
        case .other: return "shippingbox.fill"
        }
    }

    var isDangerous: Bool {
        switch self {
        case .lock, .garageDoor:
            return true
        default:
            return false
        }
    }

    static func from(category: HMAccessoryCategory) -> DeviceCategory {
        switch category.categoryType {
        case HMAccessoryCategoryTypeLightbulb:
            return .light
        case HMAccessoryCategoryTypeSwitch:
            return .switchDevice
        case HMAccessoryCategoryTypeOutlet:
            return .outlet
        case HMAccessoryCategoryTypeThermostat:
            return .thermostat
        case HMAccessoryCategoryTypeDoorLock:
            return .lock
        case HMAccessoryCategoryTypeGarageDoorOpener:
            return .garageDoor
        case HMAccessoryCategoryTypeSensor:
            return .sensor
        case HMAccessoryCategoryTypeIPCamera, HMAccessoryCategoryTypeVideoDoorbell:
            return .camera
        case HMAccessoryCategoryTypeFan:
            return .fan
        case HMAccessoryCategoryTypeWindowCovering:
            return .blind
        default:
            return .other
        }
    }
}

// MARK: - Device Info

struct DeviceInfo: Identifiable, Hashable {
    let id: UUID
    var name: String
    var room: String?
    var manufacturer: DeviceManufacturer
    var category: DeviceCategory
    var protocolType: DeviceProtocol
    var model: String?
    var firmwareVersion: String?
    var serialNumber: String?

    // HomeKit reference
    var accessoryUUID: UUID?

    // Health tracking
    var healthStatus: DeviceHealthStatus = .unknown
    var isReachable: Bool = true
    var reliabilityScore: Double = 100.0
    var lastSeen: Date?
    var averageResponseTime: Double?

    // Scene membership
    var sceneCount: Int = 0
    var sceneNames: [String] = []

    // Hub info
    var hubName: String?

    // Test history
    var testHistory: [DeviceTestResult] = []

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DeviceInfo, rhs: DeviceInfo) -> Bool {
        lhs.id == rhs.id
    }

    static func from(accessory: HMAccessory, room: HMRoom?) -> DeviceInfo {
        var info = DeviceInfo(
            id: UUID(),
            name: accessory.name,
            room: room?.name,
            manufacturer: DeviceManufacturer.from(manufacturer: accessory.manufacturer),
            category: DeviceCategory.from(category: accessory.category),
            protocolType: .unknown,
            model: accessory.model,
            firmwareVersion: accessory.firmwareVersion,
            serialNumber: nil,
            accessoryUUID: accessory.uniqueIdentifier,
            healthStatus: accessory.isReachable ? .healthy : .unreachable,
            isReachable: accessory.isReachable
        )

        // Detect protocol from manufacturer/model
        let mfgLower = accessory.manufacturer?.lowercased() ?? ""
        if mfgLower.contains("hue") || mfgLower.contains("ikea") || mfgLower.contains("aqara") {
            info.protocolType = DeviceProtocol.zigbee
        } else if mfgLower.contains("eve") {
            info.protocolType = DeviceProtocol.thread
        } else if mfgLower.contains("lifx") || mfgLower.contains("nanoleaf") || mfgLower.contains("meross") {
            info.protocolType = DeviceProtocol.wifi
        }

        return info
    }
}

// MARK: - Test Result

struct DeviceTestResult: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let success: Bool
    let responseTime: Double?
    let errorMessage: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), success: Bool, responseTime: Double? = nil, errorMessage: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.success = success
        self.responseTime = responseTime
        self.errorMessage = errorMessage
    }
}

// MARK: - Room Summary

struct RoomSummary: Identifiable, Hashable {
    let id: UUID
    let name: String
    var totalDevices: Int
    var healthyDevices: Int
    var degradedDevices: Int
    var unreachableDevices: Int

    init(id: UUID = UUID(), name: String, totalDevices: Int = 0, healthyDevices: Int = 0, degradedDevices: Int = 0, unreachableDevices: Int = 0) {
        self.id = id
        self.name = name
        self.totalDevices = totalDevices
        self.healthyDevices = healthyDevices
        self.degradedDevices = degradedDevices
        self.unreachableDevices = unreachableDevices
    }
}

// MARK: - Manufacturer Summary

struct ManufacturerSummary: Identifiable, Hashable {
    let id: UUID
    let manufacturer: DeviceManufacturer
    var deviceCount: Int
    var healthyCount: Int
    var degradedCount: Int
    var unreachableCount: Int
    var averageReliability: Double

    init(id: UUID = UUID(), manufacturer: DeviceManufacturer, deviceCount: Int = 0, healthyCount: Int = 0, degradedCount: Int = 0, unreachableCount: Int = 0, averageReliability: Double = 100.0) {
        self.id = id
        self.manufacturer = manufacturer
        self.deviceCount = deviceCount
        self.healthyCount = healthyCount
        self.degradedCount = degradedCount
        self.unreachableCount = unreachableCount
        self.averageReliability = averageReliability
    }
}
