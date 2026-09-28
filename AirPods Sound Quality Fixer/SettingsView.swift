import SwiftUI

struct SettingsView: View {
  @Environment(\.openURL) private var openURL

  var body: some View {
    Form {
      Section {
        LaunchAtLoginToggle()
      }
      Section {
        LabeledContent("Version") {
          VStack(alignment: .trailing) {
            Text(Self.version)
            Button("Check for updates") {
              openURL(URL(string: "https://github.com/mAu888/airpodssoundqualityfixer/releases")!)
            }
          }
        }
        LabeledContent("Like the app?") {
          Button("Donate…") {
            openURL(URL(string: "https://paypal.me/mau888")!)
          }
        }
      }
    }
    .formStyle(.grouped)
    .scrollDisabled(true)
    .frame(width: 380)
    .fixedSize()
  }

  private static let version: String = {
    let info = Bundle.main.infoDictionary ?? [:]
    let shortVersion = info["CFBundleShortVersionString"] as? String ?? "?"
    let build = info["CFBundleVersion"] as? String ?? "?"
    return "\(shortVersion) (\(build))"
  }()
}
