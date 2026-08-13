import Foundation

enum CoachSelfTest {
    static func run() -> Bool {
        let sentenceSample = """
        ### 完整表达

        :::writing{variant="chat_message" id="12345"}
        ---tone 极简／口语
        I’ll get back to you later.

        ---tone 轻松／口语
        I’ll take a look and get back to you later.

        ---tone 官方／书面
        I will review this and respond later today.
        :::

        ### 重点表达

        - 稍后回复：`get back to someone`
        """

        let parsedSentence = CoachOutputParser.parse(sentenceSample)
        let sentenceChecks = [
            parsedSentence.minimal == "I’ll get back to you later.",
            parsedSentence.relaxed == "I’ll take a look and get back to you later.",
            parsedSentence.formal == "I will review this and respond later today.",
            parsedSentence.cards.count == 2,
            parsedSentence.cards.first?.text == "I’ll get back to you later.",
            parsedSentence.notes.contains("重点表达"),
            !parsedSentence.notes.contains("完整表达")
        ]

        let structuredSample = sentenceSample + """

        <<<ENGLISH_COACH_APP_DATA>>>
        {
          "mode": "improve",
          "cards": [
            {
              "id": "concise",
              "title": "极简／口语",
              "subtitle": "Shortest natural version",
              "text": "I’ll get back to you later.",
              "presentation": {
                "chunks": [
                  {"text": "I’ll", "style": "core"},
                  {"text": "get back", "style": "predicate"},
                  {"text": "to you later.", "style": "modifier"}
                ],
                "spine": ["I", "get back", "to you"],
                "buildSteps": ["I’ll get back to you.", "I’ll get back to you later."]
              }
            },
            {
              "id": "formal",
              "title": "官方／书面",
              "subtitle": "Email and management communication",
              "text": "I will review this and respond later today.",
              "presentation": {
                "chunks": [
                  {"text": "I", "style": "core"},
                  {"text": "will review", "style": "predicate"},
                  {"text": "this and respond later today.", "style": "core"}
                ],
                "spine": ["I", "review", "respond"],
                "buildSteps": ["I will respond.", "I will review this and respond later today."]
              }
            }
          ],
          "learningNotes": "## 原句判断\\n- 语法需要修改。\\n\\n## 可复用结构\\n- `get back to someone`"
        }
        <<<END_ENGLISH_COACH_APP_DATA>>>
        """

        let parsedStructured = CoachOutputParser.parse(structuredSample)
        let structuredChecks = [
            parsedStructured.mode == .improve,
            parsedStructured.cards.count == 2,
            parsedStructured.cards[0].presentation?.chunks[1].style == .predicate,
            parsedStructured.cards[0].presentation?.buildSteps.count == 2,
            parsedStructured.notes.contains("原句判断"),
            !parsedStructured.notes.contains("ENGLISH_COACH_APP_DATA")
        ]

        let understandSample = """
        <<<ENGLISH_COACH_APP_DATA>>>
        {
          "mode": "understand",
          "cards": [
            {
              "id": "plain",
              "title": "ignored",
              "subtitle": "ignored",
              "text": "The board needs verification before approval.",
              "presentation": {
                "chunks": [{"text": "The board needs verification before approval.", "style": "core"}],
                "spine": ["board", "needs verification", "before approval"],
                "buildSteps": ["The board needs verification."]
              }
            },
            {
              "id": "original",
              "title": "ignored",
              "subtitle": "ignored",
              "text": "Although it looked workable, the board could not approve it until the assumptions had been verified.",
              "presentation": {
                "chunks": [
                  {"text": "Although it looked workable,", "style": "modifier"},
                  {"text": "the board", "style": "core"},
                  {"text": "could not approve", "style": "protected"},
                  {"text": "it until the assumptions had been verified.", "style": "protected"}
                ],
                "spine": ["board", "could not approve", "until verified"],
                "buildSteps": ["The board could not approve it."]
              }
            }
          ],
          "learningNotes": "## 句子意思\\n- 批准以核验为前提。"
        }
        <<<END_ENGLISH_COACH_APP_DATA>>>
        """
        let parsedUnderstand = CoachOutputParser.parse(understandSample)
        let understandChecks = [
            parsedUnderstand.cards[0].title == "简明意思",
            parsedUnderstand.cards[1].title == "原句拆分",
            parsedUnderstand.cards[1].presentation?.buildSteps.last
                == parsedUnderstand.cards[1].text
        ]

        let wordSample = """
        ## beef up

        表示加强或充实，偏口语。
        """
        let parsedWord = CoachOutputParser.parse(wordSample)
        let wordChecks = [
            !parsedWord.hasToneCards,
            parsedWord.notes == wordSample
        ]

        let learningNotes = """
        ### 重点表达

        - 表示稍后回复：`get back to you later`
        - 表示尽快回复：`get back to you shortly`

        ### 关键词

        - `respond`：偏正式
        """
        let noteBlocks = LearningNoteParser.parse(learningNotes)
        let noteChecks = [
            noteBlocks.first == .heading("重点表达"),
            noteBlocks.contains(.bullet("表示稍后回复：`get back to you later`")),
            noteBlocks.contains(.heading("关键词")),
            noteBlocks.last == .bullet("`respond`：偏正式")
        ]

        let providerPrompt = ExternalProviderPrompt.make(expression: "Keep this exact.")
        let providerRequest = ExternalCoachRequest(
            schemaVersion: CoachProviderContract.schemaVersion,
            promptVersion: CoachProviderContract.promptVersion,
            expression: "Keep this exact.",
            prompt: providerPrompt,
            model: "test-model"
        )
        let encodedRequest = try? JSONEncoder().encode(providerRequest)
        let decodedRequest = encodedRequest.flatMap {
            try? JSONDecoder().decode(ExternalCoachRequest.self, from: $0)
        }

        let configurationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("english-coach-provider-test-\(UUID().uuidString).json")
        let configuration = CoachProviderConfiguration(
            provider: "command",
            name: "Test Provider",
            command: "/tmp/not-used-by-this-test",
            model: "test-model",
            reasoningEffort: nil,
            codexPath: nil
        )
        if let configurationData = try? JSONEncoder().encode(configuration) {
            try? configurationData.write(to: configurationURL, options: .atomic)
        }
        let configuredProvider = CoachProviderFactory.make(
            environment: [:],
            configurationURL: configurationURL
        )
        try? FileManager.default.removeItem(at: configurationURL)

        let adapterSemaphore = DispatchSemaphore(value: 0)
        var echoedRequest: ExternalCoachRequest?
        let adapterProvider = ExternalCommandCoachProvider(
            commandPath: "/bin/cat",
            model: "test-model"
        )
        adapterProvider.run(expression: "Adapter test.") { result in
            if case .success(let raw) = result,
               let data = raw.data(using: .utf8) {
                echoedRequest = try? JSONDecoder().decode(
                    ExternalCoachRequest.self,
                    from: data
                )
            }
            adapterSemaphore.signal()
        }
        let adapterFinished = adapterSemaphore.wait(timeout: .now() + 3) == .success

        let providerChecks = [
            providerPrompt.contains("Keep this exact."),
            providerPrompt.contains(CoachProviderContract.appDataStart),
            providerPrompt.contains(CoachProviderContract.appDataEnd),
            decodedRequest == providerRequest,
            configuredProvider.displayName == "Test Provider",
            adapterFinished,
            echoedRequest?.expression == "Adapter test.",
            echoedRequest?.promptVersion == CoachProviderContract.promptVersion
        ]

        let passed = (
            sentenceChecks + structuredChecks + understandChecks + wordChecks + noteChecks
                + providerChecks
        )
            .allSatisfy { $0 }
        print(passed ? "SELF_TEST_PASS" : "SELF_TEST_FAIL")
        return passed
    }
}
