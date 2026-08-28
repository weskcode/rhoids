import Testing
import Foundation
@testable import RHOIDS

extension Tag {
    @Tag static var liveActivityDevice: Self
}

/// Diagnostic tests targeting the known failure modes that cause Live Activities
/// to work in the Simulator but fail silently on physical devices.
///
/// Each test validates a specific precondition for Live Activities on device.
/// If any test fails, it identifies the exact cause and what to fix.
@Suite(.tags(.liveActivityDevice))
struct LiveActivityDeviceDiagnosticTests {

    // MARK: - Issue 1: Widget extension must not compile files with unavailable frameworks

    @Test("Widget extension must not compile AlarmKitService (imports AlarmKit)")
    func widgetDoesNotCompileAlarmKitService() throws {
        let pbxprojPath = try findPbxproj()
        let content = try String(contentsOfFile: pbxprojPath, encoding: .utf8)
        let widgetFiles = try extractWidgetSourceFiles(from: content)

        #expect(widgetFiles.contains("AlarmKitService.swift") == false,
                "AlarmKitService.swift imports AlarmKit which is unavailable in widget extensions - crashes the entire extension on device")
    }

    @Test("Widget extension must not compile FocusLockNames (imports DeviceActivity, ManagedSettings)")
    func widgetDoesNotCompileFocusLockNames() throws {
        let pbxprojPath = try findPbxproj()
        let content = try String(contentsOfFile: pbxprojPath, encoding: .utf8)
        let widgetFiles = try extractWidgetSourceFiles(from: content)

        #expect(widgetFiles.contains("FocusLockNames.swift") == false,
                "FocusLockNames.swift imports DeviceActivity/ManagedSettings - crashes widget on device")
    }

    @Test("Widget extension must not compile FocusLockPreferences (imports FamilyControls)")
    func widgetDoesNotCompileFocusLockPreferences() throws {
        let pbxprojPath = try findPbxproj()
        let content = try String(contentsOfFile: pbxprojPath, encoding: .utf8)
        let widgetFiles = try extractWidgetSourceFiles(from: content)

        #expect(widgetFiles.contains("FocusLockPreferences.swift") == false,
                "FocusLockPreferences.swift imports FamilyControls - crashes widget on device")
    }

    // MARK: - Issue 2: Info.plist configuration

    @Test("Main app Info.plist must include NSSupportsLiveActivities")
    func mainAppInfoPlistHasLiveActivities() throws {
        let plistPath = try findProjectRoot() + "/Sources/RHOIDS/Info.plist"
        let data = try Data(contentsOf: URL(fileURLWithPath: plistPath))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let value = try #require(plist?["NSSupportsLiveActivities"] as? Bool,
                                 "NSSupportsLiveActivities key must exist in main app Info.plist")
        #expect(value == true, "NSSupportsLiveActivities must be true")
    }

    @Test("Widget Info.plist must include NSSupportsLiveActivities")
    func widgetInfoPlistHasLiveActivities() throws {
        let plistPath = try findProjectRoot() + "/Sources/RHOIDSWidget/Info.plist"
        let data = try Data(contentsOf: URL(fileURLWithPath: plistPath))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let value = try #require(plist?["NSSupportsLiveActivities"] as? Bool,
                                 "NSSupportsLiveActivities key should exist in widget Info.plist for device compatibility")
        #expect(value == true)
    }

    @Test("Widget Info.plist NSExtensionPointIdentifier is correct")
    func widgetExtensionPointIsCorrect() throws {
        let plistPath = try findProjectRoot() + "/Sources/RHOIDSWidget/Info.plist"
        let data = try Data(contentsOf: URL(fileURLWithPath: plistPath))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        let ext = try #require(plist?["NSExtension"] as? [String: Any])
        let pointID = try #require(ext["NSExtensionPointIdentifier"] as? String)
        #expect(pointID == "com.apple.widgetkit-extension",
                "Widget extension point must be com.apple.widgetkit-extension")
    }

    // MARK: - Issue 3: Bundle ID hierarchy

    @Test("Widget bundle ID must be a child of the app bundle ID")
    func widgetBundleIDIsChildOfApp() throws {
        let pbxprojPath = try findPbxproj()
        let content = try String(contentsOfFile: pbxprojPath, encoding: .utf8)

        let appBundleID = extractBundleID(from: content, matching: "com.wesley.RHOIDS;")
        let widgetBundleID = extractBundleID(from: content, matching: "com.wesley.RHOIDS.widget;")

        let app = try #require(appBundleID, "App bundle ID should be found")
        let widget = try #require(widgetBundleID, "Widget bundle ID should be found")

        #expect(widget.hasPrefix(app + "."),
                "Widget bundle ID '\(widget)' must be a child of app bundle ID '\(app)' - required for Live Activities on device")
    }

    // MARK: - Issue 4: App Group entitlements must match

    @Test("App and widget extension must share the same App Group")
    func appGroupEntitlementsMatch() throws {
        let root = try findProjectRoot()
        let appGroups = try extractAppGroups(from: root + "/Sources/RHOIDS/RHOIDS.entitlements")
        let widgetGroups = try extractAppGroups(from: root + "/Sources/RHOIDSWidget/RHOIDSWidget.entitlements")

        try #require(appGroups.isEmpty == false, "App must have at least one App Group")
        try #require(widgetGroups.isEmpty == false, "Widget must have at least one App Group")

        let shared = appGroups.intersection(widgetGroups)
        #expect(shared.isEmpty == false,
                "App groups \(appGroups) and widget groups \(widgetGroups) must have at least one common group")
    }

    // MARK: - Issue 5: Attribute data size must stay under 4KB

    @Test("Activity attributes + content state must be under 4KB",
          arguments: PresetTimer.all.filter { $0.isCustom == false })
    func attributesSizeUnder4KB(preset: PresetTimer) throws {
        let attrs = RHOIDSActivityAttributes(
            plannedDuration: preset.duration,
            presetIcon: preset.systemImage
        )
        let state = RHOIDSActivityAttributes.ContentState(
            endDate: Date().addingTimeInterval(preset.duration),
            presetName: preset.name
        )

        let attrsData = try JSONEncoder().encode(attrs)
        let stateData = try JSONEncoder().encode(state)
        let totalBytes = attrsData.count + stateData.count

        #expect(totalBytes < 4096,
                "Combined attributes + state (\(totalBytes) bytes) must be under 4096 bytes for preset '\(preset.name)'")
    }

    // MARK: - Issue 6: project.yml and pbxproj consistency

    @Test("project.yml widget sources should not include framework-restricted files")
    func projectYmlDoesNotIncludeRestrictedFiles() throws {
        let ymlPath = try findProjectRoot() + "/project.yml"
        let content = try String(contentsOfFile: ymlPath, encoding: .utf8)

        let restrictedFiles = ["AlarmKitService.swift", "FocusLockNames.swift", "FocusLockPreferences.swift"]
        for file in restrictedFiles {
            #expect(content.contains(file) == false || isFileInNonWidgetSection(file, in: content),
                    "\(file) must not be listed in the RHOIDSWidget target sources in project.yml")
        }
    }

    @Test("Dynamic Island avoids timer-driven ProgressView snapshots")
    func dynamicIslandAvoidsTimerDrivenProgressView() throws {
        let liveActivityPath = try findProjectRoot() + "/Sources/RHOIDSWidget/LiveActivity/RHOIDSLiveActivityWidget.swift"
        let content = try String(contentsOfFile: liveActivityPath, encoding: .utf8)
        let dynamicIslandSource = try extractDynamicIslandSource(from: content)

        #expect(dynamicIslandSource.contains("ProgressView(timerInterval:") == false,
                "Dynamic Island snapshots should avoid ProgressView(timerInterval:) because failures in any island region can blank the compact pill")
        #expect(dynamicIslandSource.contains("Text(timerInterval:"),
                "Dynamic Island should still expose a live countdown in compact/expanded text")
    }

    // MARK: - Helpers

    private func findProjectRoot() throws -> String {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<10 {
            dir = dir.deletingLastPathComponent()
            let pbxproj = dir.appendingPathComponent("RHOIDS.xcodeproj/project.pbxproj")
            if FileManager.default.fileExists(atPath: pbxproj.path) {
                return dir.path
            }
        }
        throw TestHelperError.projectRootNotFound
    }

    private func findPbxproj() throws -> String {
        try findProjectRoot() + "/RHOIDS.xcodeproj/project.pbxproj"
    }

    private func extractWidgetSourceFiles(from pbxproj: String) throws -> Set<String> {
        // Widget target's Sources build phase ID
        guard let range = pbxproj.range(of: "B5E25A6E9E78CD5C664D7014 /* Sources */ = {") else {
            throw TestHelperError.buildPhaseNotFound
        }
        let start = range.lowerBound
        guard let filesEnd = pbxproj[start...].range(of: ");") else {
            throw TestHelperError.buildPhaseNotFound
        }
        let section = String(pbxproj[start..<filesEnd.upperBound])

        var files = Set<String>()
        let pattern = try NSRegularExpression(pattern: #"/\* (.+?) in Sources \*/"#)
        let matches = pattern.matches(in: section, range: NSRange(section.startIndex..., in: section))
        for match in matches {
            if let nameRange = Range(match.range(at: 1), in: section) {
                files.insert(String(section[nameRange]))
            }
        }
        guard files.isEmpty == false else {
            throw TestHelperError.widgetSourceFilesNotFound
        }
        return files
    }

    private func extractBundleID(from pbxproj: String, matching suffix: String) -> String? {
        let pattern = "PRODUCT_BUNDLE_IDENTIFIER = " + NSRegularExpression.escapedPattern(for: suffix)
        guard pbxproj.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return suffix.replacingOccurrences(of: ";", with: "")
    }

    private func extractAppGroups(from entitlementsPath: String) throws -> Set<String> {
        let data = try Data(contentsOf: URL(fileURLWithPath: entitlementsPath))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        guard let groups = plist?["com.apple.security.application-groups"] as? [String] else {
            return []
        }
        return Set(groups)
    }

    private func isFileInNonWidgetSection(_ file: String, in yml: String) -> Bool {
        guard let widgetRange = yml.range(of: "RHOIDSWidget:") else { return true }
        let nextTarget = yml[widgetRange.upperBound...].range(of: "\n  RH")
        let widgetSection: Substring
        if let nextTarget {
            widgetSection = yml[widgetRange.lowerBound..<nextTarget.lowerBound]
        } else {
            widgetSection = yml[widgetRange.lowerBound...]
        }
        return widgetSection.contains(file) == false
    }

    private func extractDynamicIslandSource(from source: String) throws -> String {
        guard let start = source.range(of: "} dynamicIsland:")?.lowerBound,
              let end = source.range(of: "// MARK: - Lock Screen")?.lowerBound,
              start < end else {
            throw TestHelperError.dynamicIslandSourceNotFound
        }

        return String(source[start..<end])
    }

    private enum TestHelperError: Error {
        case projectRootNotFound
        case buildPhaseNotFound
        case widgetSourceFilesNotFound
        case dynamicIslandSourceNotFound
    }
}
