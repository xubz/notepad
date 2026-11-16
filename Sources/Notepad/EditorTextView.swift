import AppKit

final class EditorTextView: NSTextView {
    /// Column at which to draw a vertical guide line (0 = off).
    var columnGuide = 0 { didSet { if columnGuide != oldValue { needsDisplay = true } } }

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

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard columnGuide > 0, let font = typingAttributes[.font] as? NSFont else { return }
        let charWidth = ("0" as NSString).size(withAttributes: [.font: font]).width
        let padding = textContainer?.lineFragmentPadding ?? 0
        let x = (textContainerOrigin.x + padding + CGFloat(columnGuide) * charWidth).rounded() + 0.5
        guard x >= rect.minX - 1, x <= rect.maxX + 1 else { return }
        Theme.columnGuide.setFill()
        NSRect(x: x - 0.5, y: rect.minY, width: 1, height: rect.height).fill()
    }
}
