import AppKit

final class StatusBarView: NSView {
    static let height: CGFloat = 22

    enum Field { case language, lineEnding, encoding }

    /// Called when one of the right-hand fields is clicked.
    var onClick: ((Field, NSView) -> Void)?

    private let position = NSTextField(labelWithString: "Ln 1, Col 1")
    private let language = StatusBarView.makeButton(tip: "Syntax (click to change)")
    private let lineEnding = StatusBarView.makeButton(tip: "Line endings (click to change)")
    private let encoding = StatusBarView.makeButton(tip: "Encoding (click to change)")

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        position.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        position.textColor = Theme.statusText
        position.lineBreakMode = .byTruncatingTail
        position.translatesAutoresizingMaskIntoConstraints = false
        position.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(position)

        language.target = self; language.action = #selector(clicked(_:))
        lineEnding.target = self; lineEnding.action = #selector(clicked(_:))
        encoding.target = self; encoding.action = #selector(clicked(_:))

        let fields = NSStackView(views: [language, lineEnding, encoding])
        fields.orientation = .horizontal
        fields.spacing = 6
        fields.translatesAutoresizingMaskIntoConstraints = false
        fields.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        addSubview(fields)

        NSLayoutConstraint.activate([
            position.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            position.centerYAnchor.constraint(equalTo: centerYAnchor),
            fields.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            fields.centerYAnchor.constraint(equalTo: centerYAnchor),
            fields.leadingAnchor.constraint(greaterThanOrEqualTo: position.trailingAnchor, constant: 12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private static func makeButton(tip: String) -> NSButton {
        let b = NSButton(title: "", target: nil, action: nil)
        b.isBordered = false
        b.bezelStyle = .inline
        b.toolTip = tip
        b.setButtonType(.momentaryPushIn)
        return b
    }

    private func setTitle(_ button: NSButton, _ text: String) {
        button.attributedTitle = NSAttributedString(string: " \(text) ", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: Theme.statusText,
        ])
    }

    @objc private func clicked(_ sender: NSButton) {
        let field: Field = sender === language ? .language : sender === lineEnding ? .lineEnding : .encoding
        onClick?(field, sender)
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.statusBackground.setFill()
        bounds.fill()
        Theme.gutterBorder.setFill()
        NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
    }

    func update(line: Int, column: Int, selected: Int, language: String, lineEnding: String, encoding: String) {
        position.stringValue = "Ln \(line), Col \(column)" + (selected > 0 ? "   (\(selected) selected)" : "")
        setTitle(self.language, language)
        setTitle(self.lineEnding, lineEnding)
        setTitle(self.encoding, encoding)
    }
}
