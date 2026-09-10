import AppKit
import SwiftUI

@main
struct WindowRestorationApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Window Restoration", systemImage: "macwindow.on.rectangle") {
            MenuBarContent(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("現在の構成")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.configurationSummary)
                    .font(.headline)
            }

            HStack {
                Button("現在の配置を保存") {
                    model.saveCurrentLayout()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("保存した配置を復元") {
                    model.restoreCurrentLayout()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!model.hasSavedProfile)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    displaySection
                    profileSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // ScrollView has no intrinsic height inside MenuBarExtra and can
            // otherwise collapse, hiding the monitor and profile sections.
            .frame(minHeight: 240, idealHeight: 320, maxHeight: 380)

            Divider()

            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            HStack {
                if !model.isAccessibilityTrusted {
                    Button("権限を許可") {
                        model.requestAccessibilityPermission()
                    }
                    Button("システム設定") {
                        model.openAccessibilitySettings()
                    }
                }

                Button("状態を再確認") {
                    model.refreshState(showConfirmation: true)
                }

                Spacer()

                Button("終了") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 430)
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("モニター")
                .font(.headline)

            ForEach(model.knownDisplays) { display in
                DisplayRow(
                    display: display,
                    customName: Binding(
                        get: { model.customName(for: display.id) },
                        set: { model.setCustomName($0, for: display.id) }
                    )
                )
            }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("保存済みの構成")
                .font(.headline)

            if model.savedProfiles.isEmpty {
                Text("保存済みの配置はありません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.savedProfiles) { profile in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(profile.displayNames.joined(separator: " + "))
                                .fontWeight(.medium)
                            if profile.isCurrent {
                                Text("現在")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.tint.opacity(0.15), in: Capsule())
                            }
                        }
                        Text("\(profile.windowCount)個のウィンドウ・\(profile.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                }
            }
        }
    }
}

private struct DisplayRow: View {
    let display: DisplayStatus
    @Binding var customName: String
    @State private var isEditing = false
    @State private var draftName: String
    @FocusState private var isNameFieldFocused: Bool

    init(display: DisplayStatus, customName: Binding<String>) {
        self.display = display
        _customName = customName
        _draftName = State(initialValue: customName.wrappedValue)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                .frame(width: 18)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                if isEditing {
                    TextField("モニター名", text: $draftName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFieldFocused)
                        .onSubmit(saveName)

                    HStack(spacing: 8) {
                        Button("保存", action: saveName)
                            .disabled(trimmedDraftName.isEmpty)
                        Button("キャンセル", action: cancelEditing)
                        if !customName.isEmpty {
                            Button("標準名に戻す") {
                                customName = ""
                                isEditing = false
                            }
                        }
                    }
                    .controlSize(.small)
                } else {
                    HStack {
                        Text(display.displayName)
                            .fontWeight(.medium)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2, perform: beginEditing)

                        Spacer()

                        Button(action: beginEditing) {
                            Label("名前を変更", systemImage: "pencil")
                        }
                        .controlSize(.small)
                    }
                }

                HStack(spacing: 6) {
                    if display.displayName != display.systemName {
                        Text(display.systemName)
                    }
                    Text(display.isConnected ? "接続中" : "未接続")
                        .foregroundStyle(display.isConnected ? .green : .secondary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var trimmedDraftName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginEditing() {
        draftName = customName.isEmpty ? display.displayName : customName
        isEditing = true
        DispatchQueue.main.async {
            isNameFieldFocused = true
        }
    }

    private func saveName() {
        guard !trimmedDraftName.isEmpty else { return }
        customName = trimmedDraftName
        isEditing = false
    }

    private func cancelEditing() {
        draftName = customName
        isEditing = false
    }
}
