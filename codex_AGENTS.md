# Efficient workflow

- Use the smallest reliable workflow that completes the task. For small changes: inspect the relevant code, edit, and run the relevant checks.
- Use skills only when clearly relevant or explicitly requested. Avoid automatically chaining planning, brainstorming, reviews, or reports for routine tasks.
- Use one agent by default. Delegate only when explicitly requested or when independent substantial work justifies the extra context; give agents minimal task-specific context.
- Search paths and symbols first, then read focused sections. Reuse findings already in context. Avoid dumping whole files, logs, schemas, or transcripts.
- Batch independent queries. Request concise tool output; filter or save large results to files and inspect only relevant sections. Expand truncated output when necessary for correctness.
- Run required and relevant checks. Repeat or broaden them only after changes, failures, or unresolved concerns. Never omit necessary validation to save tokens.
- Keep plans, progress updates, and final answers concise. Avoid duplicate summaries and unsolicited documentation.
- Keep project AGENTS.md focused on commands, architecture, and constraints; consult detailed documentation on demand. For a new unrelated task, prefer a new thread with a short handoff when needed.
- Plugins, apps, and Notion are opt-in globally. Optional CLI profiles: unity, superpowers, integraciones, completo. Do not enable integrations without a task that needs them.

## Session resources

- Prefer the existing checkout. Never create throwaway clones when a worktree suffices.
- For temporary isolation use `python3 "${CODEX_HOME:-$HOME/.codex}/hooks/session-cleanup.py" create TASK --repo "$PWD"`. It uses CODEX_THREAD_ID; pass --session explicitly if unavailable. This registers ownership for cleanup.
- Before finishing, integrate completed work into the primary checkout as authorized, remove only your known disposable build outputs, and report anything retained. Never discard uncommitted changes, unique commits, ignored secrets, locked worktrees, or another session's resources.
- SessionStart/SessionEnd hooks clean only registered worktrees of ended sessions. Hooks never scan /tmp, Docker, other agents' worktrees, or Codex-native worktrees. Clean your own extra temporary resources explicitly. Reports: ~/.codex/cleanup/report.log.
