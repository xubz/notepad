import AppKit

enum LineEnding: String, CaseIterable {
    case lf, crlf, cr

    var characters: String {
        switch self {
        case .lf: return "\n"
        case .crlf: return "\r\n"
        case .cr: return "\r"
        }
    }

    var label: String { rawValue.uppercased() }

    var menuTitle: String {
        switch self {
        case .lf: return "LF (macOS / Unix)"
        case .crlf: return "CRLF (Windows)"
        case .cr: return "CR (Classic Mac OS)"
        }
    }

    /// Detects the dominant line ending and returns the text normalized to "\n".
    static func analyze(_ text: String) -> (ending: LineEnding, mixed: Bool, normalized: String) {
        var lf = 0, crlf = 0, cr = 0
        var prevCR = false
        for u in text.utf16 {
            if u == 0x0D {
                if prevCR { cr += 1 }
                prevCR = true
                continue
            }
            if u == 0x0A {
                if prevCR { crlf += 1 } else { lf += 1 }
            } else if prevCR {
                cr += 1
            }
            prevCR = false
        }
        if prevCR { cr += 1 }

        let ending: LineEnding
        if crlf > lf && crlf >= cr { ending = .crlf }
        else if cr > lf && cr > crlf { ending = .cr }
        else { ending = .lf }

        guard crlf + cr > 0 else { return (ending, false, text) }
        let mixed = [lf, crlf, cr].filter { $0 > 0 }.count > 1
        let normalized = (text as NSString)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return (ending, mixed, normalized)
    }
}

enum TextEncoding: String, CaseIterable {
    case utf8, utf8BOM, utf16LE, utf16BE, windows1252, latin1

    var label: String {
        switch self {
        case .utf8: return "UTF-8"
        case .utf8BOM: return "UTF-8 BOM"
        case .utf16LE: return "UTF-16 LE"
        case .utf16BE: return "UTF-16 BE"
        case .windows1252: return "Windows-1252"
        case .latin1: return "ISO Latin 1"
        }
    }

    var menuTitle: String {
        switch self {
        case .utf8: return "UTF-8"
        case .utf8BOM: return "UTF-8 with BOM"
        case .utf16LE: return "UTF-16 Little Endian"
        case .utf16BE: return "UTF-16 Big Endian"
        case .windows1252: return "Western (Windows-1252)"
        case .latin1: return "Western (ISO Latin 1)"
        }
    }

    var stringEncoding: String.Encoding {
        switch self {
        case .utf8, .utf8BOM: return .utf8
        case .utf16LE: return .utf16LittleEndian
        case .utf16BE: return .utf16BigEndian
        case .windows1252: return .windowsCP1252
        case .latin1: return .isoLatin1
        }
    }

    private var bom: [UInt8] {
        switch self {
        case .utf8BOM: return [0xEF, 0xBB, 0xBF]
        case .utf16LE: return [0xFF, 0xFE]
        case .utf16BE: return [0xFE, 0xFF]
        default: return []
        }
    }

    static func decode(_ data: Data) -> (String, TextEncoding) {
        let head = [UInt8](data.prefix(3))
        if head.starts(with: [0xEF, 0xBB, 0xBF]), let s = String(data: data.dropFirst(3), encoding: .utf8) {
            return (s, .utf8BOM)
        }
        if head.starts(with: [0xFF, 0xFE]), let s = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) {
            return (s, .utf16LE)
        }
        if head.starts(with: [0xFE, 0xFF]), let s = String(data: data.dropFirst(2), encoding: .utf16BigEndian) {
            return (s, .utf16BE)
        }
        if let s = String(data: data, encoding: .utf8) { return (s, .utf8) }
        if let s = String(data: data, encoding: .windowsCP1252) { return (s, .windows1252) }
        return (String(data: data, encoding: .isoLatin1) ?? "", .latin1)
    }

    func encode(_ s: String) -> Data? {
        guard let body = s.data(using: stringEncoding, allowLossyConversion: false) else { return nil }
        return Data(bom) + body
    }
}

