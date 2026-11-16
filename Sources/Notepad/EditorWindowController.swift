import AppKit

final class EditorWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, NSMenuItemValidation {
    private weak var textDocument: TextDocument?
    private let layoutManager = EditorLayoutManager()
    private var textView: EditorTextView!
    private var scrollView: NSScrollView!
    private var gutter: LineNumberView!
    private var statusBar: StatusBarView!
    private var statusHeight: NSLayoutConstraint!
    private var highlighter = SyntaxHighlighter.forLanguage(.plainText)
    private var wrapApplied: Bool?

    /// Files up to this size are fully re-highlighted after each edit;
    /// larger files only highlight what's on screen.
    private static let fullHighlightLimit = 300_000
    private static let frameName = "NotepadWindow"

    init(document: TextDocument) {
        textDocument = document
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: true)
        window.minSize = NSSize(width: 320, height: 200)
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.isRestorable = false   // always start with a fresh, empty Untitled window
        super.init(window: window)
        window.delegate = self
        placeWindow(window)
        buildUI(storage: document.textStorage)
        applySettings()
        documentStateDidChange()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func placeWindow(_ window: NSWindow) {
        if let other = NSApp.orderedWindows.first(where: { $0.windowController is EditorWindowController && $0.isVisible }) {
            window.setFrame(other.frame, display: false)
            window.setFrameTopLeftPoint(window.cascadeTopLeft(from: NSPoint(x: other.frame.minX, y: other.frame.maxY)))
        } else if !window.setFrameUsingName(Self.frameName) {
            window.center()
        }
    }

    // MARK: - UI

    private func buildUI(storage: NSTextStorage) {
        guard let window else { return }
        let content = NSView()
        window.contentView = content

        storage.addLayoutManager(layoutManager)
        layoutManager.allowsNonContiguousLayout = true
        let container = NSTextContainer(size: NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let tv = EditorTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), textContainer: container)
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.isRichText = false
        tv.importsGraphics = false
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.usesFontPanel = true
        tv.drawsBackground = true
        tv.backgroundColor = Theme.background
        tv.insertionPointColor = Theme.text
        tv.textContainerInset = NSSize(width: 2, height: 4)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.isAutomaticTextCompletionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.smartInsertDeleteEnabled = false
        tv.delegate = self
        tv.postsFrameChangedNotifications = true
        textView = tv

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = Theme.background
        scrollView.documentView = tv
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.contentView.postsFrameChangedNotifications = true

        gutter = LineNumberView(textView: tv)
        statusBar = StatusBarView()
        statusBar.onClick = { [weak self] field, view in self?.showStatusMenu(field, from: view) }
        content.addSubview(gutter)
        content.addSubview(scrollView)
        content.addSubview(statusBar)

