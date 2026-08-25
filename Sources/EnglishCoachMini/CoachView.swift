import AppKit
import SwiftUI

struct CoachView: View {
    @ObservedObject var store: CoachStore
    let onClose: () -> Void

    @FocusState private var inputIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            inputArea
            Divider()
            outputArea
            footer
        }
        .frame(minWidth: 620, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                inputIsFocused = true
            }
        }
        .onChange(of: store.focusRequest) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                inputIsFocused = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("English Coach")
                    .font(.headline)
                Text("Natural expressions for real conversations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(store.providerLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())

            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close")
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 13)
    }

    private var inputArea: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.secondary.opacity(0.16))
                    }

                if store.input.isEmpty {
                    Text("Type or paste a Chinese or English expression…")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $store.input)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .padding(7)
                    .focused($inputIsFocused)
                    .disabled(store.status == .running)
            }
            .frame(minHeight: 94, maxHeight: 132)

            ZStack {
                HStack {
                    if store.output != nil || store.status != .idle {
                        Button("Clear") {
                            store.clear()
                        }
                        .disabled(store.status == .running)
                    }

                    Spacer()

                    if store.status == .running {
                        ProgressView()
                            .controlSize(.small)
                        Text("Coaching…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        store.analyze()
                    } label: {
                        Label("Coach", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        store.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || store.status == .running
                    )
                }

                if store.status == .finished,
                   let output = store.output,
                   output.hasToneCards,
                   !output.notes.isEmpty {
                    Picker("Result view", selection: $store.selectedResultTab) {
                        ForEach(CoachResultTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 270)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var outputArea: some View {
        switch store.status {
        case .idle:
            ContentUnavailableView {
                Label("Ready to coach", systemImage: "quote.bubble")
            } description: {
                Text("Press Control–Option–E, enter an expression, then press Command–Return.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .running:
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Finding the most natural expression…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn’t finish", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
                    .textSelection(.enabled)
            } actions: {
                Button("Try Again") {
                    store.analyze()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .finished:
            if let output = store.output {
                resultView(output)
            } else {
                EmptyView()
            }
        }
    }

    private func resultView(_ output: ParsedCoachOutput) -> some View {
        Group {
            if output.mode == .word, let wordStudy = output.wordStudy {
                wordStudyView(wordStudy, fallbackNotes: output.notes)
            } else if !output.hasToneCards || store.selectedResultTab == .notes {
                learningNotesView(output.notes)
            } else {
                expressionCardsView(output)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func expressionCardsView(_ output: ParsedCoachOutput) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if output.hasToneCards {
                    if let optimizedChinese = output.optimizedChinese {
                        ToneCard(
                            title: "优化后的中文",
                            subtitle: "保留关键信息与原有语气",
                            text: optimizedChinese,
                            presentation: nil,
                            tint: .blue
                        )
                    }

                    ForEach(Array(output.cards.enumerated()), id: \.element.id) { index, card in
                        ToneCard(
                            title: card.title,
                            subtitle: card.subtitle,
                            text: card.text,
                            presentation: card.presentation,
                            tint: index == 0 ? .green : .purple
                        )
                    }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func learningNotesView(_ notes: String) -> some View {
        ScrollView {
            LearningNotesView(notes: notes)
                .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func wordStudyView(_ study: WordStudy, fallbackNotes: String) -> some View {
        ScrollView {
            WordStudyView(study: study, fallbackNotes: fallbackNotes)
                .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("⌃⌥E open")
            Text("·")
            Text("⌘↩ coach")
            Spacer()
            Text("Configurable model provider")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct ToneCard: View {
    let title: String
    let subtitle: String
    let text: String
    let presentation: SyntaxPresentation?
    let tint: Color

    init(
        title: String,
        subtitle: String,
        text: String,
        presentation: SyntaxPresentation?,
        tint: Color
    ) {
        self.title = title
        self.subtitle = subtitle
        self.text = text
        self.presentation = presentation
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    CopyButton(text: text, label: "Copy")
                }

                if let presentation {
                    PhraseChunkLayout(chunks: presentation.chunks)
                } else {
                    Text(text)
                        .font(.system(size: 15))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)

        }
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.2))
        }
    }
}

private struct PhraseChunkLayout: View {
    let chunks: [SyntaxChunk]

    var body: some View {
        FlowLayout(spacing: 7) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                chunkText(chunk)
                    .padding(.vertical, 3)

                if index < chunks.count - 1 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 1, height: 15)
                        .layoutValue(key: PhraseSeparatorLayoutKey.self, value: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chunks.map(\.text).joined(separator: " "))
    }

    @ViewBuilder
    private func chunkText(_ chunk: SyntaxChunk) -> some View {
        switch chunk.style {
        case .core:
            Text(chunk.text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)
        case .predicate:
            Text(chunk.text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)
                .underline(true, color: Color.secondary.opacity(0.55))
        case .modifier:
            Text(chunk.text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .italic()
        case .protected:
            Text(chunk.text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)
                .underline(true, color: Color.accentColor.opacity(0.55))
        }
    }
}

private struct PhraseSeparatorLayoutKey: LayoutValueKey {
    static let defaultValue = false
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    private struct Item {
        let index: Int
        let size: CGSize
    }

    private struct Rows {
        let values: [[Item]]
        let hiddenSeparators: Set<Int>
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = makeRows(maxWidth: width, subviews: subviews).values
        let widestRow = rows.map(rowWidth).max() ?? 0
        let totalHeight = rows.enumerated().reduce(CGFloat.zero) { total, entry in
            total + rowHeight(entry.element) + (entry.offset == 0 ? 0 : spacing)
        }
        return CGSize(width: min(widestRow, width), height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = makeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows.values {
            var x = bounds.minX
            let height = rowHeight(row)

            for item in row {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (height - item.size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }

            y += height + spacing
        }

        for index in rows.hiddenSeparators {
            subviews[index].place(
                at: CGPoint(x: bounds.minX - 10_000, y: bounds.minY),
                anchor: .topLeading,
                proposal: .zero
            )
        }
    }

    private func makeRows(maxWidth: CGFloat, subviews: Subviews) -> Rows {
        var rows: [[Item]] = []
        var currentRow: [Item] = []
        var currentWidth: CGFloat = 0
        var hiddenSeparators: Set<Int> = []
        var index = 0

        while index < subviews.count {
            let subview = subviews[index]
            let isSeparator = subview[PhraseSeparatorLayoutKey.self]
            let size = isSeparator
                ? subview.sizeThatFits(.unspecified)
                : subview.sizeThatFits(
                    ProposedViewSize(width: maxWidth, height: nil)
                )

            if isSeparator {
                guard !currentRow.isEmpty, index + 1 < subviews.count else {
                    hiddenSeparators.insert(index)
                    index += 1
                    continue
                }

                let nextSize = subviews[index + 1].sizeThatFits(
                    ProposedViewSize(width: maxWidth, height: nil)
                )
                let combinedWidth = currentWidth + spacing + size.width + spacing + nextSize.width
                if combinedWidth > maxWidth {
                    rows.append(currentRow)
                    currentRow = []
                    currentWidth = 0
                    hiddenSeparators.insert(index)
                    index += 1
                    continue
                }
            } else if !currentRow.isEmpty,
                      currentWidth + spacing + size.width > maxWidth {
                rows.append(currentRow)
                currentRow = []
                currentWidth = 0
            }

            currentRow.append(Item(index: index, size: size))
            currentWidth += (currentRow.count == 1 ? 0 : spacing) + size.width
            index += 1
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return Rows(values: rows, hiddenSeparators: hiddenSeparators)
    }

    private func rowWidth(_ row: [Item]) -> CGFloat {
        row.enumerated().reduce(CGFloat.zero) { total, entry in
            total + entry.element.size.width + (entry.offset == 0 ? 0 : spacing)
        }
    }

    private func rowHeight(_ row: [Item]) -> CGFloat {
        row.map(\.size.height).max() ?? 0
    }
}

private struct CopyButton: View {
    let text: String
    let label: String
    @State private var copied = false

    var body: some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                copied = false
            }
        } label: {
            Label(copied ? "Copied" : label, systemImage: copied ? "checkmark" : "doc.on.doc")
        }
        .controlSize(.small)
    }
}

private struct LearningNotesView: View {
    let notes: String

    private var blocks: [LearningNoteBlock] {
        LearningNoteParser.parse(notes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Learning Notes", systemImage: "lightbulb.max.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Divider()
                .padding(.top, 12)
                .padding(.bottom, 4)

            ForEach(blocks.indices, id: \.self) { index in
                noteBlock(blocks[index], at: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.quaternary.opacity(0.48), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
    }

    @ViewBuilder
    private func noteBlock(_ block: LearningNoteBlock, at index: Int) -> some View {
        switch block {
        case .heading(let title):
            Text(title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, index == 0 ? 10 : 18)
                .padding(.bottom, 7)

        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle()
                    .fill(Color.accentColor.opacity(0.8))
                    .frame(width: 5, height: 5)

                InlineMarkdownText(text)
            }
            .padding(.vertical, 4)

        case .paragraph(let text):
            InlineMarkdownText(text)
                .padding(.vertical, 5)
        }
    }
}

private struct WordStudyView: View {
    let study: WordStudy
    let fallbackNotes: String

    private var categoryLabel: String {
        study.category?.lowercased() == "phrase" ? "短语" : "词汇"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(study.entry)
                    .font(.system(size: 25, weight: .semibold))
                    .textSelection(.enabled)

                Text(categoryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())

                Spacer()
            }

            if let phoneticUS = study.phoneticUS,
               !phoneticUS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 7) {
                    Text("美式音标")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(phoneticUS)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                .padding(.top, 7)
            }

            if let phraseParts = study.phraseParts, !phraseParts.isEmpty {
                WordStudySection(title: "短语拆分", systemImage: "text.word.spacing") {
                    FlowLayout(spacing: 7) {
                        ForEach(Array(phraseParts.enumerated()), id: \.offset) { index, part in
                            Text(part)
                                .font(.system(size: 14.5))
                                .foregroundStyle(.primary)
                                .padding(.vertical, 3)

                            if index < phraseParts.count - 1 {
                                Text("·")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            wordStudyListSection(
                title: "词性",
                systemImage: "character.textbox",
                items: study.partOfSpeech
            )
            wordStudyListSection(
                title: "核心意思",
                systemImage: "lightbulb",
                items: study.meanings
            )
            wordStudyListSection(
                title: "词形变化",
                systemImage: "arrow.triangle.branch",
                items: study.wordForms
            )
            wordStudyListSection(
                title: "时态与句型",
                systemImage: "clock.arrow.circlepath",
                items: study.tensePatterns
            )
            wordStudyListSection(
                title: "常见搭配",
                systemImage: "link",
                items: study.collocations
            )

            if let examples = study.examples, !examples.isEmpty {
                WordStudySection(title: "例句", systemImage: "quote.bubble") {
                    VStack(alignment: .leading, spacing: 11) {
                        ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("\(index + 1)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 14, alignment: .trailing)
                                    Text(example.english)
                                        .font(.system(size: 14.5))
                                        .textSelection(.enabled)
                                }

                                if let chinese = example.chinese,
                                   !chinese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(chinese)
                                        .font(.system(size: 13.5))
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 22)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
            }

            wordStudyListSection(
                title: "使用提醒",
                systemImage: "exclamationmark.circle",
                items: study.usageNotes
            )

            if !fallbackNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                WordStudySection(title: "补充说明", systemImage: "note.text") {
                    InlineMarkdownText(fallbackNotes)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.quaternary.opacity(0.48), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
    }

    @ViewBuilder
    private func wordStudyListSection(
        title: String,
        systemImage: String,
        items: [String]?
    ) -> some View {
        if let items, !items.isEmpty {
            WordStudySection(title: title, systemImage: systemImage) {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Circle()
                                .fill(Color.accentColor.opacity(0.75))
                                .frame(width: 4, height: 4)
                            InlineMarkdownText(item)
                        }
                    }
                }
            }
        }
    }
}

private struct WordStudySection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.9))

            content()
        }
        .padding(.top, 18)
    }
}

private struct InlineMarkdownText: View {
    private let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Group {
            if let attributed = try? AttributedString(
                markdown: value,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                Text(attributed)
            } else {
                Text(value)
            }
        }
        .font(.system(size: 13.5))
        .lineSpacing(3)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
