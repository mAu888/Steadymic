import ServiceManagement
import SwiftUI
import os

private let logger = Logger(subsystem: "com.milgra.asqf", category: "LaunchAtLoginToggle")

struct LaunchAtLoginToggle: View {
  @State private var isEnabled = Self.isRegistered

  var body: some View {
    Toggle("Open at login", isOn: Binding(get: { isEnabled }, set: setEnabled))
      // The login item can also change in System Settings while the app runs. MenuBarExtra keeps
      // its NSMenu between openings, so onAppear does not run on every open.
      .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
        isEnabled = Self.isRegistered
      }
  }

  private func setEnabled(_ enabled: Bool) {
    let service = SMAppService.mainApp
    do {
      if enabled {
        try service.register()
      } else {
        try service.unregister()
      }
    } catch {
      logger.error("Updating login item failed: \(error, privacy: .public)")
    }
    if service.status == .requiresApproval {
      SMAppService.openSystemSettingsLoginItems()
    }
    isEnabled = Self.isRegistered
  }

  private static var isRegistered: Bool {
    SMAppService.mainApp.status == .enabled
  }
}
