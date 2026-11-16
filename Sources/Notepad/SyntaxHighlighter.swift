import AppKit

enum Language: String, CaseIterable {
    case plainText, c, cpp, css, go, html, ini, java, javascript, json, markdown,
         python, ruby, rust, shell, sql, swift, toml, typescript, xml, yaml

    var displayName: String {
        switch self {
        case .plainText: return "Plain Text"
        case .c: return "C"
        case .cpp: return "C++"
        case .css: return "CSS"
        case .go: return "Go"
        case .html: return "HTML"
        case .ini: return "INI / Config"
        case .java: return "Java"
        case .javascript: return "JavaScript"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        case .python: return "Python"
        case .ruby: return "Ruby"
        case .rust: return "Rust"
        case .shell: return "Shell"
        case .sql: return "SQL"
        case .swift: return "Swift"
        case .toml: return "TOML"
        case .typescript: return "TypeScript"
        case .xml: return "XML"
        case .yaml: return "YAML"
        }
    }

    static func detect(url: URL?, text: String) -> Language {
        if let url {
            switch url.lastPathComponent.lowercased() {
            case "makefile", "gnumakefile", "dockerfile", "containerfile", ".env",
                 ".bashrc", ".bash_profile", ".zshrc", ".zprofile", ".zshenv", ".profile":
                return .shell
            case ".gitignore", ".gitattributes", ".gitconfig", ".editorconfig", ".npmrc":
                return .ini
            default: break
            }
            switch url.pathExtension.lowercased() {
            case "swift": return .swift
            case "py", "pyw", "pyi": return .python
            case "js", "jsx", "mjs", "cjs": return .javascript
            case "ts", "tsx", "mts", "cts": return .typescript
            case "html", "htm", "xhtml", "vue", "svelte": return .html
            case "css", "scss", "sass", "less": return .css
            case "json", "jsonc", "json5", "geojson": return .json
            case "md", "markdown", "mdown", "mkd": return .markdown
            case "rs": return .rust
            case "go": return .go
            case "c", "h", "m": return .c
            case "cpp", "cc", "cxx", "hpp", "hh", "hxx", "mm": return .cpp
            case "java": return .java
            case "rb", "rake", "gemspec": return .ruby
            case "sh", "bash", "zsh", "fish", "ksh", "command": return .shell
            case "xml", "plist", "svg", "xsd", "xsl", "xib", "storyboard", "csproj": return .xml
            case "yml", "yaml": return .yaml
            case "sql": return .sql
            case "toml": return .toml
            case "ini", "cfg", "conf", "properties", "env", "desktop": return .ini
            default: break
            }
        }
        if text.hasPrefix("#!") {
            let first = text.prefix(while: { $0 != "\n" }).lowercased()
            if first.contains("python") { return .python }
            if first.contains("node") || first.contains("deno") || first.contains("bun") { return .javascript }
            if first.contains("ruby") { return .ruby }
            if first.contains("sh") { return .shell }
        }
        if text.hasPrefix("<?xml") { return .xml }
        return .plainText
    }
}

/// Regex-based highlighter that colors via layout-manager *temporary* attributes,
/// so highlighting never touches the text storage or the undo stack.
///
/// Two passes: `tokens` (keywords, numbers, calls…) are applied first, then
/// `spans` (comments and strings) are matched as one alternation, so whichever
/// starts first wins and keywords inside strings/comments are overridden.
final class SyntaxHighlighter {
    private let tokens: [(NSRegularExpression, NSColor)]
    private let spanRegex: NSRegularExpression?
    private let spanGroups: [(name: String, color: NSColor)]

    private static var cache: [Language: SyntaxHighlighter] = [:]

    static func forLanguage(_ language: Language) -> SyntaxHighlighter {
        if let h = cache[language] { return h }
        let h = SyntaxHighlighter(language: language)
        cache[language] = h
        return h
    }

