# Install on the parent Linux box

This is the supported install. Do not follow the NodeSource `apt` steps or `npm i -g @deepseek-ai/dsh` in the repository README. Those steps replace or shadow the machine Node and install an unpinned package. Current `@deepseek-ai/dsh@0.2.2-rc.1` declares `node >= 24.9.0`.

The installer writes only under `~/.local/dsh-orchestrator` for the user who runs it. It does not use `sudo`, does not change system packages, and does not edit another app. Read `deploy/install-prefix.sh` before running it. It downloads two pinned archives and checks their hashes. It does not pipe a remote script into a shell.

## Approve this cost before a live run

No key is included. This installer does not sign up, does not call a model, and does not ask the bot to collect a key.

OpenCode Go, as documented at https://opencode.ai/docs/console/go/ on 2026-11-08, is a paid subscription:

| Plan | Price |
|---|---|
| Go | $10 per month |
| Go Plus | $40 per month |
| Go Teams | $20 per member per month |

Token prices on that page for the models this overlay names, per 1M tokens:

| Model | Off-peak input / output | Peak input / output | Go monthly allowance |
|---|---|---|---|
| DeepSeek V4.1 Flash | $0.15 / $0.60 | $0.30 / $1.20 | $100 |
| DeepSeek V4 Pro | $0.66 / $1.98 | $1.32 / $3.96 | $15 |

The source README's per-task figures of about $0.004–$0.02 were not measured again. DeepSeek models on Go also need the workspace privacy region set to Global. That is a provider setting, not something this installer changes.

The credential name, and the only one this workflow uses, is `OPENCODE_API_KEY`. After the spend is approved, a person stores it through the bot's existing secret flow. Do not paste it into chat, a prompt, this repository, or `cordis.patch.yml`. Do not create `DEEPSEEK_API_KEY`. Do not connect 9router.

## Commands

From a checkout of this repository, as the bot user:

```sh
bash deploy/install-prefix.sh
```

That command installs the private runtime, copies the secret-free config, and runs `deploy/verify.sh`. Expected verification line:

```text
verify ok: dsh 0.2.2-rc.1 on node v24.22.2; no model request was sent
credential status: absent
```

`absent` is the correct result until the approved key is in the environment. The installer must still exit 0.

Check that the system Node was not replaced:

```sh
command -v node
node -v
```

Those two lines should show the same Node as before the install. The private runtime is `~/.local/dsh-orchestrator/node/bin/node`.

A later check, still with no model call:

```sh
~/.local/dsh-orchestrator/bin/verify.sh
```

## One scratch job, only after the key and the spend are approved

```sh
mkdir -p "$HOME/scratch" "$HOME/.local/dsh-orchestrator/work/sample"
printf '%s\n' 'Summarize the file notes.txt in five lines. If the file is missing, say chưa rõ.' > "$HOME/scratch/prompt.txt"
printf '%s\n' 'sample notes' > "$HOME/.local/dsh-orchestrator/work/sample/notes.txt"
"$HOME/.local/dsh-orchestrator/bin/run-dsh.sh" sample "$HOME/scratch/prompt.txt"
```

Do not point the job at a git checkout. `--pro` switches to `deepseek-v4-pro` and spends more of the allowance. The wrapper refuses to start when `OPENCODE_API_KEY` is missing, and it never prints the value.

## Skill

`deploy/skills/dsh-worker/SKILL.md` is the text to review. Save it through the bot's own skill-authoring flow if you want the bot to use it. This repository does not change the bot's skills or settings. Do not save `skills/dsh-worker/SKILL.md`; that copy tells the bot to do work that conflicts with its approval, delegation, and credential rules.

## What the sandbox does

Tested on this x64 Linux host with the pinned Landlock launcher, bubblewrap not installed:

- A write inside the workspace was allowed.
- A write to another home directory outside the workspace was denied.
- A write under `/tmp` was allowed. `/tmp` is not a private job boundary.
- A read of a mode `0600` file outside the workspace, owned by the same user, was allowed.
- `curl https://example.com` from inside the sandbox returned HTTP 200. The file sandbox does not block the network.
- `read-only` denied a write in the workspace.
- On this host, `danger-full-access` still went through Landlock and did not gain those writes. Do not turn it on anyway. The documented meaning of that mode is to remove the fence.

Run the worker as a user that cannot read other bots' homes or secret files. The wrapper cannot add that separation.

## Tested and untested

Tested on linux x64, Node `v24.22.2`, package `0.2.2-rc.1`, with no provider key:

- package name, version, engine, maintainers, registry, and integrity
- launcher `--help` and headless `--help`, including `--json`, `--session-id`, and `--permission-mode`
- `cordis.patch.yml` accepted by `--dump-config`, including `tool-web: disabled`
- a headless "say hi" with the key unset and the base URL forced to `http://127.0.0.1:9` exited 1 with `MISSING_CREDENTIAL` and no provider HTTP error
- Landlock write, read, and network behavior described above
- Node `v22.23.4` can print `--version` and headless `--help`, and is still below the package engine

Not tested:

- any live completion, on OpenCode Go or on DeepSeek's own API
- whether `x-deepseek-harness-session-id` satisfies OpenCode's session check
- an arm64 install, beyond pinning the published checksums
- `node-pty` shell sessions; its Linux prebuild has no `spawn-helper`, and its install script was not run
- a full headless tool loop, because that needs a paid model call
- installing over an existing `~/.dsh` used by something else; this bundle uses its own `DSH_HOME`

## Blockers before real work

1. Approve the OpenCode Go subscription and the token prices above.
2. Put `OPENCODE_API_KEY` in the environment through the existing secret flow.
3. Expect the first real call to be a compatibility check. OpenCode still lists DeepSeek Harness as a client with incomplete session headers, and a keyless empty POST to the old and new Go URLs returned `MissingSessionID` before any model ran. No follow-up request was sent.
4. Keep other bot credentials out of this Unix user's readable files. The worker can read them.
