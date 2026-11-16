import AppKit

/// Lets the menu reference the responder-chain `undo:` / `redo:` actions with #selector.
@objc private protocol UndoActions {
    func undo(_ sender: Any?)
    func redo(_ sender: Any?)
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    func applicationWillFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        NSWindow.allowsAutomaticWindowTabbing = false   // no tabs
        NSApp.mainMenu = buildMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        #if DEBUG
        DebugSnapshot.runIfRequested()
        #endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Global (all-window) settings

    @objc func toggleWordWrap(_ sender: Any?) { Settings.wordWrap.toggle() }
    @objc func toggleInvisibles(_ sender: Any?) { Settings.showInvisibles.toggle() }
    @objc func toggleLineNumbers(_ sender: Any?) { Settings.showLineNumbers.toggle() }
    @objc func toggleStatusBar(_ sender: Any?) { Settings.showStatusBar.toggle() }
    @objc func zoomIn(_ sender: Any?) { Settings.fontSize += 1 }
    @objc func zoomOut(_ sender: Any?) { Settings.fontSize -= 1 }
    @objc func zoomReset(_ sender: Any?) { Settings.fontSize = Settings.defaultFontSize }

    @objc func showFontPanel(_ sender: Any?) {
        NSFontManager.shared.setSelectedFont(Settings.font, isMultiple: false)
        NSFontManager.shared.orderFrontFontPanel(sender)
    }

    @objc func showAbout(_ sender: Any?) {
        let credits = NSAttributedString(
            string: "A plain, Notepad-style text editor.\nBased on LiteEdit by arietan (MIT).",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(toggleWordWrap(_:)): item.state = Settings.wordWrap ? .on : .off
        case #selector(toggleInvisibles(_:)): item.state = Settings.showInvisibles ? .on : .off
        case #selector(toggleLineNumbers(_:)): item.state = Settings.showLineNumbers ? .on : .off
        case #selector(toggleStatusBar(_:)): item.state = Settings.showStatusBar ? .on : .off
        default: break
        }
        return true
    }

    // MARK: - Menu bar

    private func buildMainMenu() -> NSMenu {
        let main = NSMenu()

        func add(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            holder.submenu = menu
            main.addItem(holder)
            return menu
        }
        func item(_ title: String, _ action: Selector?, _ key: String = "",
                  _ mods: NSEvent.ModifierFlags = .command, tag: Int = 0,
                  target: AnyObject? = nil, rep: String? = nil) -> NSMenuItem {
            let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
            mi.keyEquivalentModifierMask = mods
            mi.tag = tag
            mi.target = target
            mi.representedObject = rep
            return mi
        }
        func sub(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
            let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            mi.submenu = menu
            return mi
        }
        let sep = { NSMenuItem.separator() }
        let finder = #selector(NSResponder.performTextFinderAction(_:))

        _ = add("Notepad", [
            item("About Notepad", #selector(showAbout(_:)), target: self),
            sep(),
            item("Hide Notepad", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:))),
            sep(),
            item("Quit Notepad", #selector(NSApplication.terminate(_:)), "q"),
        ])

        _ = add("File", [
            item("New", #selector(NSDocumentController.newDocument(_:)), "n"),
            item("Open…", #selector(NSDocumentController.openDocument(_:)), "o"),
            sep(),
            item("Save", #selector(NSDocument.save(_:)), "s"),
            item("Save As…", #selector(NSDocument.saveAs(_:)), "s", [.command, .shift]),
            sep(),
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
            item("Exit", #selector(NSApplication.terminate(_:))),
        ])

        _ = add("Edit", [
            item("Undo", #selector(UndoActions.undo(_:)), "z"),
            item("Redo", #selector(UndoActions.redo(_:)), "z", [.command, .shift]),
            sep(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Delete", #selector(NSText.delete(_:))),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
            sep(),
            item("Find…", finder, "f", tag: NSTextFinder.Action.showFindInterface.rawValue),
            item("Find Next", finder, "g", tag: NSTextFinder.Action.nextMatch.rawValue),
            item("Find Previous", finder, "g", [.command, .shift], tag: NSTextFinder.Action.previousMatch.rawValue),
            item("Replace…", finder, "f", [.command, .option], tag: NSTextFinder.Action.showReplaceInterface.rawValue),
            item("Use Selection for Find", finder, "e", tag: NSTextFinder.Action.setSearchString.rawValue),
            sep(),
            item("Go to Line…", #selector(EditorWindowController.goToLine(_:)), "l"),
        ])

        _ = add("Format", [
            item("Word Wrap", #selector(toggleWordWrap(_:)), target: self),
            item("Font…", #selector(showFontPanel(_:)), "t", target: self),
            sep(),
            sub("Line Endings", LineEnding.allCases.map {
                item($0.menuTitle, #selector(EditorWindowController.changeLineEnding(_:)), rep: $0.rawValue)
            }),
            sub("Encoding", TextEncoding.allCases.map {
                item($0.menuTitle, #selector(EditorWindowController.changeEncoding(_:)), rep: $0.rawValue)
            }),
            sub("Syntax", Language.allCases.map {
                item($0.displayName, #selector(EditorWindowController.changeLanguage(_:)), rep: $0.rawValue)
            }),
        ])

        _ = add("View", [
            item("Line Numbers", #selector(toggleLineNumbers(_:)), target: self),
            item("Status Bar", #selector(toggleStatusBar(_:)), target: self),
            item("Show Whitespace & Line Endings", #selector(toggleInvisibles(_:)), "i", [.command, .option], target: self),
            sep(),
            item("Zoom In", #selector(zoomIn(_:)), "=", target: self),
            item("Zoom Out", #selector(zoomOut(_:)), "-", target: self),
            item("Actual Size", #selector(zoomReset(_:)), "0", target: self),
        ])

        let windowMenu = add("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Zoom", #selector(NSWindow.performZoom(_:))),
            sep(),
            item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))),
        ])
        NSApp.windowsMenu = windowMenu
        return main
    }
}
