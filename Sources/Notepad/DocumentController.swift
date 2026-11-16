import AppKit

final class DocumentController: NSDocumentController {
    override var defaultType: String? { "public.plain-text" }

    override func documentClass(forType typeName: String) -> AnyClass? { TextDocument.self }

    /// Let the Open panel pick any file, not just known text types.
    override func runModalOpenPanel(_ openPanel: NSOpenPanel, forTypes types: [String]?) -> Int {
        openPanel.treatsFilePackagesAsDirectories = true
        return super.runModalOpenPanel(openPanel, forTypes: nil)
    }

    /// Like Notepad: opening a file while the only window is a blank Untitled
    /// replaces that window instead of adding a second one.
    override func openDocument(withContentsOf url: URL, display displayDocument: Bool,
                               completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
        let blank = documents.count == 1 ? (documents.first as? TextDocument).flatMap { $0.isBlankUntitled ? $0 : nil } : nil
        let frame = blank?.windowControllers.first?.window?.frame
        super.openDocument(withContentsOf: url, display: displayDocument) { doc, wasOpen, error in
            if let doc, let blank, doc !== blank, error == nil {
                if let frame, let window = doc.windowControllers.first?.window {
                    window.setFrame(frame, display: true)
                }
                blank.close()
            }
            completionHandler(doc, wasOpen, error)
        }
    }
}
