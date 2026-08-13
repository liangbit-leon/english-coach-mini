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
    let spine: [String]
    let buildSteps: [String]
}

struct CoachCard: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let text: String
    let presentation: SyntaxPresentation?
}

struct ParsedCoachOutput: Equatable {
    let minimal: String?
    let relaxed: String?
    let formal: String?
    let mode: CoachInputMode
    let cards: [CoachCard]
    let notes: String
    let raw: String

    init(
        minimal: String?,
        relaxed: String?,
        formal: String?,
        notes: String,
        raw: String,
        mode: CoachInputMode = .unknown,
        cards: [CoachCard]? = nil
    ) {
        self.minimal = minimal
        self.relaxed = relaxed
        self.formal = formal
        self.mode = mode
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
