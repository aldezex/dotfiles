#!/usr/bin/env python3
"""Jev model router for Claude Code.

  router.py hook              UserPromptSubmit hook: stdin is the hook JSON; prints a note for Claude
  router.py on|off|status     switch the router / show counts and cost
  router.py test "msg" ...    classify messages without touching the counters

Claude Code can't switch models per message and a hook can't change the model. It can only add a
note. So the hook asks Jev to size the message, and the note tells Claude which helper agent
(each one pinned to a model) should do the work.

The hook never blocks. When the router is OFF, Jev is slow, the key is missing, or anything else
goes wrong, it prints nothing and exits 0.
"""
import fcntl
import json
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from jev import ENDPOINT, KEY_FILE, USD_PER_INPUT_TOKEN  # noqa: E402

STATE_FILE = os.environ.get(
    "JEV_ROUTER_STATE", os.path.expanduser("~/.config/typesafe/router_state.json")
)
TIMEOUT_S = 2.5
MIN_CONFIDENCE = 0.6
CONTEXT_REPLY_THRESHOLD = 0.5
MIN_WORDS = 4  # shorter messages ("yes", "ok go") skip Jev entirely

# size -> (helper agent, model it's pinned to)
TIERS = {
    "tiny": ("jev-tiny", "Haiku 4.5"),
    "everyday": ("jev-everyday", "Sonnet 5"),
    "large": ("jev-large", "Opus 5.5"),
    "hardest": ("jev-hardest", "Fable 5.1"),
}

QUESTIONS = {
    "size": {
        "type": "choice",
        "instructions": "What is the smallest AI model size that can do the job requested in this message well?",
        "criteria": {
            "tiny": "A lookup, a rename, a quick fact, or a one-line answer",
            "everyday": "A normal email, post, short document, or a small routine code change",
            "large": "A multi-step build, research across several sources, a full report, or a substantial code change",
            "hardest": "Strategy, high-stakes decisions, or anything where a wrong call is expensive",
        },
    },
    "context_reply": {
        "type": "noul",
        "instructions": (
            "Is this message a short follow-up reply that only makes sense in the context of an "
            "earlier conversation, such as 'yes do that' or 'make it shorter'?"
        ),
    },
}

DEFAULT_STATE = {"enabled": False, "counts": {}, "input_tokens": 0, "calls": 0}


def with_state(update=None):
    """Read the state file under a lock, optionally apply `update` and write it back."""
    os.makedirs(os.path.dirname(STATE_FILE), mode=0o700, exist_ok=True)
    fd = os.open(STATE_FILE, os.O_RDWR | os.O_CREAT, 0o600)
    with os.fdopen(fd, "r+") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        raw = f.read()
        state = {**DEFAULT_STATE, **(json.loads(raw) if raw.strip() else {})}
        if update:
            update(state)
            f.seek(0)
            f.truncate()
            json.dump(state, f, indent=2)
        return state


def ask_jev(message):
    with open(KEY_FILE) as f:
        key = f.read().strip()
    req = urllib.request.Request(
        ENDPOINT,
        data=json.dumps({"state": message, "model": "jev-latest", "questions": QUESTIONS}).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST",
    )
    start = time.perf_counter()
    with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
        data = json.load(resp)
    return data, time.perf_counter() - start


def decide(data):
    """Return (bucket, size, confidence, context_reply). bucket is a tier or 'self'."""
    size = data["answers"]["size"]
    context = data["answers"]["context_reply"]["noul"]
    if context >= CONTEXT_REPLY_THRESHOLD or size["confidence"] < MIN_CONFIDENCE:
        return "self", size["choice"], size["confidence"], context
    return size["choice"], size["choice"], size["confidence"], context


def note(bucket, size, confidence, context):
    if bucket == "self":
        why = (
            "it reads as a follow-up that depends on this conversation"
            if context >= CONTEXT_REPLY_THRESHOLD
            else f"Jev is unsure (best guess {size.upper()}, confidence {confidence:.2f} < {MIN_CONFIDENCE})"
        )
        return f"[Jev router] Handle this message yourself: {why}."
    agent, model = TIERS[bucket]
    return (
        f"[Jev router] Jev sized this as {bucket.upper()}, confidence {confidence:.2f}. "
        f"Hand the self-contained work to the `{agent}` agent (pinned to {model}) with a complete "
        f"brief, and relay its result, including its final 'Done by' line. If the job depends on "
        f"context only you have in this conversation, or needs your own tools or state, do it "
        f"yourself and say so."
    )


def hook():
    try:
        payload = json.load(sys.stdin)
        message = payload.get("prompt", "").strip()
        if not with_state()["enabled"]:
            return
        if message.startswith("/") or len(message.split()) < MIN_WORDS:
            with_state(lambda s: s["counts"].__setitem__("skipped", s["counts"].get("skipped", 0) + 1))
            return
        data, _ = ask_jev(message)
        bucket, size, confidence, context = decide(data)

        def record(s):
            s["counts"][bucket] = s["counts"].get(bucket, 0) + 1
            s["input_tokens"] += data.get("usage", {}).get("input_tokens", 0)
            s["calls"] += 1

        with_state(record)
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": note(bucket, size, confidence, context),
            }
        }))
    except Exception:
        pass  # never block or slow a message: act as if the router isn't there


def status():
    s = with_state()
    print(f"Jev router: {'ON' if s['enabled'] else 'OFF'}")
    counts = s["counts"]
    for key in [*TIERS, "self", "skipped"]:
        label = {"self": "handled by Claude (unsure / follow-up)", "skipped": "skipped (short or /command)"}.get(
            key, f"{key} -> {TIERS.get(key, ('', ''))[1]}"
        )
        print(f"  {label:<42} {counts.get(key, 0)}")
    cost = s["input_tokens"] * USD_PER_INPUT_TOKEN
    print(f"  Jev calls: {s['calls']}, input tokens: {s['input_tokens']}, cost: ${cost:.6f}")


def test(messages):
    print("| # | Message | Jev pick | Confidence | Follow-up? | Route |")
    print("|---|---|---|---|---|---|")
    total_tokens, total_time = 0, 0.0
    for i, message in enumerate(messages, 1):
        if len(message.split()) < MIN_WORDS:
            print(f"| {i} | {message} | — | — | — | skipped (too short) |")
            continue
        data, elapsed = ask_jev(message)
        bucket, size, confidence, context = decide(data)
        total_tokens += data["usage"]["input_tokens"]
        total_time += elapsed
        route = "Claude itself" if bucket == "self" else f"{TIERS[bucket][0]} ({TIERS[bucket][1]})"
        print(f"| {i} | {message} | {size} | {confidence:.2f} | {context:.2f} | {route} |")
    print(f"\nJev: {total_tokens} input tokens, ${total_tokens * USD_PER_INPUT_TOKEN:.6f}, "
          f"{total_time:.2f} s total")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "hook":
        hook()
    elif cmd in ("on", "off"):
        with_state(lambda s: s.__setitem__("enabled", cmd == "on"))
        status()
    elif cmd == "status":
        status()
    elif cmd == "test":
        test(sys.argv[2:])
    else:
        sys.exit("usage: router.py hook | on | off | status | test MSG...")


if __name__ == "__main__":
    main()
