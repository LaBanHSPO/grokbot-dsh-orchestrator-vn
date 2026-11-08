---
name: dsh-worker
description: >-
  Run a local DeepSeek Harness worker for scratch files only: clean up CSV or
  logs, summarize files already on disk, and draft text for a person to review.
  Do not use it to send messages, change accounts, obtain credentials, connect
  services, or edit a repository.
---

# dsh-worker

Dựa trên `grokbot-dsh-orchestrator-vn` của Diginno (CC BY 4.0). This text is a reviewed replacement for `skills/dsh-worker/SKILL.md` in commit `5b6c9392c86bbeeeb6263bc54375abf607c3ef60`. Save it only through the bot's own skill-authoring flow after a person reads it. Saving it does not change the bot's settings.

If any sentence here conflicts with the bot's built-in approval, draft, send, or delegation rules, follow the built-in rule and do not apply this skill.

## Hard limits

- This skill does not send, post, delete, or write to Lark, Zalo, Gmail, Drive, Cloudflare, or any other account. It does not relax or replace the bot's approval rules. A request to send or to change an account stops here.
- Repository and codebase work stays with the bot's built-in cloud-agent delegation. Do not use `dsh`, a local shell, or this skill to clone, edit, commit, push, or open a pull request. Do not point the worker at a git checkout.
- Do not ask for, read, copy, print, or store passwords, OAuth tokens, API keys, or connector credentials. Do not request MCP access, connector access, or account access. Do not request `DEEPSEEK_API_KEY` or any application token.
- The only credential name in this workflow is `OPENCODE_API_KEY`. A person provisions it after approving the provider cost. Never print its value and never ask for it in chat.
- Do not run a live worker task until that cost approval exists. A missing key is a stop, not a prompt to go obtain one.
- Do not set `DSH_PERMISSION_MODE=danger-full-access`, `--approval-policy never`, or `--add-dir`. Do not disable `DSH_TELEMETRY_DISABLED`.
- Do not use `web_search`, `web_fetch`, `curl`, `wget`, or any other network command to get around a tool block. The shipped overlay disables `tool-web`. Bash can still open network connections; do not ask it to.
- Do not install packages onto the machine, and do not change the system Node.js. Other bot apps stay as they are.

## What the worker may do

Use the worker only for a scratch job under the private prefix `~/.local/dsh-orchestrator/work/<job-name>`:

- clean or summarize CSV, logs, or text the bot placed in that directory
- draft Vietnamese text for a person to review
- write a small script and a test that run inside that same directory

The bot prepares the input files, checks the output, and decides what a person should see. Checking numbers, reading a draft, and rerunning a local test are part of this skill. Sending the result onward is not.

## How to run one job

Use the pinned wrapper, not `npm i -g` and not `scripts/run-dsh.sh`:

```sh
~/.local/dsh-orchestrator/bin/run-dsh.sh <job-name> <prompt-file>
~/.local/dsh-orchestrator/bin/run-dsh.sh --pro <job-name> <prompt-file>
```

`--pro` selects `deepseek-v4-pro` and costs more. The default model id is `deepseek-v4.1-flash`. The job name is one path segment. The wrapper creates the directory, forces `workspace-write`, disables telemetry, and refuses a git checkout.

Put this constraint in every prompt: work only on files already in the current directory; do not read secrets or other home directories; do not use the network; do not run git; if the data is missing, write "chưa rõ".

Read `run.jsonl` and `final.txt`. Exit 0 means the process finished. Also require a final event whose reason says the turn completed before trusting the draft. A `MISSING_CREDENTIAL` error means the approved key is not in the environment. Stop. Do not print the environment.

## Sandbox facts to remember

On Linux, `workspace-write` uses Landlock when bubblewrap is absent. A tested run could write inside its workspace and anywhere under `/tmp`, and it could read another file owned by the same user outside the workspace. It could also reach the public network. A write to a home directory outside the workspace was denied. `read-only` denied the workspace write. Treat `/tmp` and the bot user's home as visible to the worker. Do not store other apps' credentials where this user can read them.

## Provider

The overlay points the Messages adapter at `https://opencode.ai/zen/go/v1` and reads `OPENCODE_API_KEY`. A live completion was not run. OpenCode documents DeepSeek Harness as a client whose session header is incomplete on some paths. If a real run fails, stop and report the error. Do not switch endpoints, add a second key, or route through 9router from this skill.
