import AppKit

/// Line-number gutter that sits beside the scroll view (not an NSRulerView).
/// Positions are converted from text-view coordinates, so scrolling and the
/// find bar pushing the text down are handled automatically.
final class LineNumberView: NSView {
    private weak var textView: NSTextView?
    private var widthConstraint: NSLayoutConstraint!

    var font: NSFont = .monospacedDigitSystemFont(ofSize: 11, weight: .regular) { didSet { needsDisplay = true } }
    var editorFont: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular) { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    init(textView: NSTextView) {
        self.textView = textView
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthConstraint = widthAnchor.constraint(equalToConstant: 40)
        widthConstraint.isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func updateWidth(lineCount: Int) {
        let digits = max(3, String(lineCount).count)
        let digitWidth = ("0" as NSString).size(withAttributes: [.font: font]).width
        let width = isHidden ? 0 : ceil(CGFloat(digits) * digitWidth + 18)
        if widthConstraint.constant != width { widthConstraint.constant = width }
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.gutterBackground.setFill()
        dirtyRect.fill()
        Theme.gutterBorder.setFill()
        NSRect(x: bounds.maxX - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()

        guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer,
              let storage = tv.textStorage, let clip = tv.enclosingScrollView?.contentView else { return }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        // Only clip vertically to the text area (the find bar can push it down).
        let clipRect = convert(clip.bounds, from: clip)
        NSBezierPath(rect: NSRect(x: 0, y: clipRect.minY, width: bounds.width, height: clipRect.height)).addClip()

        let s = storage.mutableString
        let origin = tv.textContainerOrigin
        let baseline = lm.defaultBaselineOffset(for: editorFont)
        let normal: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Theme.gutterText]
        let active: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Theme.gutterActiveText]
        let sel = min(tv.selectedRange().location, s.length)
        let selLineStart = s.lineRange(for: NSRange(location: sel, length: 0)).location

        func drawNumber(_ n: Int, fragmentTop: CGFloat, isActive: Bool) {
            let y = convert(NSPoint(x: 0, y: fragmentTop + origin.y), from: tv).y
            let attrs = isActive ? active : normal
            let str = String(n) as NSString
            let w = str.size(withAttributes: attrs).width
            str.draw(at: NSPoint(x: bounds.width - w - 8, y: y + baseline - font.ascender), withAttributes: attrs)
        }

        if s.length == 0 {
            drawNumber(1, fragmentTop: 0, isActive: true)
            return
        }

        let visible = tv.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphs = lm.glyphRange(forBoundingRect: visible, in: tc)
        let chars = lm.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)

        // Number of the next line that *starts* in the visible area.
        var lineNumber = TextUtils.newlineCount(s, upTo: chars.location) + 1
        if chars.location > 0 && s.character(at: chars.location - 1) != 0x0A { lineNumber += 1 }

        var glyph = glyphs.location
        while glyph < NSMaxRange(glyphs) {
            var effective = NSRange()
            let fragment = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &effective)
            let cr = lm.characterRange(forGlyphRange: effective, actualGlyphRange: nil)
            if cr.location == 0 || s.character(at: cr.location - 1) == 0x0A {
                drawNumber(lineNumber, fragmentTop: fragment.minY, isActive: cr.location == selLineStart)
                lineNumber += 1
            }
            glyph = max(NSMaxRange(effective), glyph + 1)
        }

        // Empty last line after a trailing newline.
        if NSMaxRange(chars) == s.length, lm.extraLineFragmentTextContainer != nil {
            let r = lm.extraLineFragmentRect
            drawNumber(lineNumber, fragmentTop: r.minY, isActive: sel == s.length)
        }
    }
}
