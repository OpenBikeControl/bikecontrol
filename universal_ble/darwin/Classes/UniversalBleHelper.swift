//
//  UniversalBleHelper.swift
//  universal_ble
//
//  Created by Rohit Sangwan on 25/10/23.
//

import CoreBluetooth
import Foundation
#if os(iOS)
    import Flutter
#elseif os(OSX)
    import FlutterMacOS
#endif

enum BleInputProperty: Int {
    case disabled = 0
    case notification = 1
    case indication = 2
}

enum BleOutputProperty: Int {
    case withResponse = 0
    case withoutResponse = 1
}

enum BlueConnectionState: Int64 {
    case connected = 0
    case disconnected = 1
    case connecting = 2
    case disconnecting = 3
}

enum AvailabilityState: Int64 {
    case unknown = 0
    case resetting = 1
    case unsupported = 2
    case unauthorized = 3
    case poweredOff = 4
    case poweredOn = 5
}

enum CharacteristicProperty: Int64 {
    case broadcast = 0
    case read = 1
    case writeWithoutResponse = 2
    case write = 3
    case notify = 4
    case indicate = 5
    case authenticatedSignedWrites = 6
    case extendedProperties = 7
}

extension CBCharacteristicProperties {
    var toCharacteristicProperty: [Int64] {
        var properties = [Int64]()
        if contains(.broadcast) {
            properties.append(CharacteristicProperty.broadcast.rawValue)
        }
        if contains(.read) {
            properties.append(CharacteristicProperty.read.rawValue)
        }
        if contains(.writeWithoutResponse) {
            properties.append(CharacteristicProperty.writeWithoutResponse.rawValue)
        }
        if contains(.write) {
            properties.append(CharacteristicProperty.write.rawValue)
        }
        if contains(.notify) {
            properties.append(CharacteristicProperty.notify.rawValue)
        }
        if contains(.indicate) {
            properties.append(CharacteristicProperty.indicate.rawValue)
        }
        if contains(.authenticatedSignedWrites) {
            properties.append(CharacteristicProperty.authenticatedSignedWrites.rawValue)
        }
        if contains(.extendedProperties) {
            properties.append(CharacteristicProperty.extendedProperties.rawValue)
        }
        return properties
    }
}

extension CBManagerState {
    func toAvailabilityState() -> AvailabilityState {
        switch self {
        case .unknown:
            return AvailabilityState.unknown
        case .resetting:
            return AvailabilityState.resetting
        case .unsupported:
            return AvailabilityState.unsupported
        case .unauthorized:
            return AvailabilityState.unauthorized
        case .poweredOff:
            return AvailabilityState.poweredOff
        case .poweredOn:
            return AvailabilityState.poweredOn
        @unknown default:
            return AvailabilityState.unknown
        }
    }
}

extension Error {
    func toPigeonError() -> PigeonError {
        let nsError = self as NSError
        let errorCode: String = .init(nsError.code)
        let errorDescription: String = nsError.localizedDescription
        return PigeonError(code: errorCode, message: errorDescription, details: nil)
    }
}

public extension CBUUID {
    var uuidStr: String {
        uuidString.lowercased()
    }
}

public extension CBPeripheral {
    // FIXME: https://forums.developer.apple.com/thread/84375
    var uuid: UUID {
        value(forKey: "identifier") as! NSUUID as UUID
    }

    func getCharacteristic(_ characteristic: String, of service: String) -> CBCharacteristic? {
        let GSS_SUFFIX = "0000-1000-8000-00805f9b34fb"
        let s = services?.first {
            $0.uuid.uuidStr.lowercased() == service.lowercased() || service.lowercased() == "0000\($0.uuid.uuidStr)-\(GSS_SUFFIX)".lowercased()
        }
        let c = s?.characteristics?.first {
            $0.uuid.uuidStr.lowercased() == characteristic.lowercased() || characteristic.lowercased() == "0000\($0.uuid.uuidStr)-\(GSS_SUFFIX)".lowercased()
        }
        return c
    }

    func setNotifiable(_ bleInputProperty: String, for characteristic: String, of service: String) {
        guard let characteristic = getCharacteristic(characteristic, of: service) else {
            return
        }
        setNotifyValue(bleInputProperty != "disabled", for: characteristic)
    }
}

extension FlutterStandardTypedData {
    func toData() -> Data {
        return Data(data)
    }
}

// Future classes
class CharacteristicReadFuture {
    let deviceId: String
    let characteristicId: String
    let serviceId: String?
    let result: (Result<FlutterStandardTypedData, Error>) -> Void

    init(deviceId: String, characteristicId: String, serviceId: String?, result: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
        self.deviceId = deviceId
        self.characteristicId = characteristicId
        self.serviceId = serviceId
        self.result = result
    }
}

class CharacteristicWriteFuture {
    let deviceId: String
    let characteristicId: String
    let serviceId: String?
    let result: (Result<Void, Error>) -> Void

    init(deviceId: String, characteristicId: String, serviceId: String?, result: @escaping (Result<Void, Error>) -> Void) {
        self.deviceId = deviceId
        self.characteristicId = characteristicId
        self.serviceId = serviceId
        self.result = result
    }
}

class CharacteristicNotifyFuture {
    let deviceId: String
    let characteristicId: String
    let serviceId: String?
    let result: (Result<Void, Error>) -> Void

    init(deviceId: String, characteristicId: String, serviceId: String?, result: @escaping (Result<Void, Error>) -> Void) {
        self.deviceId = deviceId
        self.characteristicId = characteristicId
        self.serviceId = serviceId
        self.result = result
    }
}

class DiscoverServicesFuture {
    let deviceId: String
    let result: (Result<[UniversalBleService], Error>) -> Void

    init(deviceId: String, result: @escaping (Result<[UniversalBleService], Error>) -> Void) {
        self.deviceId = deviceId
        self.result = result
    }
}
