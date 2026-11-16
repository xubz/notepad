import AppKit

extension Notification.Name {
    static let settingsDidChange = Notification.Name("NotepadSettingsDidChange")
}

/// App-wide preferences (shared by every window), persisted in UserDefaults.
enum Settings {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let wordWrap = "wordWrap"
        static let showInvisibles = "showInvisibles"
        static let showLineNumbers = "showLineNumbers"
        static let showStatusBar = "showStatusBar"
    }

    static let defaultFontSize: CGFloat = 13

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.fontSize: Double(defaultFontSize),
            Key.wordWrap: false,
            Key.showInvisibles: true,
            Key.showLineNumbers: true,
            Key.showStatusBar: true,
        ])
    }

    /// Editor font. Defaults to the system monospaced font (SF Mono).
    static var font: NSFont {
        get {
            if let name = defaults.string(forKey: Key.fontName),
               let f = NSFont(name: name, size: fontSize) {
                return f
            }
            return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        set {
            // System UI fonts (".AppleSystemUIFontMonospaced-…") can't be looked
            // up by name, so only persist names that round-trip.
            if NSFont(name: newValue.fontName, size: newValue.pointSize)?.fontName == newValue.fontName,
               !newValue.fontName.hasPrefix(".") {
                defaults.set(newValue.fontName, forKey: Key.fontName)
            } else {
                defaults.removeObject(forKey: Key.fontName)
            }
            defaults.set(Double(clampSize(newValue.pointSize)), forKey: Key.fontSize)
            post()
        }
    }

    static var fontSize: CGFloat {
        get { clampSize(CGFloat(defaults.double(forKey: Key.fontSize))) }
        set { defaults.set(Double(clampSize(newValue)), forKey: Key.fontSize); post() }
    }

    static var wordWrap: Bool {
        get { defaults.bool(forKey: Key.wordWrap) }
        set { defaults.set(newValue, forKey: Key.wordWrap); post() }
    }

    static var showInvisibles: Bool {
        get { defaults.bool(forKey: Key.showInvisibles) }
        set { defaults.set(newValue, forKey: Key.showInvisibles); post() }
    }

    static var showLineNumbers: Bool {
        get { defaults.bool(forKey: Key.showLineNumbers) }
        set { defaults.set(newValue, forKey: Key.showLineNumbers); post() }
    }

    static var showStatusBar: Bool {
        get { defaults.bool(forKey: Key.showStatusBar) }
        set { defaults.set(newValue, forKey: Key.showStatusBar); post() }
    }

    private static func clampSize(_ s: CGFloat) -> CGFloat { min(96, max(6, s == 0 ? defaultFontSize : s)) }

    private static func post() {
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }
}
