import AppKit
import Foundation

enum CoachStatus: Equatable {
    case idle
    case running
    case finished
    case failed(String)
}

enum CoachResultTab: String, CaseIterable, Identifiable {
    case expressions = "完整表达"
    case notes = "Learning Notes"

    var id: String { rawValue }
}

enum CoachInputMode: String, Codable, Equatable {
    case express
    case improve
    case understand
    case word
    case unknown

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .unknown
    }
}

enum SyntaxChunkStyle: String, Codable, Equatable {
    case core
    case predicate
    case modifier
    case protected

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .core
    }
}

struct SyntaxChunk: Codable, Equatable {
    let text: String
    let style: SyntaxChunkStyle
}

struct SyntaxPresentation: Codable, Equatable {
    let chunks: [SyntaxChunk]
}

struct CoachCard: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let text: String
    let presentation: SyntaxPresentation?
}

struct WordStudyExample: Codable, Equatable {
    let english: String
    let chinese: String?
}

struct WordStudy: Codable, Equatable {
    let entry: String
    let phoneticUS: String?
    let category: String?
    let phraseParts: [String]?
    let partOfSpeech: [String]?
    let meanings: [String]?
    let wordForms: [String]?
    let tensePatterns: [String]?
    let collocations: [String]?
    let examples: [WordStudyExample]?
    let usageNotes: [String]?

    private enum CodingKeys: String, CodingKey {
        case entry
        case phoneticUS
        case category
        case phraseParts
        case partOfSpeech
        case meanings
        case wordForms
        case tensePatterns
        case collocations
        case examples
        case usageNotes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entry = try container.decodeIfPresent(String.self, forKey: .entry) ?? ""
        phoneticUS = try container.decodeIfPresent(String.self, forKey: .phoneticUS)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        phraseParts = try container.decodeIfPresent([String].self, forKey: .phraseParts)
        partOfSpeech = try container.decodeIfPresent([String].self, forKey: .partOfSpeech)
        meanings = try container.decodeIfPresent([String].self, forKey: .meanings)
        wordForms = try container.decodeIfPresent([String].self, forKey: .wordForms)
        tensePatterns = try container.decodeIfPresent([String].self, forKey: .tensePatterns)
        collocations = try container.decodeIfPresent([String].self, forKey: .collocations)
        examples = try container.decodeIfPresent([WordStudyExample].self, forKey: .examples)
        usageNotes = try container.decodeIfPresent([String].self, forKey: .usageNotes)
    }
}

struct ParsedCoachOutput: Equatable {
    let minimal: String?
    let relaxed: String?
    let formal: String?
    let optimizedChinese: String?
    let mode: CoachInputMode
    let cards: [CoachCard]
    let wordStudy: WordStudy?
    let notes: String
    let raw: String

    init(
        minimal: String?,
        relaxed: String?,
        formal: String?,
        notes: String,
        raw: String,
        mode: CoachInputMode = .unknown,
        cards: [CoachCard]? = nil,
        wordStudy: WordStudy? = nil,
        optimizedChinese: String? = nil
    ) {
        self.minimal = minimal
        self.relaxed = relaxed
        self.formal = formal
        self.optimizedChinese = optimizedChinese
        self.mode = mode
        self.wordStudy = wordStudy
        self.notes = notes
        self.raw = raw

        if let cards {
            self.cards = cards
        } else {
            var fallbackCards: [CoachCard] = []
            if let minimal {
                fallbackCards.append(
                    CoachCard(
                        id: "concise",
                        title: "极简／口语",
                        subtitle: "Shortest natural version",
                        text: minimal,
                        presentation: nil
                    )
                )
            }
            if let formal {
                fallbackCards.append(
                    CoachCard(
                        id: "formal",
                        title: "官方／书面",
                        subtitle: "Email and management communication",
                        text: formal,
                        presentation: nil
                    )
                )
            }
            self.cards = fallbackCards
        }
    }

    var hasToneCards: Bool {
        cards.count == 2
    }
}

@MainActor
final class CoachStore: ObservableObject {
    @Published var input = ""
    @Published var status: CoachStatus = .idle
    @Published var output: ParsedCoachOutput?
    @Published var focusRequest = UUID()
    @Published var selectedResultTab: CoachResultTab = .expressions

    private let runner: CoachProviding = CoachProviderFactory.make()
    private var requestID = UUID()

    var providerLabel: String {
        runner.displayName
    }

    func requestInputFocus() {
        focusRequest = UUID()
    }

    func analyze() {
        let expression = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expression.isEmpty, status != .running else { return }

        let currentRequestID = UUID()
        requestID = currentRequestID
        status = .running
        output = nil
        selectedResultTab = .expressions

        runner.run(expression: expression) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.requestID == currentRequestID else { return }
                switch result {
                case .success(let rawOutput):
                    self.output = CoachOutputParser.parse(rawOutput)
                    if self.output?.hasToneCards != true {
                        self.selectedResultTab = .notes
                    }
                    self.status = .finished
                case .failure(let error):
                    self.status = .failed(error.localizedDescription)
                }
            }
        }
    }

    func clear() {
        requestID = UUID()
        runner.cancel()
        input = ""
        output = nil
        status = .idle
        selectedResultTab = .expressions
        requestInputFocus()
    }
}
