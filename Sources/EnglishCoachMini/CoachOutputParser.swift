import Foundation

enum CoachOutputParser {
    private static let openingPrefix = ":::writing{variant=\"chat_message\" id=\""
    private static let minimalMarker = "---tone 极简／口语"
    private static let relaxedMarker = "---tone 轻松／口语"
    private static let formalMarker = "---tone 官方／书面"
    private static let appDataStart = CoachProviderContract.appDataStart
    private static let appDataEnd = CoachProviderContract.appDataEnd

    private struct LegacyOutput {
        let minimal: String
        let relaxed: String
        let formal: String
        let notes: String
    }

    private struct AppData: Decodable {
        let mode: CoachInputMode
        let cards: [CoachCard]
        let learningNotes: String
    }

    static func parse(_ raw: String) -> ParsedCoachOutput {
        let legacy = parseLegacy(raw)
        let appData = parseAppData(raw)

        if let appData,
           appData.cards.count == 0 || appData.cards.count == 2 {
            let cards = sanitizeCards(appData.cards, mode: appData.mode, legacy: legacy)
            let appNotes = appData.learningNotes
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = appNotes.isEmpty
                ? (legacy?.notes ?? cleanNotes(raw))
                : appNotes

            return ParsedCoachOutput(
                minimal: legacy?.minimal,
                relaxed: legacy?.relaxed,
                formal: legacy?.formal,
                notes: notes,
                raw: raw,
                mode: appData.mode,
                cards: cards
            )
        }

        if let legacy {
            return ParsedCoachOutput(
                minimal: legacy.minimal,
                relaxed: legacy.relaxed,
                formal: legacy.formal,
                notes: legacy.notes,
                raw: raw
            )
        }

        return ParsedCoachOutput(
            minimal: nil,
            relaxed: nil,
            formal: nil,
            notes: cleanNotes(raw),
            raw: raw
        )
    }

    private static func parseLegacy(_ raw: String) -> LegacyOutput? {
        guard let openingRange = raw.range(of: openingPrefix),
              let openingLineEnd = raw[openingRange.lowerBound...].firstIndex(of: "\n") else {
            return nil
        }

        let contentStart = raw.index(after: openingLineEnd)
        guard let closingRange = raw.range(of: "\n:::", range: contentStart..<raw.endIndex) else {
            return nil
        }

        let blockContent = String(raw[contentStart..<closingRange.lowerBound])
        guard let minimal = extract(
            from: blockContent,
            after: minimalMarker,
            before: relaxedMarker
        ),
        let relaxed = extract(
            from: blockContent,
            after: relaxedMarker,
            before: formalMarker
        ),
        let formal = extract(
            from: blockContent,
            after: formalMarker,
            before: nil
        ) else {
            return nil
        }

        let blockEnd = raw.index(closingRange.lowerBound, offsetBy: 4, limitedBy: raw.endIndex)
            ?? raw.endIndex
        let notes = cleanNotes(
            String(raw[..<openingRange.lowerBound]) + String(raw[blockEnd...])
        )

        return LegacyOutput(
            minimal: minimal,
            relaxed: relaxed,
            formal: formal,
            notes: notes
        )
    }

    private static func parseAppData(_ raw: String) -> AppData? {
        guard let startRange = raw.range(of: appDataStart),
              let endRange = raw.range(
                of: appDataEnd,
                range: startRange.upperBound..<raw.endIndex
              ) else {
            return nil
        }

        var json = String(raw[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if json.hasPrefix("```json") {
            json.removeFirst("```json".count)
        } else if json.hasPrefix("```") {
            json.removeFirst(3)
        }
        if json.hasSuffix("```") {
            json.removeLast(3)
        }
        json = json.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AppData.self, from: data)
    }

    private static func sanitizeCards(
        _ cards: [CoachCard],
        mode: CoachInputMode,
        legacy: LegacyOutput?
    ) -> [CoachCard] {
        cards.prefix(2).enumerated().map { index, card in
            var text = card.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if mode == .express || mode == .improve,
               let legacy {
                if card.id == "concise" {
                    text = legacy.minimal
                } else if card.id == "formal" {
                    text = legacy.formal
                }
            }

            let presentation = sanitizePresentation(card.presentation, for: text)
            let display = cardDisplay(mode: mode, index: index, source: card)
            return CoachCard(
                id: display.id,
                title: display.title,
                subtitle: display.subtitle,
                text: text,
                presentation: presentation
            )
        }
    }

    private static func sanitizePresentation(
        _ presentation: SyntaxPresentation?,
        for text: String
    ) -> SyntaxPresentation? {
        guard let presentation else { return nil }
        let chunks = presentation.chunks.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !chunks.isEmpty else { return nil }

        let reconstructed = chunks.map(\.text).joined(separator: " ")
        guard normalized(reconstructed) == normalized(text) else {
            return SyntaxPresentation(
                chunks: [SyntaxChunk(text: text, style: .core)],
                spine: presentation.spine,
                buildSteps: presentation.buildSteps
            )
        }

        var buildSteps = presentation.buildSteps.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if buildSteps.last.map({ normalized($0) != normalized(text) }) ?? true {
            if buildSteps.count >= 4 {
                buildSteps[buildSteps.count - 1] = text
            } else {
                buildSteps.append(text)
            }
        } else if !buildSteps.isEmpty {
            buildSteps[buildSteps.count - 1] = text
        }

        return SyntaxPresentation(
            chunks: chunks,
            spine: presentation.spine.filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            },
            buildSteps: buildSteps
        )
    }

    private static func cardDisplay(
        mode: CoachInputMode,
        index: Int,
        source: CoachCard
    ) -> (id: String, title: String, subtitle: String) {
        switch mode {
        case .understand:
            return index == 0
                ? ("plain", "简明意思", "Plain-English meaning")
                : ("original", "原句拆分", "Original sentence · structure view")
        case .express, .improve:
            return index == 0
                ? ("concise", "极简／口语", "Shortest natural version")
                : ("formal", "官方／书面", "Email and management communication")
        case .word, .unknown:
            return (source.id, source.title, source.subtitle)
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extract(
        from text: String,
        after startMarker: String,
        before endMarker: String?
    ) -> String? {
        guard let startRange = text.range(of: startMarker) else { return nil }
        let valueStart = startRange.upperBound
        let valueEnd: String.Index

        if let endMarker,
           let endRange = text.range(of: endMarker, range: valueStart..<text.endIndex) {
            valueEnd = endRange.lowerBound
        } else {
            valueEnd = text.endIndex
        }

        let value = text[valueStart..<valueEnd]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func cleanNotes(_ text: String) -> String {
        let withoutAppData: String
        if let startRange = text.range(of: appDataStart),
           let endRange = text.range(
            of: appDataEnd,
            range: startRange.upperBound..<text.endIndex
           ) {
            withoutAppData = String(text[..<startRange.lowerBound])
                + String(text[endRange.upperBound...])
        } else {
            withoutAppData = text
        }

        let filteredLines = withoutAppData
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                let simplified = line
                    .replacingOccurrences(of: "#", with: "")
                    .replacingOccurrences(of: "`", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return simplified != "完整表达" && simplified != "1. 完整表达"
            }

        var result = filteredLines.joined(separator: "\n")
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
