import SwiftUI

/// 完整 Markdown 渲染视图
/// 支持：标题(#)、加粗(**)、斜体(*)、粗斜体(***)、删除线(~~)、行内代码(`)、
///       代码块(```)、列表(- * •)、有序列表(1.)、任务列表(- [ ] / - [x])、
///       引用块(>)、表格(|)、链接([text](url))、分隔线(---)
struct MarkdownTextView: View {
    let markdown: String
    var baseFontSize: CGFloat = 14
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: - Block Types
    
    enum Block {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case listItem(text: String, indent: Int)
        case taskItem(text: String, checked: Bool, indent: Int)
        case codeBlock(code: String)
        case blockquote(text: String)
        case divider
        case blank
        case table(headers: [String], rows: [[String]])
    }
    
    // MARK: - Parse
    
    func parseBlocks() -> [Block] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [Block] = []
        var inCodeBlock = false
        var codeLines: [String] = []
        var tableLines: [String] = []
        var quoteLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 代码块
            if trimmed.hasPrefix("```") {
                flushTable(&tableLines, &blocks)
                flushQuote(&quoteLines, &blocks)
                if inCodeBlock {
                    blocks.append(.codeBlock(code: codeLines.joined(separator: "\n")))
                    codeLines = []
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }
            if inCodeBlock {
                codeLines.append(line)
                continue
            }
            
            // 表格行
            let isTableLine = trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count > 1
            if isTableLine {
                flushQuote(&quoteLines, &blocks)
                tableLines.append(trimmed)
                continue
            } else if !tableLines.isEmpty {
                flushTable(&tableLines, &blocks)
            }
            
            // 引用块
            if trimmed.hasPrefix("> ") || trimmed == ">" {
                flushTable(&tableLines, &blocks)
                let content = trimmed.hasPrefix("> ") ? String(trimmed.dropFirst(2)) : ""
                quoteLines.append(content)
                continue
            } else if !quoteLines.isEmpty {
                flushQuote(&quoteLines, &blocks)
            }
            
            // 空行
            if trimmed.isEmpty {
                blocks.append(.blank)
                continue
            }
            
            // 分隔线
            if trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == " " }) && trimmed.filter({ $0 == "-" || $0 == "*" }).count >= 3 {
                blocks.append(.divider)
                continue
            }
            
            // 标题
            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let text = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: min(level, 4), text: text))
                continue
            }
            
            // 任务列表 - [ ] 或 - [x]
            if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                let checked = trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]")
                let text = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                let indent = line.prefix(while: { $0 == " " }).count / 2
                blocks.append(.taskItem(text: text, checked: checked, indent: indent))
                continue
            }
            
            // 无序列表
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                let indent = line.prefix(while: { $0 == " " }).count / 2
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.listItem(text: text, indent: indent))
                continue
            }
            
            // 有序列表
            if let dotIdx = trimmed.firstIndex(of: "."),
               trimmed[trimmed.startIndex..<dotIdx].allSatisfy(\.isNumber),
               trimmed.index(after: dotIdx) < trimmed.endIndex,
               trimmed[trimmed.index(after: dotIdx)] == " " {
                let text = String(trimmed[trimmed.index(dotIdx, offsetBy: 2)...]).trimmingCharacters(in: .whitespaces)
                let indent = line.prefix(while: { $0 == " " }).count / 2
                blocks.append(.listItem(text: text, indent: indent))
                continue
            }
            
            // 普通段落
            blocks.append(.paragraph(text: trimmed))
        }
        
        // flush 末尾
        flushTable(&tableLines, &blocks)
        flushQuote(&quoteLines, &blocks)
        
        return blocks
    }
    
    private func flushTable(_ lines: inout [String], _ blocks: inout [Block]) {
        guard !lines.isEmpty else { return }
        blocks.append(parseTable(lines))
        lines = []
    }
    
    private func flushQuote(_ lines: inout [String], _ blocks: inout [Block]) {
        guard !lines.isEmpty else { return }
        let combined = lines.joined(separator: "\n")
        blocks.append(.blockquote(text: combined))
        lines = []
    }
    
    // MARK: - Parse Table
    
    private func parseTable(_ lines: [String]) -> Block {
        let parsedRows = lines.compactMap { line -> [String]? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.allSatisfy({ $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " }) {
                return nil
            }
            let cells = trimmed
                .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            return cells.isEmpty ? nil : cells
        }
        
        guard let headers = parsedRows.first else {
            return .paragraph(text: lines.joined(separator: "\n"))
        }
        let dataRows = Array(parsedRows.dropFirst())
        return .table(headers: headers, rows: dataRows)
    }
    
    // MARK: - Render Blocks
    
    @ViewBuilder
    func blockView(_ block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            let size: CGFloat = [0, baseFontSize + 8, baseFontSize + 5, baseFontSize + 2, baseFontSize][min(level, 4)]
            renderInlineMarkdown(text)
                .font(.system(size: size, weight: .bold))
                .padding(.top, level == 1 ? 8 : 4)
            
        case .paragraph(let text):
            renderInlineMarkdown(text)
                .font(.system(size: baseFontSize))
                .foregroundColor(.secondary)
                .lineSpacing(4)
            
        case .listItem(let text, let indent):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.system(size: baseFontSize, weight: .bold))
                    .foregroundColor(.teal)
                renderInlineMarkdown(text)
                    .font(.system(size: baseFontSize))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            .padding(.leading, CGFloat(indent) * 16)
            
        case .taskItem(let text, let checked, let indent):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: baseFontSize))
                    .foregroundColor(checked ? .teal : .secondary)
                renderInlineMarkdown(text)
                    .font(.system(size: baseFontSize))
                    .foregroundColor(checked ? .secondary : .primary)
                    .strikethrough(checked, color: .secondary)
                    .lineSpacing(3)
            }
            .padding(.leading, CGFloat(indent) * 16)
            
        case .codeBlock(let code):
            Text(code)
                .font(.system(size: baseFontSize - 2, design: .monospaced))
                .foregroundColor(Color(UIColor.label))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            
        case .blockquote(let text):
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.teal.opacity(0.6))
                    .frame(width: 3)
                
                // 递归渲染引用内容
                MarkdownTextView(markdown: text, baseFontSize: baseFontSize - 1)
                    .padding(.leading, 10)
                    .padding(.vertical, 4)
            }
            .padding(.vertical, 2)
            .padding(.trailing, 4)
            .background(Color.teal.opacity(0.05))
            .cornerRadius(6)
            
        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)
            
        case .divider:
            Divider().padding(.vertical, 4)
            
        case .blank:
            Spacer().frame(height: 2)
        }
    }
    
    // MARK: - Table View
    
    @ViewBuilder
    func tableView(headers: [String], rows: [[String]]) -> some View {
        let colCount = headers.count
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { idx, header in
                    renderInlineMarkdown(header)
                        .font(.system(size: baseFontSize - 1, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity,
                               alignment: idx == 0 ? .leading : .trailing)
                }
            }
            .background(Color(UIColor.systemGray5))
            
            // Rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(0..<colCount, id: \.self) { colIdx in
                        let cell = colIdx < row.count ? row[colIdx] : ""
                        renderInlineMarkdown(cell)
                            .font(.system(size: baseFontSize - 1))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity,
                                   alignment: colIdx == 0 ? .leading : .trailing)
                    }
                }
                .background(rowIdx % 2 == 0 ? Color.clear : Color(UIColor.systemGray6).opacity(0.5))
            }
        }
        .clipped()
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(UIColor.systemGray4), lineWidth: 0.5)
        )
    }
    
    // MARK: - Inline Markdown (bold, italic, bold+italic, strikethrough, code, links)
    
    func renderInlineMarkdown(_ text: String) -> Text {
        var result = Text("")
        var remaining = text[text.startIndex...]
        
        while !remaining.isEmpty {
            // 粗斜体 ***...***
            if remaining.hasPrefix("***") {
                let after = remaining.index(remaining.startIndex, offsetBy: 3)
                if let end = remaining[after...].range(of: "***") {
                    let content = String(remaining[after..<end.lowerBound])
                    result = result + Text(content).bold().italic()
                    remaining = remaining[end.upperBound...]
                    continue
                }
            }
            
            // 加粗 **...**
            if remaining.hasPrefix("**") {
                let after = remaining.index(remaining.startIndex, offsetBy: 2)
                if let end = remaining[after...].range(of: "**") {
                    let bold = String(remaining[after..<end.lowerBound])
                    result = result + Text(bold).bold()
                    remaining = remaining[end.upperBound...]
                    continue
                }
            }
            
            // 删除线 ~~...~~
            if remaining.hasPrefix("~~") {
                let after = remaining.index(remaining.startIndex, offsetBy: 2)
                if let end = remaining[after...].range(of: "~~") {
                    let struck = String(remaining[after..<end.lowerBound])
                    result = result + Text(struck).strikethrough()
                    remaining = remaining[end.upperBound...]
                    continue
                }
            }
            
            // 行内代码 `...`
            if remaining.hasPrefix("`") {
                let after = remaining.index(after: remaining.startIndex)
                if let end = remaining[after...].firstIndex(of: "`") {
                    let code = String(remaining[after..<end])
                    result = result + Text(code).font(.system(size: baseFontSize - 1, design: .monospaced)).foregroundColor(.teal)
                    remaining = remaining[remaining.index(after: end)...]
                    continue
                }
            }
            
            // 链接 [text](url)
            if remaining.hasPrefix("[") {
                let afterBracket = remaining.index(after: remaining.startIndex)
                if let closeBracket = remaining[afterBracket...].firstIndex(of: "]") {
                    let linkText = String(remaining[afterBracket..<closeBracket])
                    let afterClose = remaining.index(after: closeBracket)
                    if afterClose < remaining.endIndex && remaining[afterClose] == "(" {
                        let afterParen = remaining.index(after: afterClose)
                        if let closeParen = remaining[afterParen...].firstIndex(of: ")") {
                            // 显示链接文字（蓝色带下划线）
                            result = result + Text(linkText).foregroundColor(.blue).underline()
                            remaining = remaining[remaining.index(after: closeParen)...]
                            continue
                        }
                    }
                }
            }
            
            // 斜体 *...*
            if remaining.hasPrefix("*") && !remaining.hasPrefix("**") {
                let after = remaining.index(after: remaining.startIndex)
                if let end = remaining[after...].firstIndex(of: "*") {
                    let italic = String(remaining[after..<end])
                    result = result + Text(italic).italic()
                    remaining = remaining[remaining.index(after: end)...]
                    continue
                }
            }
            
            // 普通文本到下一个特殊字符
            var nextSpecial = remaining.endIndex
            for marker in ["***", "**", "~~", "`", "[", "*"] {
                if let r = remaining.dropFirst().range(of: marker) {
                    if r.lowerBound < nextSpecial {
                        nextSpecial = r.lowerBound
                    }
                }
            }
            
            let plain = String(remaining[remaining.startIndex..<nextSpecial])
            result = result + Text(plain)
            remaining = remaining[nextSpecial...]
        }
        
        return result
    }
}
