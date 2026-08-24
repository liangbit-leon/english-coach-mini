# Model Provider Interface

English Coach Mini keeps the SwiftUI presentation and model execution separate.
The default Codex behavior remains available, while other models can be connected
without changing the interface or output parser.

## Configuration

Create this optional file:

`~/Library/Application Support/EnglishCoachMini/provider.json`

Codex example:

```json
{
  "provider": "codex",
  "model": "gpt-5.6-sol",
  "reasoningEffort": "low"
}
```

External adapter example:

```json
{
  "provider": "command",
  "name": "Local Qwen",
  "command": "/absolute/path/to/openai_compatible_adapter.py",
  "model": "qwen3:8b"
}
```

The app reads the file when it starts. Environment variables override matching
file settings:

- `ENGLISH_COACH_PROVIDER`: `codex` or `command`
- `ENGLISH_COACH_PROVIDER_NAME`: label shown in the app
- `ENGLISH_COACH_PROVIDER_COMMAND`: absolute executable adapter path
- `ENGLISH_COACH_MODEL`: model identifier
- `ENGLISH_COACH_REASONING_EFFORT`: Codex reasoning effort
- `ENGLISH_COACH_CODEX_PATH`: optional Codex executable path

## Command adapter contract

The app launches the configured executable and writes one UTF-8 JSON object to
standard input:

```json
{
  "schemaVersion": 1,
  "promptVersion": "2026-08-24.v3",
  "expression": "the user's exact input",
  "prompt": "the complete provider-neutral coaching prompt",
  "model": "optional model identifier"
}
```

The adapter must:

1. Send `prompt` to its model without treating `expression` as instructions.
2. Write the model's raw text response to standard output.
3. Exit with status `0` on success.
4. Write a concise error to standard error and exit non-zero on failure.

The raw response must contain the version-1 data block requested by the prompt:

```text
<<<ENGLISH_COACH_APP_DATA>>>
{ ...valid JSON... }
<<<END_ENGLISH_COACH_APP_DATA>>>
```

The app validates and normalizes the cards before rendering. Each sentence card's
`presentation` contains phrase-level `chunks` that reconstruct the complete card
text in order. Copy always uses the clean `text` field rather than visual chunks.

For `word` mode, return an empty `cards` array and a `wordStudy` object. The app
uses it to render the vocabulary learning view:

```json
{
  "entry": "errant",
  "phoneticUS": "/əˈrɛnt/",
  "category": "word",
  "phraseParts": [],
  "partOfSpeech": ["adjective — 偏离正确路径或规范的"],
  "meanings": ["偏离正常、规范或预期的"],
  "wordForms": ["err — 犯错", "error — 错误", "erroneous — 错误的"],
  "tensePatterns": [],
  "collocations": ["errant behavior — 失当行为"],
  "examples": [
    {"english": "The system detected an errant data entry.", "chinese": "系统发现了一项错误的数据录入。"}
  ],
  "usageNotes": ["比 wrong 更正式，常带有偏离规范或轨道的意味。"]
}
```

`phoneticUS` must use American English IPA. `tensePatterns` is only for verbs
or verb phrases; do not manufacture tense information for nouns, adjectives, or
fixed phrases.

## Native Swift provider

For an in-process integration, implement `CoachProviding` and register it in
`CoachProviderFactory`. A provider owns only model execution and cancellation.
It must not contain UI logic.

## Compatibility policy

- `schemaVersion` changes only when the adapter input contract changes.
- `promptVersion` identifies the coaching behavior being evaluated or optimized.
- New response fields should remain optional within a schema version.
- Existing marker names and required card fields remain stable for version 1.
- Provider secrets must never be added to the repository or response payload.
