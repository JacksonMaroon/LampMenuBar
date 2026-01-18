import Foundation
import SwiftUI

@MainActor
class LampController: ObservableObject {
    @Published var isOn: Bool = true
    @Published var brightness: Double = 100
    @Published var selectedColor: LampColor = .white

    private let lampScript = "/Users/jacksonmaroon/lamp"

    enum LampColor: String, CaseIterable {
        case white, red, pink, purple, blue, cyan, green, yellow

        var color: Color {
            switch self {
            case .white: return .white
            case .red: return .red
            case .pink: return .pink
            case .purple: return .purple
            case .blue: return .blue
            case .cyan: return .cyan
            case .green: return .green
            case .yellow: return .yellow
            }
        }

        var commandName: String {
            rawValue
        }
    }

    func togglePower() {
        isOn.toggle()
        runLamp(isOn ? "on" : "off")
    }

    func setColor(_ color: LampColor) {
        selectedColor = color
        isOn = true
        runLamp(color.commandName)
    }

    func setBrightness(_ value: Double) {
        brightness = value
        runLamp("bright", "\(Int(value))")
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
