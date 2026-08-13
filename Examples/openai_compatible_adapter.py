#!/usr/bin/env python3
"""English Coach Mini adapter for an OpenAI-compatible chat endpoint."""

import json
import os
import sys
import urllib.error
import urllib.request


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    try:
        request = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        fail(f"Invalid adapter request: {error}")

    if request.get("schemaVersion") != 1:
        fail("Unsupported English Coach provider schema version.")

    prompt = request.get("prompt")
    if not isinstance(prompt, str) or not prompt:
        fail("The adapter request did not contain a prompt.")

    base_url = os.environ.get(
        "OPENAI_COMPATIBLE_BASE_URL", "http://127.0.0.1:11434/v1"
    ).rstrip("/")
    model = request.get("model") or os.environ.get("ENGLISH_COACH_ADAPTER_MODEL")
    if not model:
        fail("Configure a model in provider.json or ENGLISH_COACH_ADAPTER_MODEL.")

    payload = json.dumps(
        {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.2,
        }
    ).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    api_key = os.environ.get("OPENAI_COMPATIBLE_API_KEY")
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    http_request = urllib.request.Request(
        f"{base_url}/chat/completions",
        data=payload,
        headers=headers,
        method="POST",
    )

    try:
        with urllib.request.urlopen(http_request, timeout=180) as response:
            result = json.load(response)
        content = result["choices"][0]["message"]["content"]
    except (urllib.error.URLError, KeyError, IndexError, json.JSONDecodeError) as error:
        fail(f"Model request failed: {error}")

    if not isinstance(content, str) or not content.strip():
        fail("The model returned an empty response.")
    sys.stdout.write(content)


if __name__ == "__main__":
    main()
