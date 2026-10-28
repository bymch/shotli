import SwiftUI

struct DeviceBrowser: View {
    @ObservedObject var model: EditorModel
    var shot: CGImage?
    var onClose: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var category: DeviceCategory?
    @State private var extraID: String?

    private var ink: Color { ShotliGlass.ink(colorScheme) }
    private var devices: [DeviceSpec] { DeviceLibrary.matching("", category: category) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            categories
                .padding(.top, 16)
                .padding(.bottom, 12)
            catalogue
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .shotliGlass(.panel, radius: 22)
        .onExitCommand(perform: onClose)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Devices")
    }

    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, title: "All", symbol: "square.grid.2x2")
                ForEach(DeviceCategory.allCases) { item in
                    categoryChip(item, title: item.label, symbol: item.symbol)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func categoryChip(_ value: DeviceCategory?, title: String, symbol: String) -> some View {
        let selected = category == value
        return Button(action: { category = value }) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(selected ? ShotliGlass.selectedControlInk(colorScheme) : ink)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                Capsule().fill(selected ? ShotliGlass.selectedControl(colorScheme) : ShotliGlass.quiet(colorScheme))
            )
        }
        .buttonStyle(PressFadeButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : AccessibilityTraits())
    }

    private var catalogue: some View {
        ScrollView {
            if devices.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "ipad.and.iphone")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("No devices in this category.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ink)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 12)], spacing: 12) {
                    ForEach(devices) { device in
                        deviceCard(device)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func deviceCard(_ device: DeviceSpec) -> some View {
        let selected = model.style.deviceID == device.id && model.style.frame == .none
        let finishID = chosenFinish(device)
        let shown = extraID == device.id ? device.finishes : Array(device.finishes.prefix(3))
        let extra = Array(device.finishes.dropFirst(3))
        return VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                model.setDevice(device.id, finish: finishID)
                onClose()
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(device.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 6)
                        if device.isNew {
                            Text("New")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(colorScheme == .dark ? Color.white : Color.black))
                        }
                    }
                    Text(device.resolution)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    preview(device, finishID: finishID)
                        .frame(height: 148)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(device.name), \(device.resolution)")
            HStack(spacing: 6) {
                ForEach(shown) { finish in
                    finishSwatch(finish, device: device, selected: finish.id == finishID)
                }
                if !extra.isEmpty && extraID != device.id {
                    Button(action: { extraID = device.id }) {
                        Text("+\(extra.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(ink)
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(extra.count) more finishes")
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ShotliGlass.surface(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? ShotliGlass.accent : ShotliGlass.hairline(colorScheme), lineWidth: selected ? 1.5 : 1)
        )
    }

    private func preview(_ device: DeviceSpec, finishID: String) -> some View {
        let image = DeviceLibrary.preview(device: device, finishID: finishID, shot: shot, size: CGSize(width: 220, height: 148))
        return Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .padding(.horizontal, 4)
            .accessibilityHidden(true)
    }

    private func finishSwatch(_ finish: DeviceFinish, device: DeviceSpec, selected: Bool) -> some View {
        Button(action: { model.setDevice(device.id, finish: finish.id) }) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(nsColor: NSColor(hex: finish.body) ?? .gray))
                .frame(width: 16, height: 16)
                .padding(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(selected ? ShotliGlass.accent : Color.primary.opacity(0.18), lineWidth: selected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .help(finish.name)
        .accessibilityLabel("\(finish.name) finish")
        .accessibilityAddTraits(selected ? .isSelected : AccessibilityTraits())
    }

    private func chosenFinish(_ device: DeviceSpec) -> String {
        if model.style.deviceID == device.id, let finish = model.style.deviceFinish, device.finishes.contains(where: { $0.id == finish }) {
            return finish
        }
        return device.finishes[0].id
    }
}