        statusHeight = statusBar.heightAnchor.constraint(equalToConstant: StatusBarView.height)
        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            gutter.topAnchor.constraint(equalTo: content.topAnchor),
            gutter.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            scrollView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            statusHeight,
        ])
        window.initialFirstResponder = tv

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(viewportChanged), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        nc.addObserver(self, selector: #selector(redrawGutter), name: NSView.frameDidChangeNotification, object: scrollView.contentView)
        nc.addObserver(self, selector: #selector(redrawGutter), name: NSView.frameDidChangeNotification, object: tv)
        nc.addObserver(self, selector: #selector(applySettings), name: .settingsDidChange, object: nil)
    }

    // MARK: - Settings

    @objc private func applySettings() {
        let font = Settings.font
        layoutManager.invisiblesFont = font
        layoutManager.showsInvisibles = Settings.showInvisibles
        applyBaseAttributes(font: font)
        applyWrap(Settings.wordWrap)
        textView.columnGuide = Settings.columnGuide

        gutter.editorFont = font
        gutter.font = .monospacedDigitSystemFont(ofSize: max(9, (font.pointSize * 0.85).rounded()), weight: .regular)
        gutter.isHidden = !Settings.showLineNumbers
        statusBar.isHidden = !Settings.showStatusBar
        statusHeight.constant = Settings.showStatusBar ? StatusBarView.height : 0

        runHighlight()
        updateStatus()
    }

    private func applyBaseAttributes(font: NSFont) {
        let para = NSMutableParagraphStyle()
        para.tabStops = []
        para.defaultTabInterval = 4 * (" " as NSString).size(withAttributes: [.font: font]).width
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Theme.text, .paragraphStyle: para]
        textView.defaultParagraphStyle = para
        textView.typingAttributes = attrs
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        storage.beginEditing()
        storage.setAttributes(attrs, range: NSRange(location: 0, length: storage.length))
        storage.endEditing()
    }

    private func applyWrap(_ wrap: Bool) {
        guard wrapApplied != wrap, let container = textView.textContainer else { return }
        wrapApplied = wrap
        if wrap {
            scrollView.hasHorizontalScroller = false
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            let width = scrollView.contentSize.width
            textView.setFrameSize(NSSize(width: width, height: textView.frame.height))
            container.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            container.widthTracksTextView = true
        } else {
            scrollView.hasHorizontalScroller = true
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.width, .height]
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
        gutter.needsDisplay = true
    }

    // MARK: - Document callbacks

    /// Text was replaced wholesale (Revert).
    func documentDidReload() {
        applyBaseAttributes(font: Settings.font)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        documentStateDidChange()
    }

    /// Language, line ending or encoding changed.
    func documentStateDidChange() {
        guard let doc = textDocument else { return }
        highlighter = SyntaxHighlighter.forLanguage(doc.language)
        layoutManager.lineEnding = doc.lineEnding
        runHighlight()
        updateStatus()
    }

    // MARK: - Highlighting

    @objc private func runHighlight() {
        let length = textView.textStorage?.length ?? 0
        if length <= Self.fullHighlightLimit {
            highlighter.highlight(layoutManager, in: NSRange(location: 0, length: length))
        } else {
            highlighter.highlight(layoutManager, in: visibleCharacterRange(padding: 5_000))
        }
        gutter.updateWidth(lineCount: TextUtils.newlineCount(textView.textStorage!.mutableString, upTo: length) + 1)
        gutter.needsDisplay = true
    }

    private func scheduleHighlight(after delay: TimeInterval) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(runHighlight), object: nil)
        perform(#selector(runHighlight), with: nil, afterDelay: delay)
    }

    private func visibleCharacterRange(padding: Int) -> NSRange {
        guard let container = textView.textContainer else { return NSRange(location: 0, length: 0) }
        let length = textView.textStorage?.length ?? 0
        let origin = textView.textContainerOrigin
        let rect = textView.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphs = layoutManager.glyphRange(forBoundingRect: rect, in: container)
        let chars = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        let start = max(0, chars.location - padding)
        let end = min(length, NSMaxRange(chars) + padding)
        return NSRange(location: start, length: max(0, end - start))
    }

    @objc private func viewportChanged() {
        gutter.needsDisplay = true
        if (textView.textStorage?.length ?? 0) > Self.fullHighlightLimit {
            scheduleHighlight(after: 0.05)
        }
    }

    @objc private func redrawGutter() { gutter.needsDisplay = true }

    // MARK: - NSTextViewDelegate

    func undoManager(for view: NSTextView) -> UndoManager? { textDocument?.undoManager }

    func textDidChange(_ notification: Notification) {
        // Re-color the edited line(s) right away, then the rest shortly after.
        let s = textView.textStorage!.mutableString
        let loc = min(textView.selectedRange().location, s.length)
        let from = max(0, loc - 1)
        highlighter.highlight(layoutManager, in: NSRange(location: from, length: loc - from))
        scheduleHighlight(after: 0.15)
        gutter.needsDisplay = true
        updateStatus()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        gutter.needsDisplay = true
        updateStatus()
    }

    private func updateStatus() {
        guard let doc = textDocument, !statusBar.isHidden, let storage = textView.textStorage else { return }
        let s = storage.mutableString
        let sel = textView.selectedRange()
        let loc = min(sel.location, s.length)
        let line = TextUtils.newlineCount(s, upTo: loc) + 1
        let lineStart = s.lineRange(for: NSRange(location: loc, length: 0)).location
        statusBar.update(line: line,
                         column: loc - lineStart + 1,
                         selected: sel.length,
                         language: doc.language.displayName,
                         lineEnding: doc.lineEnding.label + (doc.hasMixedLineEndings ? " (mixed)" : ""),
                         encoding: doc.encoding.label)
    }

    // MARK: - NSWindowDelegate

    func windowDidResize(_ notification: Notification) { window?.saveFrame(usingName: Self.frameName) }
    func windowDidMove(_ notification: Notification) { window?.saveFrame(usingName: Self.frameName) }

    func windowWillClose(_ notification: Notification) {
        window?.saveFrame(usingName: Self.frameName)
        NotificationCenter.default.removeObserver(self)
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }

    // MARK: - Menu actions (document-specific)

    @objc func changeLineEnding(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let ending = LineEnding(rawValue: raw) else { return }
        textDocument?.setLineEnding(ending)
    }

    @objc func changeEncoding(_ sender: NSMenuItem) {
        guard let doc = textDocument, let window,
              let raw = sender.representedObject as? String, let encoding = TextEncoding(rawValue: raw),
              encoding != doc.encoding else { return }
        guard doc.textStorage.string.canBeConverted(to: encoding.stringEncoding) else {
            let alert = NSAlert()
            alert.messageText = "\(encoding.menuTitle) can’t represent every character in this document."
            alert.informativeText = "Those characters would be lost, so the encoding wasn’t changed."
            alert.beginSheetModal(for: window)
            return
        }
        doc.setEncoding(encoding)
    }

    @objc func changeLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let language = Language(rawValue: raw) else { return }
        textDocument?.setLanguage(language)
    }

    private func showStatusMenu(_ field: StatusBarView.Field, from view: NSView) {
        let menu: NSMenu
        switch field {
        case .language: menu = FormatMenus.menu("Syntax", FormatMenus.languageItems(target: self))
        case .lineEnding: menu = FormatMenus.menu("Line Endings", FormatMenus.lineEndingItems(target: self))
        case .encoding: menu = FormatMenus.menu("Encoding", FormatMenus.encodingItems(target: self))
        }
        menu.items.forEach { _ = validateMenuItem($0) }
        let checked = menu.items.first { $0.state == .on }
        menu.popUp(positioning: checked, at: NSPoint(x: 0, y: view.isFlipped ? view.bounds.height : 0), in: view)
    }

    @objc func goToLine(_ sender: Any?) {
        guard let window, let storage = textView.textStorage else { return }
        let s = storage.mutableString
        let total = TextUtils.newlineCount(s, upTo: s.length) + 1
        let current = TextUtils.newlineCount(s, upTo: min(textView.selectedRange().location, s.length)) + 1

        let alert = NSAlert()
        alert.messageText = "Go to Line"
        alert.informativeText = "Line number (1–\(total)):"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = String(current)
        alert.accessoryView = field
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn, let self,
                  let n = Int(field.stringValue.trimmingCharacters(in: .whitespaces)) else { return }
            let loc = TextUtils.location(ofLine: n, in: s)
            self.textView.setSelectedRange(NSRange(location: loc, length: 0))
            self.textView.scrollRangeToVisible(NSRange(location: loc, length: 0))
            self.window?.makeFirstResponder(self.textView)
        }
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard let doc = textDocument else { return false }
        let rep = item.representedObject as? String
        switch item.action {
        case #selector(changeLineEnding(_:)):
            item.state = rep == doc.lineEnding.rawValue ? .on : .off
        case #selector(changeEncoding(_:)):
            item.state = rep == doc.encoding.rawValue ? .on : .off
        case #selector(changeLanguage(_:)):
            item.state = rep == doc.language.rawValue ? .on : .off
        default:
            break
        }
        return true
    }
}
