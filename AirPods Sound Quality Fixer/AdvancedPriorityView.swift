import AudioInputFixer
import SwiftUI

enum WindowIDs {
  static let advancedPriority = "advanced-priority"
}

/// Lets the user configure an ordered list of preferred input devices: the fixer forces the first
/// connected device in the list, falling back to the built-in microphone when none of them are.
struct AdvancedPriorityView: View {
  @Bindable var fixer: InputFixer
  @State private var selection: Set<String> = []

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Preferred input devices")
        .font(.headline)
      Text(
        "The fixer forces the default input to the first connected device below, falling back to "
          + "the built-in microphone when none of them are connected."
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)

      VStack(spacing: 0) {
        List(selection: $selection) {
          // Identified by `uid`, not the default `Identifiable.id` (`AudioDeviceID`), which can
          // change across reconnects and would desync row identity from the selection above.
          ForEach(priorityDevices, id: \.uid) { device in
            Text(device.name)
              // Without this, only the text's glyph bounds are hit-tested, not the full row width.
              .contentShape(Rectangle())
          }
          .onMove { indices, newOffset in
            var uids = priorityDevices.map(\.uid)
            uids.move(fromOffsets: indices, toOffset: newOffset)
            fixer.setPriority(uids)
          }
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        .frame(minHeight: 140)

        addRemoveControl
      }
      .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))
    }
    .padding()
    .frame(width: 380)
    .onAppear {
      // A single device already forced, e.g. the built-in fallback with nothing configured yet,
      // becomes the list's starting point instead of showing an empty list.
      if fixer.priorityUIDs.isEmpty, let forcedDevice = fixer.forcedDevice {
        fixer.select(uid: forcedDevice.uid)
      }
      selection = selection.filter { uid in priorityDevices.contains { $0.uid == uid } }
    }
  }

  /// The classic bottom-left add/remove segmented control macOS list editors use, e.g. Login Items.
  private var addRemoveControl: some View {
    HStack(spacing: 0) {
      Menu {
        ForEach(availableDevices, id: \.uid) { device in
          Button(device.name) {
            fixer.appendToPriority(uid: device.uid)
          }
        }
      } label: {
        Image(systemName: "plus")
          .frame(width: 24, height: 16)
          .contentShape(Rectangle())
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .disabled(availableDevices.isEmpty)

      Divider().frame(height: 12)

      Button {
        for uid in selection { fixer.removeFromPriority(uid: uid) }
        selection.removeAll()
      } label: {
        Image(systemName: "minus")
          .frame(width: 24, height: 16)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(selection.isEmpty)

      Spacer()
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 3)
    .background(Color(nsColor: .controlBackgroundColor))
  }

  private var priorityDevices: [AudioDevice] {
    fixer.priorityUIDs.compactMap { uid in fixer.devices.first { $0.uid == uid } }
  }

  private var availableDevices: [AudioDevice] {
    let priorityUIDs = Set(fixer.priorityUIDs)
    return fixer.devices.filter { !priorityUIDs.contains($0.uid) }
  }
}
