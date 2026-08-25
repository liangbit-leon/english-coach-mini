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
          "optimizedChinese": "",
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
                ]
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
                ]
              }
            }
          ],
          "learningNotes": "## 语法拆分\\n- 语法需要修改。\\n\\n## 关键词\\n- `get back to someone`"
        }
        <<<END_ENGLISH_COACH_APP_DATA>>>
        """

        let parsedStructured = CoachOutputParser.parse(structuredSample)
        let structuredChecks = [
            parsedStructured.mode == .improve,
            parsedStructured.cards.count == 2,
            parsedStructured.cards[0].presentation?.chunks[1].style == .predicate,
            parsedStructured.cards[0].presentation?.chunks.count == 3,
            parsedStructured.optimizedChinese == nil,
            parsedStructured.notes.contains("语法拆分"),
            parsedStructured.notes.contains("关键词"),
            !parsedStructured.notes.contains("ENGLISH_COACH_APP_DATA")
        ]

        let expressSample = """
        <<<ENGLISH_COACH_APP_DATA>>>
        {
          "mode": "express",
          "optimizedChinese": "如果预算明天仍未获批，请先准备材料，不要承诺启动日期。",
          "cards": [
            {
              "id": "concise",
              "title": "ignored",
              "subtitle": "ignored",
              "text": "If the budget still isn't approved tomorrow, please prepare the materials but don't commit to a start date.",
              "presentation": {
                "chunks": [
                  {"text": "If the budget still isn't approved tomorrow,", "style": "protected"},
                  {"text": "please prepare the materials", "style": "predicate"},
                  {"text": "but don't commit to a start date.", "style": "protected"}
                ]
              }
            },
            {
              "id": "formal",
              "title": "ignored",
              "subtitle": "ignored",
              "text": "If the budget remains unapproved tomorrow, please prepare the materials but do not commit to a commencement date.",
              "presentation": {
                "chunks": [
                  {"text": "If the budget remains unapproved tomorrow,", "style": "protected"},
                  {"text": "please prepare the materials", "style": "predicate"},
                  {"text": "but do not commit to a commencement date.", "style": "protected"}
                ]
              }
            }
          ],
          "learningNotes": "## 语法拆分\\n- 条件从句 + 主句。\\n\\n## 关键词\\n- `commit to` 表示作出承诺。"
        }
        <<<END_ENGLISH_COACH_APP_DATA>>>
        """
        let parsedExpress = CoachOutputParser.parse(expressSample)
        let expressChecks = [
            parsedExpress.mode == .express,
            parsedExpress.optimizedChinese == "如果预算明天仍未获批，请先准备材料，不要承诺启动日期。",
            parsedExpress.cards.count == 2,
            parsedExpress.cards[0].title == "极简／口语",
            parsedExpress.cards[1].title == "官方／书面",
            parsedExpress.notes.contains("语法拆分"),
            parsedExpress.notes.contains("关键词")
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
                "chunks": [{"text": "The board needs verification before approval.", "style": "core"}]
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
                ]
              }
            }
          ],
          "learningNotes": "## 语法拆分\\n- 批准以核验为前提。\\n\\n## 关键词\\n- `until` 引导时间条件。"
        }
        <<<END_ENGLISH_COACH_APP_DATA>>>
        """
        let parsedUnderstand = CoachOutputParser.parse(understandSample)
        let understandChecks = [
            parsedUnderstand.cards[0].title == "简明意思",
            parsedUnderstand.cards[1].title == "原句拆分",
            parsedUnderstand.cards[1].presentation?.chunks.count == 4
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

        let structuredWordSample = """
        <<<ENGLISH_COACH_APP_DATA>>>
        {
          "mode": "word",
          "cards": [],
          "wordStudy": {
            "entry": "errant",
            "phoneticUS": "/əˈrɛnt/",
            "category": "word",
            "phraseParts": [],
            "partOfSpeech": ["adjective — 偏离规范的"],
            "meanings": ["偏离正常、规范或预期的"],
            "wordForms": ["err — 犯错", "error — 错误"],
            "tensePatterns": [],
            "collocations": ["errant behavior — 失当行为"],
            "examples": [
              {"english": "The system detected an errant data entry.", "chinese": "系统发现了一项错误的数据录入。"}
            ],
            "usageNotes": ["比 wrong 更正式。"]
          },
          "learningNotes": "## 补充说明\\n- 这里是补充提示。"
        }
        <<<END_MARKER>>>
        """
        let parsedStructuredWord = CoachOutputParser.parse(structuredWordSample)
        let structuredWordChecks = [
            parsedStructuredWord.mode == .word,
            parsedStructuredWord.wordStudy?.entry == "errant",
            parsedStructuredWord.wordStudy?.phoneticUS == "/əˈrɛnt/",
            parsedStructuredWord.wordStudy?.tensePatterns?.isEmpty == true,
            parsedStructuredWord.wordStudy?.examples?.count == 1,
            parsedStructuredWord.notes.contains("补充提示"),
            !parsedStructuredWord.notes.contains("ENGLISH_COACH_APP_DATA"),
            !parsedStructuredWord.notes.contains("END_MARKER")
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

        let missingConfigurationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("english-coach-missing-\(UUID().uuidString).json")
        let defaultProvider = CoachProviderFactory.make(
            environment: [:],
            configurationURL: missingConfigurationURL
        )

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
            providerPrompt.contains("## 语法拆分"),
            providerPrompt.contains("## 关键词"),
            providerPrompt.contains("first produce optimizedChinese"),
            providerPrompt.contains("interpersonal tone"),
            providerPrompt.contains("\"optimizedChinese\""),
            providerPrompt.contains("Do not include logic"),
            providerPrompt.contains("Concision may reduce words, never facts."),
            !providerPrompt.localizedCaseInsensitiveContains("logic spine"),
            !providerPrompt.localizedCaseInsensitiveContains("build steps"),
            !providerPrompt.contains("\"sentences\""),
            decodedRequest == providerRequest,
            configuredProvider.displayName == "Test Provider",
            defaultProvider.displayName == "Sol · Low",
            adapterFinished,
            echoedRequest?.expression == "Adapter test.",
            echoedRequest?.promptVersion == CoachProviderContract.promptVersion
        ]

        let windowChecks = [
            CoachWindowPolicy.collectionBehavior.contains(.managed),
            !CoachWindowPolicy.collectionBehavior.contains(.canJoinAllSpaces),
            !CoachWindowPolicy.collectionBehavior.contains(.moveToActiveSpace),
            !CoachWindowPolicy.frameAutosaveName.isEmpty
        ]

        let passed = (
            sentenceChecks + structuredChecks + expressChecks + understandChecks + wordChecks
                + structuredWordChecks + noteChecks
                + providerChecks + windowChecks
        )
            .allSatisfy { $0 }
        print(passed ? "SELF_TEST_PASS" : "SELF_TEST_FAIL")
        return passed
    }
}
