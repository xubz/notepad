import AppKit

/// Menu items for Syntax / Line Endings / Encoding, shared by the Format menu
/// (target nil → responder chain) and the status-bar popups (target = window controller).
/// Checkmarks are set by `EditorWindowController.validateMenuItem`.
enum FormatMenus {
    static func languageItems(target: AnyObject?) -> [NSMenuItem] {
        Language.allCases.map {
            item($0.displayName, #selector(EditorWindowController.changeLanguage(_:)), $0.rawValue, target)
        }
    }

    static func lineEndingItems(target: AnyObject?) -> [NSMenuItem] {
        LineEnding.allCases.map {
            item($0.menuTitle, #selector(EditorWindowController.changeLineEnding(_:)), $0.rawValue, target)
        }
    }

    static func encodingItems(target: AnyObject?) -> [NSMenuItem] {
        TextEncoding.allCases.map {
            item($0.menuTitle, #selector(EditorWindowController.changeEncoding(_:)), $0.rawValue, target)
        }
    }

    static func menu(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        return menu
    }

    private static func item(_ title: String, _ action: Selector, _ rep: String, _ target: AnyObject?) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: "")
        mi.representedObject = rep
        mi.target = target
        return mi
    }
}
