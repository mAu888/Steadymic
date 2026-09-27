import AudioInputFixer
import SwiftUI

@main
struct AirPodsSoundQualityFixerApp: App {
  @State private var fixer: InputFixer
  @State private var isIconVisible = true
  // Kept alive here: UNUserNotificationCenter.delegate does not retain its delegate.
  private let overrideNotificationCenter: OverrideNotificationCenter

  init() {
    let fixer = InputFixer(hardware: CoreAudioHardware())
    overrideNotificationCenter = OverrideNotificationCenter(fixer: fixer)
    fixer.notifier = overrideNotificationCenter
    // Forcing has to begin at launch, not when the menu is first opened.
    fixer.start()
    _fixer = State(initialValue: fixer)
  }

  var body: some Scene {
    MenuBarExtra(isInserted: $isIconVisible) {
      MenuContent(fixer: fixer, isIconVisible: $isIconVisible)
    } label: {
      Image(.menuBarIcon)
        .help("AirPods Audio Quality & Battery Life Fixer")
    }
  }
}
