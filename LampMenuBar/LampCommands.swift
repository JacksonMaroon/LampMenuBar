import Foundation
import AppIntents

enum LampColor: String, CaseIterable, AppEnum {
    case red
    case orange
    case yellow
    case green
    case cyan
    case blue
    case purple
    case pink
    case magenta
    case white
    case warm
    case cool

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Lamp Color"
    }

    static var caseDisplayRepresentations: [LampColor: DisplayRepresentation] {
        [
            .red: .init(title: "Red"),
            .orange: .init(title: "Orange"),
            .yellow: .init(title: "Yellow"),
            .green: .init(title: "Green"),
            .cyan: .init(title: "Cyan"),
            .blue: .init(title: "Blue"),
            .purple: .init(title: "Purple"),
            .pink: .init(title: "Pink"),
            .magenta: .init(title: "Magenta"),
            .white: .init(title: "White"),
            .warm: .init(title: "Warm"),
            .cool: .init(title: "Cool")
        ]
    }

    var hsv: (h: Int, s: Int, v: Int) {
        switch self {
        case .red:
            return (0, 100, 100)
        case .orange:
            return (15, 100, 100)
        case .yellow:
            return (30, 100, 100)
        case .green:
            return (60, 100, 100)
        case .cyan:
            return (90, 100, 100)
        case .blue:
            return (120, 100, 100)
        case .purple:
            return (135, 100, 100)
        case .pink:
            return (165, 100, 100)
        case .magenta:
            return (150, 100, 100)
        case .white:
            return (0, 0, 100)
        case .warm:
            return (15, 30, 100)
        case .cool:
            return (120, 10, 100)
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

struct LampCommands {
    static func power(on: Bool) -> Data {
        let state: UInt8 = on ? 0x23 : 0x24
        return Data([
            0x00, 0x04, 0x80, 0x00, 0x00, 0x0d, 0x0e, 0x0b, 0x3b, state,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x32, 0x00, 0x00, 0x90
        ])
    }

    static func color(h: Int, s: Int, v: Int) -> Data {
        return Data([
            0x00, 0x05, 0x80, 0x00, 0x00, 0x0d, 0x0e, 0x0b, 0x3b, 0xa1,
            UInt8(clamp(h, min: 0, max: 180)),
            UInt8(clamp(s, min: 0, max: 100)),
            UInt8(clamp(v, min: 0, max: 100)),
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ])
    }

    static func brightness(_ level: Int) -> Data {
        let value = clamp(level, min: 0, max: 100)
        return color(h: 0, s: 0, v: value)
    }

    static func rgbToHSV(r: Int, g: Int, b: Int) -> (h: Int, s: Int, v: Int) {
        let rVal = Double(clamp(r, min: 0, max: 255)) / 255.0
        let gVal = Double(clamp(g, min: 0, max: 255)) / 255.0
        let bVal = Double(clamp(b, min: 0, max: 255)) / 255.0

        let maxC = max(rVal, gVal, bVal)
        let minC = min(rVal, gVal, bVal)
        let delta = maxC - minC

        var h: Double = 0
        if delta == 0 {
            h = 0
        } else if maxC == rVal {
            h = 60 * fmod(((gVal - bVal) / delta), 6)
        } else if maxC == gVal {
            h = 60 * (((bVal - rVal) / delta) + 2)
        } else {
            h = 60 * (((rVal - gVal) / delta) + 4)
        }
        if h < 0 { h += 360 }

        let s: Double = maxC == 0 ? 0 : delta / maxC
        let v: Double = maxC

        let hByte = Int(h / 2)
        let sByte = Int(s * 100)
        let vByte = Int(v * 100)
        return (hByte, sByte, vByte)
    }

    private static func clamp(_ value: Int, min: Int, max: Int) -> Int {
        if value < min { return min }
        if value > max { return max }
        return value
    }
}
