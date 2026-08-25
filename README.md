# English Coach Mini

A small macOS menu-bar utility for translating, improving, and understanding
English without opening a chat window. The UI is separated from the model layer
so the same learning experience can run on Codex or another model provider.

## Use

1. Press `Control + Option + E`.
2. Type or paste a Chinese or English expression.
3. Press `Return` for a new line, or `Command + Return` to run Coach.
4. For Chinese input, review the optimized Chinese wording first.
5. Review the concise spoken and formal written English versions.
6. Read the phrase-level structure directly in each English expression card.
7. Switch to Learning Notes for sentence-level grammar and keyword analysis.
8. Copy any clean, ready-to-send version.

The app automatically adapts its analysis for Chinese expression, broken English,
complex English reading, and word or fragment input. Word mode becomes a focused
vocabulary study card with American IPA, part of speech, meanings, forms and
tenses when relevant, phrase parts, collocations, examples, and usage notes.
For Chinese expression, Coach first improves the Chinese wording without dropping
key information or changing the original interpersonal tone, then uses that version
as the basis for both English translations.
Sentence cards use subtle phrase separation, predicate anchors, and
protected-meaning emphasis while Copy always returns unmarked text.

By default, the app invokes the installed `english-expression-coach` Skill with
`gpt-5.6-sol` and low reasoning. It runs Codex in read-only, ephemeral mode and
does not change the global Codex model configuration or the installed Skill.

## Model providers

The provider layer is replaceable. A user can select a provider in:

`~/Library/Application Support/EnglishCoachMini/provider.json`

Developers can implement `CoachProviding` directly, or connect any model through
the stable command-adapter contract. See [PROVIDER_INTERFACE.md](PROVIDER_INTERFACE.md)
and the runnable [OpenAI-compatible example](Examples/openai_compatible_adapter.py).

The adapter receives the complete coaching prompt and returns the model's raw
text response. API keys remain outside the app and should be managed by the
adapter or its environment.

## Build

Run `scripts/build_app.sh`. The packaged app is written to
`dist/English Coach Mini.app`.

Run the local verification suite with:

`swift run EnglishCoachMini --self-test`

## License

Licensed under the [Apache License 2.0](LICENSE). Contributions and compatible
provider integrations are welcome.
