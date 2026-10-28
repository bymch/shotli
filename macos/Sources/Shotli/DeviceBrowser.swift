import SwiftUI

struct DeviceBrowser: View {
    @ObservedObject var model: EditorModel
    var shot: CGImage?
    var onClose: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var query = ""
    @State private var category: DeviceCategory?
    @State private var extraID: String?

    private var ink: Color { ShotliGlass.ink(colorScheme) }
    private var devices: [DeviceSpec] { DeviceLibrary.matching(query, category: category) }

    var body: some View {
        GeometryReader { geo in
            let width = min(980, max(640, geo.size.width - 72))
            let height = min(760, max(520, geo.size.height - 72))
            ZStack {
                Color.black.opacity(colorScheme == .dark ? 0.45 : 0.22)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)
                VStack(alignment: .leading, spacing: 0) {
                    header
                    search
                        .padding(.horizontal, 22)
                        .padding(.bottom, 12)
                    categories
                        .padding(.bottom, 12)
                    catalogue
                }
                .frame(width: width, height: height)
                .shotliGlass(.panel, radius: ShotliGlass.radiusOverlay)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Devices")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ink)
                Text("The screenshot sits inside the screen.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 12)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ink)
                    .frame(width: 28, height: 28)
                    .shotliCapsuleChip()
            }
            .buttonStyle(PressFadeButtonStyle())
            .keyboardShortcut(.cancelAction)
            .help("Close")
            .accessibilityLabel("Close devices")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search model, category, or maker", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ShotliGlass.search(colorScheme)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(ShotliGlass.hairline(colorScheme), lineWidth: 1))
    }

    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, title: "All", symbol: "square.grid.2x2")
                ForEach(DeviceCategory.allCases) { item in
                    categoryChip(item, title: item.label, symbol: item.symbol)
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private func categoryChip(_ value: DeviceCategory?, title: String, symbol: String) -> some View {
        let selected = category == value
        return Button(action: { category = value }) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(selected ? ShotliGlass.accent : ink)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                Capsule().fill(selected ? ShotliGlass.accent.opacity(0.16) : ShotliGlass.quiet(colorScheme))
            )
            .overlay(
                Capsule().stroke(selected ? ShotliGlass.accent.opacity(0.7) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PressFadeButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : AccessibilityTraits())
    }

    @ViewBuilder
    private var catalogue: some View {
        if DeviceLibrary.all.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading devices…")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if devices.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.secondary)
                Text("No devices match that search.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ink)
                Text("Try a model name, or switch category.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 176, maximum: 220), spacing: 14)], spacing: 14) {
                    ForEach(devices) { device in
                        deviceCard(device)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
        }
    }

    private func deviceCard(_ device: DeviceSpec) -> some View {
        let selected = model.style.deviceID == device.id && model.style.frame == .none
        let finishID = chosenFinish(device)
        let shown = Array(device.finishes.prefix(3))
        let extra = Array(device.finishes.dropFirst(3))
        return VStack(alignment: .leading, spacing: 8) {
            Button(action: { model.setDevice(device.id, finish: finishID) }) {
                VStack(alignment: .leading, spacing: 8) {
                    preview(device, finishID: finishID)
                        .frame(height: 168)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04))
                        )
                    Text(device.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ink)
                        .lineLimit(1)
                    Text(device.resolution)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(device.name), \(device.category.label), \(device.resolution)")
            HStack(spacing: 6) {
                ForEach(shown) { finish in
                    finishSwatch(finish, device: device, selected: finish.id == finishID)
                }
                if !extra.isEmpty {
                    Button(action: { extraID = device.id }) {
                        Text("+\(extra.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(ink)
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(ShotliGlass.quiet(colorScheme)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(extra.count) more finishes")
                    .popover(isPresented: Binding(get: { extraID == device.id }, set: { if !$0 { extraID = nil } })) {
                        extraFinishes(device, finishes: extra, chosen: finishID)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ShotliGlass.surface(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? ShotliGlass.accent : ShotliGlass.hairline(colorScheme), lineWidth: selected ? 1.5 : 1)
        )
    }

    private func preview(_ device: DeviceSpec, finishID: String) -> some View {
        let image = DeviceLibrary.preview(device: device, finishID: finishID, shot: shot, size: CGSize(width: 180, height: 168))
        return Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .padding(8)
            .accessibilityHidden(true)
    }

    private func finishSwatch(_ finish: DeviceFinish, device: DeviceSpec, selected: Bool) -> some View {
        Button(action: { model.setDevice(device.id, finish: finish.id) }) {
            Circle()
                .fill(Color(nsColor: NSColor(hex: finish.body) ?? .gray))
                .frame(width: 16, height: 16)
                .padding(3)
                .overlay(Circle().stroke(selected ? ShotliGlass.accent : Color.primary.opacity(0.18), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .help(finish.name)
        .accessibilityLabel("\(finish.name) finish")
        .accessibilityAddTraits(selected ? .isSelected : AccessibilityTraits())
    }

    private func extraFinishes(_ device: DeviceSpec, finishes: [DeviceFinish], chosen: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Finishes")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ink)
            ForEach(finishes) { finish in
                Button(action: {
                    model.setDevice(device.id, finish: finish.id)
                    extraID = nil
                }) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(nsColor: NSColor(hex: finish.body) ?? .gray))
                            .frame(width: 14, height: 14)
                        Text(finish.name)
                            .font(.system(size: 12))
                            .foregroundColor(ink)
                        Spacer(minLength: 8)
                        if finish.id == chosen {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(ShotliGlass.accent)
                        }
                    }
                    .frame(width: 160, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(finish.name)
            }
        }
        .padding(12)
    }

    private func chosenFinish(_ device: DeviceSpec) -> String {
        if model.style.deviceID == device.id, let finish = model.style.deviceFinish, device.finishes.contains(where: { $0.id == finish }) {
            return finish
        }
        return device.finishes[0].id
    }
}
