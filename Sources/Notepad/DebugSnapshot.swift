#if DEBUG
import AppKit

/// Debug-only self-test hook (not compiled into release builds):
///   NOTEPAD_OPEN=<file>  NOTEPAD_SNAPSHOT=<png>  [NOTEPAD_APPEARANCE=dark]  .build/debug/Notepad
/// opens the file, renders the front window to a PNG and quits.
/// NOTEPAD_OPEN alone just opens the file and keeps running (used by launch.json).
enum DebugSnapshot {
    static func runIfRequested() {
        let env = ProcessInfo.processInfo.environment
        if env["NOTEPAD_APPEARANCE"] == "dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        if env["NOTEPAD_APPEARANCE"] == "light" { NSApp.appearance = NSAppearance(named: .aqua) }
        if let path = env["NOTEPAD_OPEN"] {
            NSDocumentController.shared.openDocument(withContentsOf: URL(fileURLWithPath: path), display: true) { _, _, error in
                if let error { print("open failed: \(error)") }
            }
        }
        guard let out = env["NOTEPAD_SNAPSHOT"] else { return }   // no snapshot: keep running normally
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let window = NSApp.orderedWindows.first(where: { $0.windowController is EditorWindowController }),
                  let view = window.contentView?.superview else { print("no window"); exit(1) }
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
            print("title=\(window.title) docs=\(NSDocumentController.shared.documents.count)")
            if let saveTo = env["NOTEPAD_SAVE_TO"], let doc = NSDocumentController.shared.documents.first(where: { $0.fileURL != nil }) {
                doc.save(to: URL(fileURLWithPath: saveTo), ofType: doc.fileType ?? "public.plain-text",
                         for: .saveToOperation) { error in
                    print(error.map { "save failed: \($0)" } ?? "saved")
                    exit(0)
                }
                return
            }
            exit(0)
        }
    }
}
#endif
