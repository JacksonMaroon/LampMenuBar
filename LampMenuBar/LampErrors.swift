import Foundation

enum LampError: LocalizedError {
    case bluetoothUnavailable
    case bluetoothUnauthorized
    case deviceNotSelected
    case deviceNotFound
    case connectionFailed
    case serviceNotFound
    case characteristicNotFound
    case timeout

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is unavailable or powered off."
        case .bluetoothUnauthorized:
            return "Bluetooth access is not authorized."
        case .deviceNotSelected:
            return "No lamp selected. Open the app and select your lamp first."
        case .deviceNotFound:
            return "Saved lamp not found. Make sure it is nearby and powered on."
        case .connectionFailed:
            return "Failed to connect to the lamp."
        case .serviceNotFound:
            return "Lamp service not found on the device."
        case .characteristicNotFound:
            return "Lamp control characteristic not found."
        case .timeout:
            return "Bluetooth operation timed out."
        }
    }
}
