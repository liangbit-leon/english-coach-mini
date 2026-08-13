import AppKit
import Carbon.HIToolbox
import SwiftUI

if CommandLine.arguments.contains("--self-test") {
    exit(CoachSelfTest.run() ? 0 : 1)
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let applicationDelegate = AppDelegate()
    application.delegate = applicationDelegate
    application.setActivationPolicy(.accessory)
    application.run()
    _ = applicationDelegate
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panelController: CoachPanelController?
    private var globalHotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = CoachPanelController()
        configureMainMenu()
        configureStatusItem()

        globalHotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_E),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.showCoach()
            }
        }

        showCoach()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "English Coach Mini")
        let quitItem = NSMenuItem(
            title: "Quit English Coach",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        applicationMenu.addItem(quitItem)
        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")

        let redoItem = NSMenuItem(
            title: "Redo",
            action: Selector(("redo:")),
            keyEquivalent: "z"
        )
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "character.book.closed.fill",
                accessibilityDescription: "English Coach"
            )
            image?.isTemplate = true
            button.image = image
            button.toolTip = "English Coach Mini"
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "Open English Coach",
            action: #selector(showCoachFromMenu),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        let quitItem = NSMenuItem(
            title: "Quit English Coach",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func showCoach() {
        panelController?.show()
    }

    @objc private func showCoachFromMenu() {
        showCoach()
    }

    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}

@MainActor
final class CoachPanelController {
    private let store = CoachStore()
    private let panel: NSPanel
    private var hasPositionedWindow = false
    private var keyMonitor: Any?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "English Coach Mini"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 620, height: 520)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .windowBackgroundColor

        let rootView = CoachView(store: store) { [weak panel] in
            panel?.orderOut(nil)
        }
        panel.contentView = NSHostingView(rootView: rootView)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.panel.isKeyWindow,
                  event.keyCode == UInt16(kVK_Return) || event.keyCode == UInt16(kVK_ANSI_KeypadEnter) else {
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if modifiers.contains(.command) {
                self.store.analyze()
                return nil
            }

            if modifiers.isDisjoint(with: [.control, .option]),
               let editor = self.panel.firstResponder as? NSTextView {
                editor.insertNewline(nil)
                return nil
            }

            return event
        }
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    func show() {
        if !hasPositionedWindow {
            panel.center()
            hasPositionedWindow = true
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        store.requestInputFocus()
    }
}
