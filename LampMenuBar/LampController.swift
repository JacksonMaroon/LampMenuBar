import Foundation
import SwiftUI

@MainActor
class LampController: ObservableObject {
    @Published var isOn: Bool = true
    @Published var brightness: Double = 100
    @Published var selectedColor: LampColor = .white

    private let lampScript = "/Users/jacksonmaroon/lamp"
    private var brightnessCommitTask: Task<Void, Never>?

    enum LampColor: String, CaseIterable {
        case white, yellow, red, pink, purple, blue

        var color: Color {
            switch self {
            case .white:
                return .white
            default:
                let hsv = hsv
                return Color(
                    hue: Double(hsv.h) / 180.0,
                    saturation: Double(hsv.s) / 100.0,
                    brightness: 1.0
                )
            }
        }

        var hsv: (h: Int, s: Int) {
            switch self {
            case .white: return (0, 0)
            case .red: return (0, 100)
            case .pink: return (165, 100)
            case .purple: return (135, 100)
            case .blue: return (120, 100)
            case .yellow: return (30, 100)
            }
        }

        var commandName: String {
            rawValue
        }
    }

    func togglePower() {
        brightnessCommitTask?.cancel()
        isOn.toggle()
        runLamp(isOn ? "on" : "off")
    }

    func setColor(_ color: LampColor) {
        brightnessCommitTask?.cancel()
        selectedColor = color
        isOn = true
        let hsv = color.hsv
        runLamp("hsv", "\(hsv.h)", "\(hsv.s)", "\(Int(brightness))")
    }

    func cancelPendingBrightnessCommit() {
        brightnessCommitTask?.cancel()
    }

    func commitBrightness(_ value: Double) {
        brightness = value
        brightnessCommitTask?.cancel()
        brightnessCommitTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            let hsv = selectedColor.hsv
            runLamp("hsv", "\(hsv.h)", "\(hsv.s)", "\(Int(brightness))")
        }
    }

    private func runLamp(_ args: String...) {
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/Users/jacksonmaroon/lamp")
            process.arguments = Array(args)
            try? process.run()
        }
    }
}
