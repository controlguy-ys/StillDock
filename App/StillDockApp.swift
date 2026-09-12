import AppKit
import SwiftUI

@main
struct StillDockApp: App {
    @NSApplicationDelegateAdaptor(StillDockAppDelegate.self) private var appDelegate
    @StateObject private var model = WorkbenchModel()

    var body: some Scene {
        WindowGroup("StillDock") {
            WorkbenchView(model: model)
                .frame(minWidth: 1040, minHeight: 700)
                .preferredColorScheme(.light)
                .task { model.importQAFixturesIfRequested() }
        }
        .defaultSize(width: 1160, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("사진 추가…") { model.chooseImages() }
                    .keyboardShortcut("o")
                    .disabled(model.isLocked)
            }
            CommandGroup(after: .pasteboard) {
                Button("선택한 사진 제거") { model.removeSelection() }
                    .keyboardShortcut(.delete, modifiers: [])
                    .disabled(model.isLocked || model.selectedID == nil)
            }
        }
    }
}

final class StillDockAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
