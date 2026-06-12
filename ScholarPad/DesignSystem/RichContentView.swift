import Foundation
import SwiftUI

/// Renders imported course text without exposing Markdown, HTML table, or LaTeX syntax.
struct RichContentView: View {
    let content: String
    var bodyFont: Font = .body
    var headingFont: Font = .headline
    var textColor: Color = .primary
    var headingColor: Color = .primary
    var accentColor: Color = .indigo
    var lineSpacing: CGFloat = 5

    private var blocks: [RichContentBlock] {
        RichContentParser.blocks(from: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: RichContentBlock) -> some View {
        switch block {
        case .paragraph(let text):
            RichInlineText(text, font: bodyFont, color: textColor, lineSpacing: lineSpacing)

        case .heading(let level, let text):
            RichInlineText(
                text,
                font: level <= 2 ? headingFont : bodyFont.weight(.semibold),
                color: headingColor,
                lineSpacing: lineSpacing
            )
            .padding(.top, level <= 2 ? 5 : 2)

        case .listItem(let marker, let text):
            HStack(alignment: .top, spacing: 10) {
                Text(marker)
                    .font(bodyFont.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .frame(minWidth: 18, alignment: .trailing)
                RichInlineText(text, font: bodyFont, color: textColor, lineSpacing: lineSpacing)
            }

        case .quote(let text):
            RichInlineText(text, font: bodyFont, color: textColor, lineSpacing: lineSpacing)
                .padding(.leading, 13)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor.opacity(0.55))
                        .frame(width: 4)
                }

        case .formula(let formula):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(RichContentFormatter.formulaText(formula))
                    .font(.system(.callout, design: .monospaced).weight(.medium))
                    .foregroundStyle(headingColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
            }
            .background(accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accentColor.opacity(0.16), lineWidth: 1)
            }

        case .table(let rows):
            RichTableView(
                rows: rows,
                font: bodyFont,
                textColor: textColor,
                headingColor: headingColor,
                accentColor: accentColor,
                lineSpacing: lineSpacing
            )
        }
    }
}

struct RichInlineText: View {
    let content: String
    var font: Font = .body
    var color: Color = .primary
    var lineSpacing: CGFloat = 4

    init(_ content: String, font: Font = .body, color: Color = .primary, lineSpacing: CGFloat = 4) {
        self.content = content
        self.font = font
        self.color = color
        self.lineSpacing = lineSpacing
    }

    var body: some View {
        Text(RichContentFormatter.attributedText(content))
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }
}

enum ContentText {
    static func normalized(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{2060}", with: "")
            .precomposedStringWithCanonicalMapping

        var result = ""
        for scalar in normalized.unicodeScalars
        where scalar == "\n" || scalar == "\t" || !CharacterSet.controlCharacters.contains(scalar) {
            result.unicodeScalars.append(scalar)
        }
        return result
    }
}

private enum RichContentBlock {
    case paragraph(String)
    case heading(Int, String)
    case listItem(String, String)
    case quote(String)
    case formula(String)
    case table([[String]])
}

