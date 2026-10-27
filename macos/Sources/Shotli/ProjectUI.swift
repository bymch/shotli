import AppKit
import SwiftUI

final class ProjectPrompt: ObservableObject {
    static let shared = ProjectPrompt()

    @Published var naming = false
    @Published var draft = ""
    @Published var issue: String?
    private var onCommit: ((URL) -> Void)?
    private var excluding: URL?

    var canCreate: Bool {
        ProjectStore.validationError(for: draft, excluding: excluding) == nil
    }

    func ask(excluding: URL? = nil, onCommit: @escaping (URL) -> Void) {
        self.excluding = excluding
        self.onCommit = onCommit
        draft = ProjectStore.suggestedName()
        issue = ProjectStore.validationError(for: draft, excluding: excluding)
        naming = true
    }

    func cancel() {
        naming = false
        onCommit = nil
    }

    func updateDraft(_ value: String) {
        if draft != value { draft = value }
        let next = ProjectStore.validationError(for: value, excluding: excluding)
        if next != issue { issue = next }
    }

    func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let issue = ProjectStore.validationError(for: trimmed, excluding: excluding) {
            self.issue = issue
            return
        }
        do {
            let folder = try ProjectStore.create(name: trimmed)
            let callback = onCommit
            onCommit = nil
            naming = false
            callback?(folder)
            LibraryModel.shared.refresh()
        } catch {
            issue = error.localizedDescription
        }
    }
}

struct NewProjectSheet: View {
    @ObservedObject var prompt: ProjectPrompt
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Project")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ShotliGlass.ink)
                Text("Shotli creates a folder in \(ShotliProjects.displayRoot) after you confirm. Cancel leaves the disk alone.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("Project name", text: Binding(get: { prompt.draft }, set: { prompt.updateDraft($0) }))
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { if prompt.canCreate { prompt.commit() } }
            if let issue = prompt.issue {
                Text(issue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(nsColor: NSColor(hex: "#C13636")!))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button("Cancel") { prompt.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Create Project") { prompt.commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!prompt.canCreate)
            }
        }
        .padding(22)
        .frame(width: 440)
        .background(ShotliWorkspaceWash())
        .onAppear { focused = true }
    }
}

struct SaveProjectPopover: View {
    @ObservedObject var model: EditorModel
    @State private var query = ""
    @State private var projects: [ProjectRecord] = []
    @State private var hoveredID: String?

    private var filtered: [ProjectRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matched = needle.isEmpty ? projects : projects.filter { $0.name.lowercased().contains(needle) }
        return matched.sorted { $0.modified > $1.modified }
    }

    private var saving: Bool { model.popoverSave.isSaving }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Save to Project")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Saves the composition and a copy of the screenshot. Export and Copy are unchanged.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let status = statusLine {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: status.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(status.isError ? Color(nsColor: .systemRed) : ShotliGlass.accent)
                    Text(status.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(status.isError ? Color(nsColor: .systemRed) : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("Search projects", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .shotliGlass(.compact, radius: 10, shadow: false)
            GeometryReader { geo in
                ScrollView {
                    if filtered.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(projects.isEmpty ? "No projects yet" : "Nothing matches “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            if projects.isEmpty {
                                Text("Create a project and this screenshot is saved into it.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(width: geo.size.width, alignment: .leading)
                        .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(filtered) { project in
                                projectRow(project)
                                    .frame(width: geo.size.width, alignment: .leading)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            Button(action: create) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Create New Project")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Capsule().fill(ShotliGlass.accent))
            }
            .buttonStyle(PressFadeButtonStyle())
            .disabled(saving)
            .opacity(saving ? 0.5 : 1)
            .help("Name a project, then save this screenshot into it")
            .accessibilityLabel("Create New Project")
        }
        .padding(16)
        .frame(width: 340, height: 460)
        .onAppear { projects = ProjectStore.list() }
        .onChange(of: model.showSaveProjects) { shown in
            if shown {
                projects = ProjectStore.list()
                return
            }
            if model.popoverSave.isSaving {
                model.showSaveProjects = true
                return
            }
            model.notePopoverClosed()
        }
        .onChange(of: model.popoverSave.phase) { _ in
            projects = ProjectStore.list()
        }
    }

    private var statusLine: (symbol: String, text: String, isError: Bool)? {
        switch model.popoverSave.phase {
        case .success(_, let name):
            return ("checkmark.circle.fill", "Saved to \(name)", false)
        case .failure(_, let message):
            return ("exclamationmark.triangle.fill", message, true)
        default:
            return nil
        }
    }

    private func projectRow(_ project: ProjectRecord) -> some View {
        let active = model.popoverSave.phase.savingID == project.id
        return Button(action: { model.saveCurrent(into: project.folder, recordID: project.id) }) {
            HStack(alignment: .center, spacing: 10) {
                thumbnail(project)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(detail(project))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                rowMarker(savingThis: active, savedThis: saved(project))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(SaveRowStyle(hovered: hoveredID == project.id))
        .disabled(saving)
        .opacity(saving && !active ? 0.45 : 1)
        .onHover { inside in
            if inside {
                hoveredID = project.id
            } else if hoveredID == project.id {
                hoveredID = nil
            }
        }
        .help("Save to \(project.name)")
        .accessibilityLabel("\(project.name), \(detail(project))")
        .accessibilityHint("Saves the current composition into this project")
    }

    private func saved(_ project: ProjectRecord) -> Bool {
        if case .success(let id, _) = model.popoverSave.phase { return id == project.id }
        return false
    }

    private func rowMarker(savingThis: Bool, savedThis: Bool) -> some View {
        Group {
            if savingThis {
                ProgressView()
                    .controlSize(.small)
            } else if savedThis {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(ShotliGlass.accent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }

    private func thumbnail(_ project: ProjectRecord) -> some View {
        Color.clear
            .frame(width: 48, height: 36)
            .overlay(thumbnailImage(project))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func thumbnailImage(_ project: ProjectRecord) -> some View {
        if let url = project.thumbnail, let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 36)
        } else {
            ZStack {
                Color.primary.opacity(0.06)
                Image(systemName: "photo")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .frame(width: 48, height: 36)
        }
    }

    private func detail(_ project: ProjectRecord) -> String {
        let count = project.compositions
        let noun = count == 1 ? "composition" : "compositions"
        return "\(count) \(noun)"
    }

    private func create() {
        guard !saving else { return }
        model.showSaveProjects = false
        DispatchQueue.main.async {
            ProjectPrompt.shared.ask { folder in
                model.saveCurrent(into: folder, removeFolderOnFailure: true)
            }
        }
    }
}

private struct SaveRowStyle: ButtonStyle {
    var hovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill(pressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(configuration.isPressed || hovered ? 0.14 : 0.06), lineWidth: 1)
            )
    }

    private func fill(pressed: Bool) -> Color {
        if pressed { return ShotliGlass.accent.opacity(0.16) }
        if hovered { return ShotliGlass.accent.opacity(0.08) }
        return Color.primary.opacity(0.04)
    }
}
