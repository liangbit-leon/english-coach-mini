# Contributing

Contributions that improve coaching quality, model portability, parsing safety,
accessibility, or the reading experience are welcome.

## Design boundaries

- Keep model execution behind `CoachProviding`.
- Keep provider-neutral prompts and response schemas versioned.
- Do not place API keys, tokens, or user language material in source control.
- Preserve protected meaning such as negation, uncertainty, attribution,
  responsibility, permission, conditions, dates, amounts, and commitment level.
- Copy must continue to return clean, unmarked sentences.
- UI changes must remain usable in both light and dark appearance.

## Before proposing a change

```sh
swift build
swift run EnglishCoachMini --self-test
scripts/build_app.sh
```

For a new model provider, include a small adapter-contract test and document any
required environment variables. Provider-specific behavior should not leak into
the SwiftUI views.