private enum RichContentParser {
    static func blocks(from source: String) -> [RichContentBlock] {
        let lines = ContentText.normalized(source).components(separatedBy: "\n")
        var blocks: [RichContentBlock] = []
        var paragraph: [String] = []
        var index = 0

        func flushParagraph() {
            let value = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                blocks.append(.paragraph(value))
            }
            paragraph.removeAll(keepingCapacity: true)
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if trimmed.range(of: "<table", options: [.caseInsensitive]) != nil {
                flushParagraph()
                var html = line
                while html.range(of: "</table>", options: [.caseInsensitive]) == nil, index + 1 < lines.count {
                    index += 1
                    html += "\n" + lines[index]
                }
                let rows = htmlTableRows(html)
                if rows.isEmpty {
                    paragraph.append(RichContentFormatter.strippingHTML(html))
                } else {
                    blocks.append(.table(rows))
                }
                index += 1
                continue
            }

            if isMarkdownTableStart(lines: lines, index: index) {
                flushParagraph()
                var tableLines: [String] = []
                while index < lines.count, looksLikeMarkdownTableRow(lines[index]) {
                    tableLines.append(lines[index])
                    index += 1
                }
                let rows = tableLines
                    .filter { !isMarkdownSeparatorRow($0) }
                    .map(markdownCells)
                    .filter { !$0.isEmpty }
                if !rows.isEmpty {
                    blocks.append(.table(rows))
                }
                continue
            }

            if trimmed.hasPrefix("$$") {
                flushParagraph()
                var formula = trimmed
                while !formula.hasSuffix("$$") || formula == "$$", index + 1 < lines.count {
                    index += 1
                    formula += "\n" + lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
                }
                blocks.append(.formula(formula.replacingOccurrences(of: "$$", with: "")))
                index += 1
                continue
            }

            if let heading = heading(in: trimmed) {
                flushParagraph()
                blocks.append(.heading(heading.level, heading.text))
                index += 1
                continue
            }

            if let item = listItem(in: trimmed) {
                flushParagraph()
                blocks.append(.listItem(item.marker, item.text))
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                blocks.append(.quote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)))
                index += 1
                continue
            }

            paragraph.append(line)
            index += 1
        }

        flushParagraph()
        return blocks
    }

    private static func heading(in line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }
        guard !hashes.isEmpty, hashes.count <= 6 else { return nil }
        let remainder = line.dropFirst(hashes.count)
        guard remainder.first == " " else { return nil }
        return (hashes.count, remainder.trimmingCharacters(in: .whitespaces))
    }

    private static func listItem(in line: String) -> (marker: String, text: String)? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return ("•", String(line.dropFirst(2)))
        }

        guard let match = firstMatch(#"^(\d+)[.、]\s+(.+)$"#, in: line), match.count == 2 else {
            return nil
        }
        return ("\(match[0]).", match[1])
    }

    private static func isMarkdownTableStart(lines: [String], index: Int) -> Bool {
        guard looksLikeMarkdownTableRow(lines[index]), index + 1 < lines.count else { return false }
        return isMarkdownSeparatorRow(lines[index + 1])
    }

    private static func looksLikeMarkdownTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count > 2
    }

    private static func isMarkdownSeparatorRow(_ line: String) -> Bool {
        let cells = markdownCells(line)
        return !cells.isEmpty && cells.allSatisfy { cell in
            let value = cell.replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
            return value.count >= 3 && value.allSatisfy { $0 == "-" }
        }
    }

    private static func markdownCells(_ line: String) -> [String] {
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("|") { value.removeFirst() }
        if value.hasSuffix("|") { value.removeLast() }

        var cells: [String] = []
        var current = ""
        var escaped = false
        for character in value {
            if character == "|" && !escaped {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
            escaped = character == "\\" && !escaped
            if character != "\\" { escaped = false }
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }

    private static func htmlTableRows(_ html: String) -> [[String]] {
        matches(#"(?is)<tr\b[^>]*>(.*?)</tr>"#, in: html).compactMap { rowHTML in
            let cells = matches(#"(?is)<t[hd]\b[^>]*>(.*?)</t[hd]>"#, in: rowHTML)
                .map {
                    RichContentFormatter.strippingHTML($0)
                        .replacingOccurrences(of: #"\\n"#, with: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            return cells.isEmpty ? nil : cells
        }
    }

    private static func matches(_ pattern: String, in value: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..., in: value)
        return regex.matches(in: value, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let swiftRange = Range(match.range(at: 1), in: value) else {
                return nil
            }
            return String(value[swiftRange])
        }
    }

    private static func firstMatch(_ pattern: String, in value: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = regex.firstMatch(in: value, range: range) else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            guard let swiftRange = Range(match.range(at: index), in: value) else { return nil }
            return String(value[swiftRange])
        }
    }
}

private struct RichTableView: View {
    let rows: [[String]]
    let font: Font
    let textColor: Color
    let headingColor: Color
    let accentColor: Color
    let lineSpacing: CGFloat

    private var columnCount: Int {
        rows.map(\.count).max() ?? 0
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow(alignment: .top) {
                        ForEach(0..<columnCount, id: \.self) { columnIndex in
                            RichInlineText(
                                row.indices.contains(columnIndex) ? row[columnIndex] : "",
                                font: rowIndex == 0 ? font.weight(.semibold) : font,
                                color: rowIndex == 0 ? headingColor : textColor,
                                lineSpacing: lineSpacing
                            )
                            .frame(
                                minWidth: columnIndex == 0 ? 130 : 105,
                                maxWidth: columnIndex == 0 ? 300 : 240,
                                alignment: .leading
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(rowIndex == 0 ? accentColor.opacity(0.12) : Color.clear)
                            .overlay(alignment: .trailing) {
                                Divider().opacity(0.55)
                            }
                            .overlay(alignment: .bottom) {
                                Divider().opacity(0.55)
                            }
                        }
                    }
                }
            }
            .background(Color.primary.opacity(0.018))
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }
}

enum RichContentFormatter {
    static func attributedText(_ source: String) -> AttributedString {
        let cleaned = inlineText(source)
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: cleaned, options: options)) ?? AttributedString(cleaned)
    }

    static func strippingHTML(_ source: String) -> String {
        var value = source
        value = replacing(#"(?i)<br\s*/?>"#, in: value, with: "\n")
        value = replacing(#"(?i)</(?:p|div|li|tr)>"#, in: value, with: "\n")
        value = replacing(#"(?i)<li\b[^>]*>"#, in: value, with: "• ")
        value = replacing(#"(?is)</?[A-Za-z][^>]*>"#, in: value, with: "")
        return decodeHTMLEntities(value)
    }

    static func previewText(_ source: String) -> String {
        var value = inlineText(source)
        value = replacing(#"(?m)^\s{0,3}#{1,6}\s+"#, in: value, with: "")
        value = replacing(#"(?m)^\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*$"#, in: value, with: "")
        value = value.replacingOccurrences(of: "|", with: " · ")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
        value = replacing(#"\s+"#, in: value, with: " ")
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func formulaText(_ source: String) -> String {
        var value = ContentText.normalized(source)
        value = replacing(#"\\begin\{(?:aligned|array|matrix|cases)\}"#, in: value, with: "")
        value = replacing(#"\\end\{(?:aligned|array|matrix|cases)\}"#, in: value, with: "")
        value = value.replacingOccurrences(of: "\\\\", with: "\n")
        value = value.replacingOccurrences(of: "&=", with: " = ")
        value = value.replacingOccurrences(of: "&", with: " ")

        for _ in 0..<4 {
            value = replacing(#"\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}"#, in: value, with: "($1) ÷ ($2)")
            value = replacing(#"\\sqrt\s*\{([^{}]+)\}"#, in: value, with: "√($1)")
            value = replacing(#"\\(?:text|mathrm|mathbf|operatorname)\s*\{([^{}]*)\}"#, in: value, with: "$1")
        }

        let replacements: [(String, String)] = [
            (#"\\left"#, ""), (#"\\right"#, ""), (#"\\times"#, "×"), (#"\\div"#, "÷"),
            (#"\\cdot"#, "·"), (#"\\approx"#, "≈"), (#"\\geq?"#, "≥"), (#"\\leq?"#, "≤"),
            (#"\\neq"#, "≠"), (#"\\pm"#, "±"), (#"\\rightarrow"#, "→"), (#"\\to"#, "→"),
            (#"\\infty"#, "∞"), (#"\\pi"#, "π"), (#"\\triangle"#, "△"), (#"\\angle"#, "∠"),
            (#"\\neg"#, "¬"), (#"\\cup"#, "∪"), (#"\\cap"#, "∩"), (#"\\in"#, "∈"),
            (#"\\sum"#, "Σ"), (#"\\Delta"#, "Δ"), (#"\\alpha"#, "α"), (#"\\beta"#, "β"),
            (#"\\theta"#, "θ"), (#"\\lambda"#, "λ"), (#"\\mu"#, "μ"), (#"\\%+"#, "%"),
            (#"\\circ"#, "°"), (#"\\quad"#, "  "), (#"\\,"#, " "), (#"\\;"#, " ")
        ]
        for (pattern, replacement) in replacements {
            value = replacing(pattern, in: value, with: replacement)
        }

        value = replacing(#"\^\{([^{}]+)\}"#, in: value) {
            scripted($0, using: superscriptCharacters) ?? "^(\($0))"
        }
        value = replacing(#"_\{([^{}]+)\}"#, in: value) {
            scripted($0, using: subscriptCharacters) ?? "_(\($0))"
        }
        value = replacing(#"\^([0-9+\-=()]+)"#, in: value) {
            scripted($0, using: superscriptCharacters) ?? "^(\($0))"
        }
        value = replacing(#"_([0-9+\-=()]+)"#, in: value) {
            scripted($0, using: subscriptCharacters) ?? "_(\($0))"
        }
        value = replacing(#"\\([A-Za-z]+)"#, in: value, with: "$1")
        value = value.replacingOccurrences(of: "{", with: "(")
            .replacingOccurrences(of: "}", with: ")")
        value = replacing(#"[ \t]{2,}"#, in: value, with: " ")
        value = replacing(#"\n[ \t]+"#, in: value, with: "\n")
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func inlineText(_ source: String) -> String {
        var value = strippingHTML(ContentText.normalized(source))
        value = replacing(#"(?s)\$\$(.+?)\$\$"#, in: value) { formulaText($0) }
        value = replacing(#"(?s)(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)"#, in: value) { formulaText($0) }
        return value
    }

    private static func decodeHTMLEntities(_ source: String) -> String {
        var value = source
        let named: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'"
        ]
        for (entity, replacement) in named {
            value = value.replacingOccurrences(of: entity, with: replacement)
        }

        return replacing(#"&#(x[0-9A-Fa-f]+|\d+);"#, in: value) { token in
            let number: UInt32?
            if token.lowercased().hasPrefix("x") {
                number = UInt32(token.dropFirst(), radix: 16)
            } else {
                number = UInt32(token, radix: 10)
            }
            guard let number, let scalar = UnicodeScalar(number) else { return "�" }
            return String(scalar)
        }
    }

    private static let superscriptCharacters: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "n": "ⁿ", "i": "ⁱ"
    ]

    private static let subscriptCharacters: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ",
        "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
        "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "x": "ₓ"
    ]

    private static func scripted(
        _ source: String,
        using characters: [Character: Character]
    ) -> String? {
        var result = ""
        for character in source {
            guard let replacement = characters[character] else { return nil }
            result.append(replacement)
        }
        return result
    }

    private static func replacing(_ pattern: String, in value: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..., in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: template)
    }

    private static func replacing(
        _ pattern: String,
        in value: String,
        transform: (String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
        var result = value
        for match in matches.reversed() {
            guard match.numberOfRanges > 1,
                  let wholeRange = Range(match.range(at: 0), in: result),
                  let captureRange = Range(match.range(at: 1), in: result) else {
                continue
            }
            result.replaceSubrange(wholeRange, with: transform(String(result[captureRange])))
        }
        return result
    }
}