/// One plain-text file. The text lives in `textStorage` with "\n" line endings;
/// the file's original line ending and encoding are restored on save.
@objc(TextDocument)
final class TextDocument: NSDocument {
    let textStorage = NSTextStorage()
    private(set) var lineEnding: LineEnding = .lf
    private(set) var encoding: TextEncoding = .utf8
    private(set) var hasMixedLineEndings = false
    private(set) var language: Language = .plainText
    private var languageIsManual = false

    override class var autosavesInPlace: Bool { false }   // classic Save / Save As
    override class var preservesVersions: Bool { false }

    /// An untouched, empty "Untitled" window: Open replaces it instead of adding a window.
    var isBlankUntitled: Bool { fileURL == nil && !isDocumentEdited && textStorage.length == 0 }

    override func makeWindowControllers() {
        addWindowController(EditorWindowController(document: self))
    }

    // MARK: - Reading / writing

    override func read(from url: URL, ofType typeName: String) throws {
        let data = try Data(contentsOf: url)
        let (decoded, enc) = TextEncoding.decode(data)
        let analysis = LineEnding.analyze(decoded)
        encoding = enc
        lineEnding = analysis.ending
        hasMixedLineEndings = analysis.mixed
        if !languageIsManual { language = Language.detect(url: url, text: analysis.normalized) }
        textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: analysis.normalized)
        undoManager?.removeAllActions()
        for wc in windowControllers { (wc as? EditorWindowController)?.documentDidReload() }
    }

    override func data(ofType typeName: String) throws -> Data {
        var text = textStorage.string
        if lineEnding != .lf {
            text = (text as NSString).replacingOccurrences(of: "\n", with: lineEnding.characters)
        }
        guard let data = encoding.encode(text) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding, userInfo: [
                NSLocalizedDescriptionKey: "The document can’t be saved as \(encoding.menuTitle).",
                NSLocalizedRecoverySuggestionErrorKey: "It contains characters that encoding can’t represent. Choose Format ▸ Encoding ▸ UTF-8 and save again.",
            ])
        }
        return data
    }

    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType,
                       completionHandler: @escaping (Error?) -> Void) {
        super.save(to: url, ofType: typeName, for: saveOperation) { [weak self] error in
            if error == nil, let self, saveOperation == .saveOperation || saveOperation == .saveAsOperation {
                self.hasMixedLineEndings = false
                if saveOperation == .saveAsOperation && !self.languageIsManual {
                    let head = self.textStorage.mutableString.substring(to: min(200, self.textStorage.length))
                    self.language = Language.detect(url: url, text: head)
                }
                self.notifyStateChange()
            }
            completionHandler(error)
        }
    }

    // MARK: - Save panel: allow any file name / extension

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        savePanel.allowedContentTypes = []
        savePanel.allowsOtherFileTypes = true
        savePanel.isExtensionHidden = false
        savePanel.canSelectHiddenExtension = false
        return true
    }

    override var shouldRunSavePanelWithAccessoryView: Bool { false }

    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        [fileType ?? "public.plain-text"]
    }

    override func fileNameExtension(forType typeName: String, saveOperation: NSDocument.SaveOperationType) -> String? {
        if let ext = fileURL?.pathExtension, !ext.isEmpty { return ext }
        return "txt"
    }

    // MARK: - Format changes (undoable, so they mark the document edited)

    func setLineEnding(_ new: LineEnding) {
        let old = lineEnding
        guard new != old || hasMixedLineEndings else { return }
        undoManager?.registerUndo(withTarget: self) { $0.setLineEnding(old) }
        undoManager?.setActionName("Change Line Endings")
        lineEnding = new
        hasMixedLineEndings = false
        notifyStateChange()
    }

    func setEncoding(_ new: TextEncoding) {
        let old = encoding
        guard new != old else { return }
        undoManager?.registerUndo(withTarget: self) { $0.setEncoding(old) }
        undoManager?.setActionName("Change Encoding")
        encoding = new
        notifyStateChange()
    }

    func setLanguage(_ new: Language) {
        languageIsManual = true
        language = new
        notifyStateChange()
    }

    private func notifyStateChange() {
        for wc in windowControllers { (wc as? EditorWindowController)?.documentStateDidChange() }
    }
}
