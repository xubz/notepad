import AppKit

/// Tango palette (https://en.wikipedia.org/wiki/Tango_Desktop_Project#Palette).
/// Every color is dynamic: light variant in Light Mode, dark variant in Dark Mode.
enum Theme {
    // Tango swatches
    private enum T {
        static let butter1: UInt32 = 0xFCE94F, butter3: UInt32 = 0xC4A000
        static let orange1: UInt32 = 0xFCAF3E, orange3: UInt32 = 0xCE5C00
        static let choc1: UInt32 = 0xE9B96E, choc3: UInt32 = 0x8F5902
        static let green1: UInt32 = 0x8AE234, green3: UInt32 = 0x4E9A06
        static let blue1: UInt32 = 0x729FCF, blue3: UInt32 = 0x204A87
        static let plum1: UInt32 = 0xAD7FA8, plum3: UInt32 = 0x5C3566
        static let red1: UInt32 = 0xEF2929, red3: UInt32 = 0xA40000
        static let alu1: UInt32 = 0xEEEEEC, alu2: UInt32 = 0xD3D7CF, alu3: UInt32 = 0xBABDB6
        static let alu4: UInt32 = 0x888A85, alu5: UInt32 = 0x555753, alu6: UInt32 = 0x2E3436
    }

    static let background = dynamic(0xFFFFFF, T.alu6)
    static let text       = dynamic(T.alu6, T.alu1)

    static let gutterBackground = dynamic(0xF6F6F4, 0x272C2E)
    static let gutterBorder     = dynamic(0xE4E5E1, 0x3A4144)
    static let gutterText       = dynamic(T.alu3, 0x6E7370)
    static let gutterActiveText = dynamic(T.alu5, T.alu2)
    static let statusBackground = gutterBackground
    static let statusText       = dynamic(T.alu5, T.alu3)

    /// Whitespace dots, tab arrows and line-ending markers.
    static let invisibles = dynamic(T.alu2, 0x4B5356)

    /// Vertical column-guide line (e.g. at 80).
    static let columnGuide = dynamic(0xE4E5E1, 0x3E4649)

    // Syntax
    static let comment   = dynamic(T.alu4, T.alu4)
    static let string    = dynamic(T.green3, T.green1)
    static let keyword   = dynamic(T.blue3, T.blue1)
    static let type      = dynamic(T.plum3, T.plum1)
    static let number    = dynamic(T.orange3, T.orange1)
    static let function  = dynamic(T.choc3, T.butter1)
    static let attribute = dynamic(T.red3, T.red1)

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return rgb(isDark ? dark : light)
        }
    }

    private static func rgb(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
    }
}
