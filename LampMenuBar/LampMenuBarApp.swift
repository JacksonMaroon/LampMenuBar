import SwiftUI

@main
struct LampMenuBarApp: App {
    @StateObject private var lampController = LampController()

    var body: some Scene {
        MenuBarExtra {
            LampPopoverView(controller: lampController)
        } label: {
            Image(systemName: lampController.isOn ? "lightbulb.fill" : "lightbulb")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(lampController.isOn ? .yellow : .secondary)
        }
        .menuBarExtraStyle(.window)
    }
}
