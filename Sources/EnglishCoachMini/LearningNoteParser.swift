import Foundation

enum LearningNoteBlock: Equatable {
    case heading(String)
    case bullet(String)
    case paragraph(String)
}

enum LearningNoteParser {
    static func parse(_ markdown: String) -> [LearningNoteBlock] {
        var blocks: [LearningNoteBlock] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
            paragraphLines.removeAll()
        }

        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                continue
            }

            if line.hasPrefix("#") {
                flushParagraph()
                let title = line
                    .drop(while: { $0 == "#" || $0 == " " })
                    .trimmingCharacters(in: .whitespaces)
                if !title.isEmpty {
                    blocks.append(.heading(title))
                }
                continue
            }

            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                let content = String(line.dropFirst(2))
                    .trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    blocks.append(.bullet(content))
                }
                continue
            }

            let plainLabel = line
                .replacingOccurrences(of: "`", with: "")
                .trimmingCharacters(in: .whitespaces)
            if plainLabel == "重点表达" || plainLabel == "关键词" || plainLabel == "原句分析" {
                flushParagraph()
                blocks.append(.heading(plainLabel))
                continue
            }

            paragraphLines.append(line)
        }

        flushParagraph()
        return blocks
    }
}
