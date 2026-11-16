import Foundation

enum TextUtils {
    /// Number of "\n" characters in `s[0..<end]`. Reads the string in chunks, so
    /// it stays fast on multi-megabyte files.
    static func newlineCount(_ s: NSString, upTo end: Int) -> Int {
        let end = min(end, s.length)
        let chunk = 16_384
        var buffer = [unichar](repeating: 0, count: chunk)
        var count = 0
        var pos = 0
        while pos < end {
            let n = min(chunk, end - pos)
            buffer.withUnsafeMutableBufferPointer { p in
                s.getCharacters(p.baseAddress!, range: NSRange(location: pos, length: n))
                for i in 0..<n where p[i] == 0x0A { count += 1 }
            }
            pos += n
        }
        return count
    }

    /// Character offset where 1-based `line` starts (clamped to the last line).
    static func location(ofLine line: Int, in s: NSString) -> Int {
        guard line > 1 else { return 0 }
        var remaining = line - 1
        let chunk = 16_384
        var buffer = [unichar](repeating: 0, count: chunk)
        var pos = 0
        while pos < s.length {
            let n = min(chunk, s.length - pos)
            var found: Int?
            buffer.withUnsafeMutableBufferPointer { p in
                s.getCharacters(p.baseAddress!, range: NSRange(location: pos, length: n))
                for i in 0..<n where p[i] == 0x0A {
                    remaining -= 1
                    if remaining == 0 { found = pos + i + 1; return }
                }
            }
            if let found { return found }
            pos += n
        }
        return s.lineRange(for: NSRange(location: s.length, length: 0)).location
    }
}