    private init(language: Language) {
        let spec = Self.spec(for: language)
        tokens = spec.tokens.compactMap { pattern, role in
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                assertionFailure("Bad token regex: \(pattern)")
                return nil
            }
            return (re, role.color)
        }
        var groups: [(String, NSColor)] = []
        var parts: [String] = []
        for (i, (pattern, role)) in spec.spans.enumerated() {
            let name = "s\(i)"
            parts.append("(?<\(name)>\(pattern))")
            groups.append((name, role.color))
        }
        spanGroups = groups
        if parts.isEmpty {
            spanRegex = nil
        } else {
            spanRegex = try? NSRegularExpression(pattern: parts.joined(separator: "|"), options: [.anchorsMatchLines])
            assert(spanRegex != nil, "Bad span regex for \(language)")
        }
    }

    func highlight(_ lm: NSLayoutManager, in requested: NSRange) {
        guard let storage = lm.textStorage, storage.length > 0 else { return }
        let ns = storage.mutableString
        let start = min(requested.location, ns.length)
        let end = min(NSMaxRange(requested), ns.length)
        let range = ns.lineRange(for: NSRange(location: start, length: end - start))
        guard range.length > 0 else { return }

        lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range)
        guard !tokens.isEmpty || spanRegex != nil else { return }

        let str = storage.string
        for (re, color) in tokens {
            re.enumerateMatches(in: str, options: [], range: range) { m, _, _ in
                guard let r = m?.range, r.length > 0 else { return }
                lm.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: r)
            }
        }
        if let re = spanRegex {
            re.enumerateMatches(in: str, options: [], range: range) { m, _, _ in
                guard let m, m.range.length > 0 else { return }
                for g in spanGroups where m.range(withName: g.name).location != NSNotFound {
                    lm.addTemporaryAttribute(.foregroundColor, value: g.color, forCharacterRange: m.range)
                    break
                }
            }
        }
    }

    // MARK: - Language definitions

    private enum Role {
        case comment, string, keyword, type, number, function, attribute
        var color: NSColor {
            switch self {
            case .comment: return Theme.comment
            case .string: return Theme.string
            case .keyword: return Theme.keyword
            case .type: return Theme.type
            case .number: return Theme.number
            case .function: return Theme.function
            case .attribute: return Theme.attribute
            }
        }
    }

    private struct Spec {
        var tokens: [(String, Role)] = []
        var spans: [(String, Role)] = []
    }

    private enum P {
        static let slashComment = #"//.*$"#
        static let blockComment = #"/\*[\s\S]*?\*/"#
        static let hashComment  = #"#.*$"#
        static let dq           = #"\"(?:[^\"\\\n]|\\.)*\""#
        static let dqMultiline  = #"\"(?:[^\"\\]|\\.)*\""#
        static let sq           = #"'(?:[^'\\\n]|\\.)*'"#
        static let charLiteral  = #"'(?:[^'\\\n]|\\.)'"#
        static let tripleDQ     = #"\"\"\"[\s\S]*?\"\"\""#
        static let tripleSQ     = #"'''[\s\S]*?'''"#
        static let backtick     = #"`(?:[^`\\]|\\.)*`"#
        static let number       = #"\b(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)\b"#
        static let call         = #"\b[A-Za-z_]\w*(?=\s*\()"#

        static func words(_ list: String, caseInsensitive: Bool = false) -> String {
            (caseInsensitive ? "(?i)" : "") + #"\b(?:"# + list.split(separator: " ").joined(separator: "|") + #")\b"#
        }
    }

    private static func spec(for lang: Language) -> Spec {
        switch lang {
        case .plainText:
            return Spec()

        case .swift:
            return Spec(tokens: [
                (P.call, .function),
                (P.words("Any AnyObject Array Bool Character Data Date Dictionary Double Error Float Int Int8 Int16 Int32 Int64 Never Optional Result Self Set String Substring UInt UInt8 UInt16 UInt32 UInt64 URL UUID Void"), .type),
                (P.words("actor any as associatedtype async await break case catch class continue default defer deinit do else enum extension fallthrough fileprivate final for func guard if import in indirect init inout internal is lazy let mutating nonisolated open operator override private protocol public repeat rethrows return self some static struct subscript super switch throw throws try typealias unowned var weak where while"), .keyword),
                (P.words("true false nil"), .number),
                (P.number, .number),
                (#"@\w+"#, .attribute),
                (#"#\w+"#, .keyword),
            ], spans: [
                (P.slashComment, .comment), (P.blockComment, .comment),
                (P.tripleDQ, .string), (P.dq, .string),
            ])

        case .python:
            return Spec(tokens: [
                (P.call, .function),
                (P.words("abs all any bool bytes dict enumerate filter float int isinstance len list map max min object open print range repr set sorted str sum super tuple type zip"), .type),
                (P.words("and as assert async await break case class continue def del elif else except finally for from global if import in is lambda match nonlocal not or pass raise return try while with yield"), .keyword),
                (P.words("True False None self cls"), .number),
                (P.number, .number),
                (#"@[\w.]+"#, .attribute),
            ], spans: [
                (P.tripleDQ, .string), (P.tripleSQ, .string),
                (P.hashComment, .comment), (P.dq, .string), (P.sq, .string),
            ])

        case .javascript, .typescript:
            return Spec(tokens: [
                (P.call, .function),
                (P.words("Array Boolean Date Error Function JSON Map Math Number Object Promise RegExp Set String Symbol console document window any boolean never number string unknown"), .type),
                (P.words("as async await break case catch class const continue debugger default delete do else enum export extends finally for from function get if implements import in instanceof interface let new of private protected public readonly return set static super switch this throw try type typeof var void while with yield"), .keyword),
                (P.words("true false null undefined NaN Infinity"), .number),
                (P.number, .number),
                (#"=>"#, .keyword),
                (#"@\w+"#, .attribute),
            ], spans: [
                (P.slashComment, .comment), (P.blockComment, .comment),
                (P.backtick, .string), (P.dq, .string), (P.sq, .string),
            ])

        case .html, .xml:
            var spans: [(String, Role)] = [
                (#"<!--[\s\S]*?-->"#, .comment),
                (#"(?<==)\s*(?:\"[^\"]*\"|'[^']*')"#, .string),
            ]
            if lang == .xml {
                spans.insert((#"<!\[CDATA\[[\s\S]*?\]\]>"#, .string), at: 1)
                spans.insert((#"<\?[\s\S]*?\?>"#, .attribute), at: 1)
            }
            return Spec(tokens: [
                (#"</?[A-Za-z][\w:.-]*"#, .keyword),
                (#"/?>"#, .keyword),
                (#"(?i)<!DOCTYPE[^>]*>"#, .keyword),
                (#"\b[A-Za-z_:@][\w:.-]*(?=\s*=)"#, .attribute),
                (#"&#?\w+;"#, .number),
            ], spans: spans)

        case .css:
            return Spec(tokens: [
                (#"[.#][A-Za-z_-][\w-]*"#, .function),
                (#"[\w-]+(?=\s*:[^:])"#, .type),
                (#"#[0-9a-fA-F]{3,8}\b"#, .number),
                (#"-?\b\d+(?:\.\d+)?(?:px|em|rem|%|vh|vw|vmin|vmax|ch|ex|pt|s|ms|deg|fr)?"#, .number),
                (#"@[\w-]+"#, .keyword),
                (#"!important"#, .keyword),
            ], spans: [
                (P.blockComment, .comment), (P.dq, .string), (P.sq, .string),
            ])

        case .json:
            return Spec(tokens: [
                (P.words("true false null"), .keyword),
                (#"-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, .number),
            ], spans: [
                (P.slashComment, .comment), (P.blockComment, .comment),
                (#"\"(?:[^\"\\\n]|\\.)*\"(?=\s*:)"#, .type),
                (P.dq, .string),
            ])

        case .markdown:
            return Spec(tokens: [
                (#"(?<![*\w])\*[^*\s][^*\n]*\*(?!\*)|(?<![_\w])_[^_\s][^_\n]*_(?!\w)"#, .attribute),
                (#"\*\*[^*\n]+\*\*|__[^_\n]+__"#, .function),
                (#"!?\[[^\]\n]*\]\([^)\n]*\)"#, .type),
                (#"^\s*(?:[-*+]|\d+\.)\s"#, .keyword),
                (#"^\s*>.*$"#, .comment),
                (#"^\s*(?:\*{3,}|-{3,}|_{3,})\s*$"#, .comment),
                (#"^#{1,6}\s.*$"#, .keyword),
            ], spans: [
                (#"^```[\s\S]*?^```"#, .string),
                (#"`[^`\n]+`"#, .string),
            ])

        case .rust:
            return Spec(tokens: [
                (P.call, .function),
                (#"\b[A-Za-z_]\w*!"#, .function),
                (P.words("bool char f32 f64 i8 i16 i32 i64 i128 isize str u8 u16 u32 u64 u128 usize Box Option Result String Vec HashMap HashSet Rc Arc RefCell Some None Ok Err"), .type),
                (P.words("as async await break const continue crate dyn else enum extern fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait type union unsafe use where while"), .keyword),
                (P.words("true false"), .number),
                (P.number, .number),
                (#"'[A-Za-z_]\w*\b(?!')"#, .attribute),
                (#"#!?\[[^\]\n]*\]"#, .attribute),
            ], spans: [
                (P.slashComment, .comment), (P.blockComment, .comment),
                (P.dqMultiline, .string), (P.charLiteral, .string),
            ])

        case .go:
            return Spec(tokens: [
                (P.call, .function),
                (P.words("any bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16 uint32 uint64 uintptr"), .type),
                (P.words("break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var"), .keyword),
                (P.words("true false iota nil"), .number),
                (P.number, .number),
            ], spans: [
                (P.slashComment, .comment), (P.blockComment, .comment),
                (#"`[^`]*`"#, .string), (P.dq, .string), (P.sq, .string),
            ])

        case .c, .cpp:
            return Spec(tokens: [
                (P.call, .function),
                (P.words("bool char double float int long short signed unsigned void size_t ssize_t int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t std string vector map set unique_ptr shared_ptr id instancetype"), .type),
                (P.words("alignas alignof auto break case catch class const constexpr continue decltype default delete do else enum explicit export extern for friend goto if inline mutable namespace new noexcept operator private protected public register return sizeof static static_assert struct switch template this throw try typedef typename union using virtual volatile while"), .keyword),
                (P.words("true false NULL nullptr YES NO nil"), .number),
                (P.number, .number),
                (#"^\s*#\s*[a-z]+"#, .attribute),
                (#"@\w+"#, .attribute),
            ], spans: [
                (P.slashComment, .comment), (P.blockComment, .comment),
                (#"(?<=#include)\s*<[^>\n]*>"#, .string),
                (P.dq, .string), (P.charLiteral, .string),
            ])

        case .java:
            return Spec(tokens: [
                (P.call, .function),
                (P.words("boolean byte char double float int long short String Integer Long Double Float Boolean Character Object List Map Set Optional"), .type),
                (P.words("abstract assert break case catch class continue default do else enum extends final finally for if implements import instanceof interface native new package permits private protected public record return sealed static super switch synchronized this throw throws transient try var void volatile while yield"), .keyword),
                (P.words("true false null"), .number),
                (P.number, .number),
                (#"@\w+"#, .attribute),
            ], spans: [
                (P.slashComment, .comment), (P.blockComment, .comment),
                (P.tripleDQ, .string), (P.dq, .string), (P.charLiteral, .string),
            ])

        case .ruby:
            return Spec(tokens: [
                (P.call, .function),
                (#"\b[A-Z]\w*"#, .type),
                (P.words("alias and begin break case class def defined do else elsif end ensure for if in include module next not or redo require rescue retry return super then undef unless until when while yield"), .keyword),
                (P.words("true false nil self"), .number),
                (P.number, .number),
                (#"(?<![:\w]):[A-Za-z_]\w*[?!]?"#, .string),
                (#"@{1,2}\w+"#, .attribute),
            ], spans: [
                (#"^=begin[\s\S]*?^=end"#, .comment),
                (P.hashComment, .comment), (P.dq, .string), (P.sq, .string),
            ])

        case .shell:
            return Spec(tokens: [
                (P.words("alias awk bg cat cd chmod chown command cp curl echo eval exec exit export fg find git grep ls mkdir mv printf pwd read readonly rm sed set shift source sudo tar test trap ulimit umask unalias unset wait"), .function),
                (P.words("case do done elif else esac fi for function if in local return select then until while"), .keyword),
                (#"\$(?:\{[^}\n]*\}|[A-Za-z_]\w*|[0-9@*#?$!-])"#, .attribute),
                (P.number, .number),
            ], spans: [
                (#"(?<![\w$\{#])#.*$"#, .comment),
                (P.dqMultiline, .string),
                (#"'[^']*'"#, .string),
            ])

        case .yaml:
            return Spec(tokens: [
                (#"^[ \t]*(?:- +)?[\w$][\w$ .\-/]*(?=:(?:[ \t]|$))"#, .type),
                (P.words("true false yes no on off null True False Null TRUE FALSE NULL"), .keyword),
                (P.number, .number),
                (#"(?<=\s)[&*][\w-]+"#, .attribute),
                (#"^(?:---|\.\.\.)\s*$"#, .comment),
            ], spans: [
                (#"(?:^|(?<=\s))#.*$"#, .comment),
                (P.dq, .string), (#"'[^'\n]*'"#, .string),
            ])

        case .sql:
            return Spec(tokens: [
                (P.call, .function),
                (P.words("bigint blob boolean char date datetime decimal double float int integer json jsonb numeric real serial smallint text time timestamp uuid varchar", caseInsensitive: true), .type),
                (P.words("add all alter and as asc begin between by case check column commit constraint create cross database default delete desc distinct drop else end exists foreign from full group having if in index inner insert into is join key left like limit not null offset on or order outer primary references returning right rollback select set table then transaction truncate union unique update using values view when where with", caseInsensitive: true), .keyword),
                (P.words("true false", caseInsensitive: true), .number),
                (P.number, .number),
            ], spans: [
                (#"--.*$"#, .comment), (P.blockComment, .comment),
                (#"'(?:[^']|'')*'"#, .string), (P.dq, .type),
            ])

        case .toml:
            return Spec(tokens: [
                (#"^\s*\[\[?[^\]\n]*\]\]?"#, .keyword),
                (#"^\s*[\w.\-]+(?=\s*=)"#, .type),
                (P.words("true false"), .number),
                (P.number, .number),
            ], spans: [
                (P.hashComment, .comment),
                (P.tripleDQ, .string), (P.tripleSQ, .string),
                (P.dq, .string), (#"'[^'\n]*'"#, .string),
            ])

        case .ini:
            return Spec(tokens: [
                (#"^\s*\[[^\]\n]*\]"#, .keyword),
                (#"^\s*[^=:\s;#\[][^=:\n]*?(?=\s*[=:])"#, .type),
                (P.words("true false yes no on off", caseInsensitive: true), .number),
                (P.number, .number),
            ], spans: [
                (#"^\s*[;#].*$"#, .comment),
                (P.dq, .string),
            ])
        }
    }
}
