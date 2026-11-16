import AppKit

// The first NSDocumentController created becomes the shared one, so this must
// happen before anything touches NSDocumentController.shared.
_ = DocumentController()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
