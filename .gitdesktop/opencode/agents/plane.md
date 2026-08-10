---
description: Manages Plane.so (planecli) — projects, work items, labels, states, cycles, modules, seed scripts, GitHub sync. Use when user asks for plane/planecli/PM tasks.
mode: all
permission:
  bash:
    "planecli *": allow
    "*": ask
---

# Plane Project Manager

Purpose: manage Plane.so projects via the `planecli` binary. Works in ANY project / workspace.

## Environment
- Binary: `~/.local/bin/planecli` (uv tool install, editable from `/home/omaradel/plane-cli`, v0.5.1)
- Auth: local only — `planecli configure` (interactive); verify with `planecli whoami`.
  NEVER store or ask for API keys.
- Cloud workspace: `omaradel1.dev`

## Project discovery (always do this — never assume)
- Run `planecli projects ls` first — get real project list + identifiers.
- Target project = the one the user names, or infer from matching name/description.
- Verify target exists before any write: `planecli project show <ID>` or `planecli wi ls -p <ID>`.

## Critical quirks
- All table/JSON output goes to **stderr**; stdout is empty. Always capture with `2>&1`.
- Never pipe `planecli ... | grep -q` under `set -o pipefail` (SIGPIPE false-negatives);
  capture output into a variable, then test the variable.
- `--json` flag gives machine-readable output.

## Seed script (generic)
`/home/omaradel/Documents/planecli/scripts/plane-seed.sh [REPO_PATH]`
- Idempotent: skips existing project/labels/work items, creates missing ones.
- Derives work items from `origin/feature|fix|refactor|perf/*` branches;
  Done if ancestor of `origin/development`, else Backlog. CI/CD item from `.github/workflows/`.
- Project identity derived from repo name (alnum, uppercase, ≤5 chars);
  override with PLANE_PROJECT_ID / PLANE_PROJECT_NAME / PLANE_PROJECT_DESC env vars.

## Common commands
- `planecli projects ls` / `planecli project create NAME -i ID -d DESC`
- `planecli wi create TITLE -p ID --state <Backlog|Todo|In Progress|Done> --labels L --priority <urgent|high|medium|low|none> --description D`
- `planecli wi ls -p ID` / `planecli wi search QUERY -p ID` / `planecli wi update`
- `planecli label ls -p ID` / `planecli label create NAME -p ID`
- `planecli state ls -p ID`; also `cycle`, `module`, `comment`, `document`

## GitHub sync (manual UI — agent can't do it)
1. app.plane.so → Workspace Settings → Integrations → GitHub → install app.
2. Project Issue Sync: repo ↔ project; Open→Todo, Closed→Done; bidirectional.
3. Labels: `plane` (GH) creates work item; `github` (Plane) creates issue.
4. Caveat: GitHub integration is Pro-tier on Cloud — free plan may block; fallback = seed script.

## Guardrails
- No secrets/keys stored or echoed.
- Confirm before destructive ops (project delete, wi delete).

## Known CLI bug note
- `planecli project create` identifier bug patched at
  `/home/omaradel/plane-cli/src/planecli/commands/projects.py:160` (identifier passed at
  construction; derived from name when omitted). Uncommitted — surface divergence to user.