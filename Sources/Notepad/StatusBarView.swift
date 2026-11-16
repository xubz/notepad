import AppKit

final class StatusBarView: NSView {
    static let height: CGFloat = 22

    private let left = NSTextField(labelWithString: "Ln 1, Col 1")
    private let right = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        for label in [left, right] {
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            label.textColor = Theme.statusText
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            addSubview(label)
        }
        right.alignment = .right
        right.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        left.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            left.centerYAnchor.constraint(equalTo: centerYAnchor),
            right.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            right.centerYAnchor.constraint(equalTo: centerYAnchor),
            right.leadingAnchor.constraint(greaterThanOrEqualTo: left.trailingAnchor, constant: 12),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        Theme.statusBackground.setFill()
        bounds.fill()
        Theme.gutterBorder.setFill()
        NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
    }

    func update(line: Int, column: Int, selected: Int, language: String, lineEnding: String, encoding: String) {
        left.stringValue = "Ln \(line), Col \(column)" + (selected > 0 ? "   (\(selected) selected)" : "")
        right.stringValue = [language, lineEnding, encoding].joined(separator: "     ")
    }
}
