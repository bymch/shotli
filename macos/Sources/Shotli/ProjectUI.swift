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
        draft = value
        issue = ProjectStore.validationError(for: value, excluding: excluding)
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

    private var filtered: [ProjectRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matched = needle.isEmpty ? projects : projects.filter { $0.name.lowercased().contains(needle) }
        return matched.sorted { $0.modified > $1.modified }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Save to Project")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ShotliGlass.ink)
                Text("Saves the composition and a copy of the screenshot. Export and Copy are unchanged.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
            ScrollView {
                if filtered.isEmpty {
                    Text(projects.isEmpty ? "No projects yet." : "Nothing matches “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 4) {
                        ForEach(filtered) { project in
                            projectRow(project)
                        }
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
            .help("Name a project, then save this screenshot into it")
            .accessibilityLabel("Create New Project")
        }
        .padding(16)
        .frame(width: 340, height: 460)
        .onAppear { projects = ProjectStore.list() }
    }

    private func projectRow(_ project: ProjectRecord) -> some View {
        HStack(spacing: 10) {
            thumb(project)
                .frame(width: 36, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ShotliGlass.ink)
                    .lineLimit(1)
                Text(detail(project))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button("Save") { save(project) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("Save to \(project.name)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func thumb(_ project: ProjectRecord) -> some View {
        Group {
            if let url = project.thumbnail, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.5))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 1))
    }

    private func detail(_ project: ProjectRecord) -> String {
        let count = project.compositions
        let noun = count == 1 ? "composition" : "compositions"
        return "\(count) \(noun)"
    }

    private func save(_ project: ProjectRecord) {
        model.showSaveProjects = false
        model.saveCurrent(into: project.folder)
    }

    private func create() {
        model.showSaveProjects = false
        DispatchQueue.main.async {
            ProjectPrompt.shared.ask { folder in
                model.saveCurrent(into: folder)
            }
        }
    }
}
