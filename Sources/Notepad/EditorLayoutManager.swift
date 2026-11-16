import AppKit

/// Draws visible whitespace on top of the normal text:
/// `·` for spaces, `→` for tabs, `°` for non-breaking spaces, and a small
/// LF / CRLF / CR tag at the end of every line.
final class EditorLayoutManager: NSLayoutManager {
    var showsInvisibles = true { didSet { if showsInvisibles != oldValue { redrawAll() } } }
    var lineEnding: LineEnding = .lf { didSet { if lineEnding != oldValue { redrawAll() } } }
    var invisiblesFont: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular) {
        didSet { redrawAll() }
    }

    private func redrawAll() {
        guard let length = textStorage?.length else { return }
        invalidateDisplay(forCharacterRange: NSRange(location: 0, length: length))
    }

    /// Vertical center of the text within a line fragment (ignores extra line spacing).
    private func font(forLineHeight height: CGFloat) -> CGFloat {
        min(height, defaultLineHeight(for: invisiblesFont)) / 2
    }

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard showsInvisibles, let storage = textStorage, let container = textContainers.first else { return }

        let chars = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        guard chars.length > 0 else { return }

        let color = Theme.invisibles
        let symbolAttrs: [NSAttributedString.Key: Any] = [.font: invisiblesFont, .foregroundColor: color]
        let eolFont = NSFont.systemFont(ofSize: max(7, invisiblesFont.pointSize * 0.6), weight: .medium)
        let eolAttrs: [NSAttributedString.Key: Any] = [.font: eolFont, .foregroundColor: color]
        let eolLabel = lineEnding.label as NSString
        let eolSize = eolLabel.size(withAttributes: eolAttrs)

        var buffer = [unichar](repeating: 0, count: chars.length)
        storage.mutableString.getCharacters(&buffer, range: chars)

        for (i, c) in buffer.enumerated() {
            let symbol: NSString
            switch c {
            case 0x20: symbol = "·"
            case 0x09: symbol = "→"
            case 0xA0: symbol = "°"
            case 0x0A: symbol = eolLabel
            default: continue
            }
            let glyph = glyphIndexForCharacter(at: chars.location + i)

            if c == 0x0A {
                let line = lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil, withoutAdditionalLayout: true)
                let x = line.minX + location(forGlyphAt: glyph).x + origin.x
                let midY = line.minY + origin.y + font(forLineHeight: line.height)
                symbol.draw(at: NSPoint(x: x + 3, y: midY - eolSize.height / 2), withAttributes: eolAttrs)
                continue
            }

            let rect = boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
                .offsetBy(dx: origin.x, dy: origin.y)
            switch c {
            case 0x09:
                symbol.draw(at: NSPoint(x: rect.minX + 1, y: rect.minY), withAttributes: symbolAttrs)
            default:
                let w = symbol.size(withAttributes: symbolAttrs).width
                symbol.draw(at: NSPoint(x: rect.midX - w / 2, y: rect.minY), withAttributes: symbolAttrs)
            }
        }
    }
}
