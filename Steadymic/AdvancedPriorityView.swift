import AudioInputFixer
import SwiftUI

enum WindowIDs {
  static let advancedPriority = "advanced-priority"
}

/// Lets the user enable and configure a fallback chain of input devices: the fixer forces the first
/// connected device in the chain, falling back to the built-in microphone when none of them are.
struct AdvancedPriorityView: View {
  @Bindable var fixer: InputFixer
  @State private var selection: Set<String> = []

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Toggle("Use a fallback chain", isOn: $fixer.isPriorityEnabled)
        .font(.headline)
      Text(
        """
        Steadymic forces the default input to the first connected device below, falling back to \
        the built-in microphone when none of them are connected. Choosing a single input from \
        the menu turns the chain off and keeps this list.
        """
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)

      VStack(spacing: 0) {
        List(selection: $selection) {
          ForEach(priorityDevices) { device in
            Text(device.name)
              // Without this, only the text's glyph bounds are hit-tested, not the full row width.
              .contentShape(Rectangle())
          }
          .onMove { indices, newOffset in
            var uids = priorityDevices.map(\.uid)
            uids.move(fromOffsets: indices, toOffset: newOffset)
            fixer.setPriority(uids)
          }
          if let fallbackDevice {
            fallbackRow(fallbackDevice)
          }
        }
        .listStyle(.bordered)
        .alternatingRowBackgrounds()
        .frame(minHeight: 140)

        addRemoveControl
      }
      .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))
    }
    .padding()
    .frame(width: 380)
    .onAppear {
      // A fixed device becomes the list's starting point. The fallback row already shows the
      // built-in microphone, so adding it here would only duplicate that row.
      if fixer.priorityUIDs.isEmpty, let forcedDevice = fixer.forcedDevice, forcedDevice != fixer.fallbackDevice {
        fixer.appendToPriority(uid: forcedDevice.uid)
      }
      selection = selection.filter { uid in priorityDevices.contains { $0.uid == uid } }
    }
  }

  /// The classic bottom-left add/remove segmented control macOS list editors use, e.g. Login Items.
  private var addRemoveControl: some View {
    HStack(spacing: 0) {
      Menu {
        ForEach(availableDevices) { device in
          Button(device.name) {
            fixer.appendToPriority(uid: device.uid)
          }
        }
      } label: {
        Image(systemName: "plus")
          .frame(width: 24, height: 16)
          .contentShape(Rectangle())
      }
      .menuStyle(.button)
      .buttonStyle(.borderless)
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

  /// Sits outside the `ForEach`, so `onMove` neither drags it nor drops rows below it.
  private func fallbackRow(_ device: AudioDevice) -> some View {
    HStack {
      Text(device.name)
      Spacer()
      Text("(default)")
    }
    .foregroundStyle(.secondary)
    .contentShape(Rectangle())
    .selectionDisabled()
    .help("Used when no device above is connected. It cannot be moved or removed.")
  }

  /// `nil` when the user added the built-in microphone to the chain, since its row then already
  /// marks where the chain ends.
  private var fallbackDevice: AudioDevice? {
    fixer.fallbackDevice.flatMap { device in fixer.priorityUIDs.contains(device.uid) ? nil : device }
  }

  private var priorityDevices: [AudioDevice] {
    fixer.priorityUIDs.compactMap { uid in fixer.devices.first { $0.uid == uid } }
  }

  private var availableDevices: [AudioDevice] {
    let priorityUIDs = Set(fixer.priorityUIDs)
    return fixer.devices.filter { !priorityUIDs.contains($0.uid) }
  }
}
