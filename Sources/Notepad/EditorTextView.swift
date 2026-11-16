import AppKit

final class EditorTextView: NSTextView {
    /// Keep the previous line's indentation on Return.
    override func insertNewline(_ sender: Any?) {
        let s = textStorage?.mutableString ?? ""
        let sel = selectedRange()
        let lineStart = s.lineRange(for: NSRange(location: sel.location, length: 0)).location
        var end = lineStart
        while end < sel.location {
            let c = s.character(at: end)
            if c != 0x20 && c != 0x09 { break }
            end += 1
        }
        let indent = s.substring(with: NSRange(location: lineStart, length: end - lineStart))
        insertText("\n" + indent, replacementRange: sel)
    }

    /// Font panel changes apply app-wide (every window), like Notepad's Format ▸ Font.
    override func changeFont(_ sender: Any?) {
        guard let manager = sender as? NSFontManager else { return }
        Settings.font = manager.convert(Settings.font)
    }
}
