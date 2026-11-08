---
name: dsh-worker
description: >-
  Run a local DeepSeek Harness worker for scratch files only: clean up CSV or
  logs, summarize files already on disk, and draft text for a person to review.
  Do not use it to send messages, change accounts, obtain credentials, connect
  services, or edit a repository.
---

# dsh-worker

Dựa trên `grokbot-dsh-orchestrator-vn` của Diginno (CC BY 4.0). This text replaces `skills/dsh-worker/SKILL.md` for review. Save it only through the bot's own skill-authoring flow after a person reads it. Saving it does not change the bot's settings.

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

Use the pinned wrapper, not `npm i -g`, not `scripts/run-dsh.sh`, and not a bare `dsh` command:

```sh
~/.local/dsh-orchestrator/bin/run-dsh.sh <job-name> <prompt-file>
~/.local/dsh-orchestrator/bin/run-dsh.sh --pro <job-name> <prompt-file>
```

Do not run a live job until `test-isolation.sh` has passed on that box, a person has approved the provider spend, and `OPENCODE_API_KEY` is already in the environment. `--pro` selects `deepseek-v4-pro` and costs more. The default model id is `deepseek-v4.1-flash`. The job name is one path segment. The wrapper refuses a git checkout, a symlink job path, and a missing sandbox.

Put this constraint in every prompt: work only on files already in the current directory; do not read secrets; do not open network connections of your own; do not run git; if the data is missing, write "chưa rõ".

Read `run.jsonl` and `final.txt` from the job directory after the wrapper returns. Exit 0 means the process finished. Also require a final event whose reason says the turn completed before trusting the draft. A `MISSING_CREDENTIAL` error means the approved key is not in the environment. Stop. Do not print the environment.

## Jail boundary

The wrapper runs bubblewrap with every namespace unshared except the network. The network stays on the host because the provider API needs it. Child tools can also open network connections. That is not a closed network.

The process can see only the one job directory, the private Node and dsh install, this prefix's dsh home, and the system libraries and CA files required to start Node. It cannot see the real home, other bots, the host `/tmp`, `/root`, `/opt`, or `/var`. Its environment is cleared. The provider variable is passed only by the wrapper, and only when a person has already set it. The wrapper does not write that value into a file.

If bubblewrap is missing or its probe fails, the wrapper exits and does not run `dsh`. Landlock inside the jail is an extra restriction, not the boundary that hides other bots.

## Provider

The overlay points the Messages adapter at `https://opencode.ai/zen/go/v1` and reads `OPENCODE_API_KEY`. A live completion was not run. OpenCode documents DeepSeek Harness as a client whose session header is incomplete on some paths. If a real run fails, stop and report the error. Do not switch endpoints, add a second key, or route through 9router from this skill.
