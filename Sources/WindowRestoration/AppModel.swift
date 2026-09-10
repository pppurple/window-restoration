import AppKit
import Combine
import Foundation
import WindowRestorationCore

struct DisplayStatus: Identifiable, Equatable {
    let id: String
    let systemName: String
    let displayName: String
    let isBuiltIn: Bool
    let isConnected: Bool
}

struct SavedProfileStatus: Identifiable, Equatable {
    let id: String
    let displayNames: [String]
    let windowCount: Int
    let capturedAt: Date
    let isCurrent: Bool
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var configurationSummary = "確認中…"
    @Published private(set) var hasSavedProfile = false
    @Published private(set) var statusMessage = ""
    @Published private(set) var isAccessibilityTrusted = false
    @Published private(set) var knownDisplays: [DisplayStatus] = []
    @Published private(set) var savedProfiles: [SavedProfileStatus] = []

    private let displays = DisplayProvider()
    private let windows = AccessibilityWindowService()
    private let store = ProfileStore()
    private let nameStore = DisplayNameStore()
    private var customNames: [String: String] = [:]
    private var currentConfiguration: DisplayConfiguration?
    private var cachedProfiles: [LayoutProfile] = []
    private var screenObserver: NSObjectProtocol?

    init() {
        customNames = (try? nameStore.load()) ?? [:]
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshState()
            }
        }
        refreshState()
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func refreshState(showConfirmation: Bool = false) {
        isAccessibilityTrusted = windows.isTrusted
        do {
            let configuration = try displays.currentConfiguration()
            let profiles = try store.loadAll()
            currentConfiguration = configuration
            cachedProfiles = profiles
            hasSavedProfile = store.hasProfile(configurationID: configuration.identifier)
            rebuildConfigurationStatus()
            if showConfirmation {
                let permission = isAccessibilityTrusted ? "許可済み" : "未許可"
                let currentProfile = hasSavedProfile ? "保存済み" : "未保存"
                statusMessage = "確認結果：アクセシビリティは\(permission)、接続中モニターは\(configuration.displays.count)台、保存済み構成は\(profiles.count)件、現在の構成は\(currentProfile)です。"
            }
        } catch {
            configurationSummary = "取得できません"
            hasSavedProfile = false
            statusMessage = error.localizedDescription
        }
    }

    func customName(for displayID: String) -> String {
        customNames[displayID] ?? ""
    }

    func setCustomName(_ name: String, for displayID: String) {
        if name.isEmpty {
            customNames.removeValue(forKey: displayID)
        } else {
            customNames[displayID] = name
        }

        do {
            try nameStore.save(customNames)
            rebuildConfigurationStatus()
            statusMessage = "モニター名を保存しました。"
        } catch {
            statusMessage = "モニター名を保存できませんでした：\(error.localizedDescription)"
        }
    }

    func requestAccessibilityPermission() {
        _ = windows.requestTrust()
        isAccessibilityTrusted = windows.isTrusted
        if !isAccessibilityTrusted {
            statusMessage = "設定後に、メニューの「状態を再確認」を押してください。"
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func saveCurrentLayout() {
        guard ensureAccessibilityPermission() else { return }
        do {
            let configuration = try displays.currentConfiguration()
            let snapshots = windows.captureWindows()
            try store.save(LayoutProfile(
                displayConfiguration: configuration,
                windows: snapshots
            ))
            refreshState()
            statusMessage = "\(snapshots.count)個のウィンドウを保存しました。"
        } catch {
            statusMessage = "保存できませんでした：\(error.localizedDescription)"
        }
    }

    func restoreCurrentLayout() {
        guard ensureAccessibilityPermission() else { return }
        do {
            let configuration = try displays.currentConfiguration()
            guard let profile = try store.load(configurationID: configuration.identifier) else {
                statusMessage = "このディスプレイ構成の保存データがありません。"
                hasSavedProfile = false
                return
            }
            let report = windows.restore(profile)
            statusMessage = "\(report.restored)個を復元、\(report.skipped)個をスキップ、\(report.failed)個が失敗しました。"
        } catch {
            statusMessage = "復元できませんでした：\(error.localizedDescription)"
        }
    }

    private func rebuildConfigurationStatus() {
        guard let currentConfiguration else { return }
        let connectedIDs = Set(currentConfiguration.displays.map(\.uuid))
        var displaysByID: [String: DisplaySnapshot] = [:]

        for profile in cachedProfiles {
            for display in profile.displayConfiguration.displays {
                displaysByID[display.uuid] = display
            }
        }
        for display in currentConfiguration.displays {
            displaysByID[display.uuid] = display
        }

        knownDisplays = displaysByID.values
            .map { display in
                DisplayStatus(
                    id: display.uuid,
                    systemName: display.name,
                    displayName: displayName(for: display),
                    isBuiltIn: display.isBuiltIn,
                    isConnected: connectedIDs.contains(display.uuid)
                )
            }
            .sorted {
                if $0.isConnected != $1.isConnected { return $0.isConnected }
                if $0.isBuiltIn != $1.isBuiltIn { return $0.isBuiltIn }
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }

        savedProfiles = cachedProfiles.map { profile in
            SavedProfileStatus(
                id: profile.displayConfiguration.identifier,
                displayNames: profile.displayConfiguration.displays.map(displayName(for:)),
                windowCount: profile.windows.count,
                capturedAt: profile.capturedAt,
                isCurrent: profile.displayConfiguration.identifier == currentConfiguration.identifier
            )
        }

        configurationSummary = currentConfiguration.displays
            .map(displayName(for:))
            .joined(separator: " + ")
    }

    private func displayName(for display: DisplaySnapshot) -> String {
        guard let customName = customNames[display.uuid],
              !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return display.name
        }
        return customName
    }

    private func ensureAccessibilityPermission() -> Bool {
        isAccessibilityTrusted = windows.isTrusted
        guard isAccessibilityTrusted else {
            requestAccessibilityPermission()
            statusMessage = "ウィンドウ操作にはアクセシビリティ権限が必要です。"
            return false
        }
        return true
    }
}
