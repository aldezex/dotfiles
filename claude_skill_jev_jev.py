#!/usr/bin/env python3
"""Call Jev (TypeSafe System One) directly.

Reads a request from stdin: {"state": ..., "questions": {...}, "model"?: "..."}
Prints the API response as JSON plus a "_meta" block with latency and cost.

The API key comes from $TYPESAFE_API_KEY or ~/.config/typesafe/api_key.
It is never printed.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

ENDPOINT = "https://api.typesafe.ai/v1/systemone"
DEFAULT_MODEL = "jev-latest"
USD_PER_INPUT_TOKEN = 0.042 / 1_000_000  # jev-1.13: $0.042/Mtok input, output free
KEY_FILE = os.path.expanduser("~/.config/typesafe/api_key")


def load_key():
    key = os.environ.get("TYPESAFE_API_KEY")
    if not key:
        try:
            with open(KEY_FILE) as f:
                key = f.read().strip()
        except FileNotFoundError:
            sys.exit(f"No API key: set TYPESAFE_API_KEY or create {KEY_FILE}")
    return key


def main():
    request = json.load(sys.stdin)
    request.setdefault("model", DEFAULT_MODEL)
    body = json.dumps(request).encode()
    req = urllib.request.Request(
        ENDPOINT,
        data=body,
        headers={
            "Authorization": f"Bearer {load_key()}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    start = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.load(resp)
    except urllib.error.HTTPError as e:
        elapsed = time.perf_counter() - start
        print(f"HTTP {e.code} {e.reason} after {elapsed * 1000:.0f} ms", file=sys.stderr)
        print(e.read().decode(errors="replace"), file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        sys.exit(f"Connection error: {e.reason}")
    elapsed = time.perf_counter() - start

    input_tokens = data.get("usage", {}).get("input_tokens", 0)
    data["_meta"] = {
        "latency_ms": round(elapsed * 1000),
        "cost_usd": round(input_tokens * USD_PER_INPUT_TOKEN, 8),
    }
    json.dump(data, sys.stdout, indent=2, ensure_ascii=False)
    print()


if __name__ == "__main__":
    main()
