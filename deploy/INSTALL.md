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

## One scratch job, only after isolation passes and the spend is approved

Do not start a live worker until all three are true:

1. `bash deploy/test-isolation.sh` prints `ISOLATION PASS` on this box.
2. A person has approved the OpenCode Go subscription and the token prices above.
3. `OPENCODE_API_KEY` is in the environment through the existing secret flow.

Re-run `bash deploy/install-prefix.sh` from this commit before that test. It refreshes the wrappers under the private prefix and does not replace system Node. It leaves an existing `cordis.patch.yml` in place.

```sh
mkdir -p "$HOME/scratch" "$HOME/.local/dsh-orchestrator/work/sample"
printf '%s\n' 'Summarize the file notes.txt in five lines. If the file is missing, say chưa rõ.' > "$HOME/scratch/prompt.txt"
printf '%s\n' 'sample notes' > "$HOME/.local/dsh-orchestrator/work/sample/notes.txt"
"$HOME/.local/dsh-orchestrator/bin/run-dsh.sh" sample "$HOME/scratch/prompt.txt"
```

Do not point the job at a git checkout. `--pro` switches to `deepseek-v4-pro` and spends more of the allowance. The wrapper refuses to start when `OPENCODE_API_KEY` is missing, when bubblewrap is unavailable, or when the job path is a symlink. It never prints the key.

## Skill

`deploy/skills/dsh-worker/SKILL.md` is the text to review. Save it through the bot's own skill-authoring flow if you want the bot to use it. This repository does not change the bot's skills or settings. Do not save `skills/dsh-worker/SKILL.md`; that copy tells the bot to do work that conflicts with its approval, delegation, and credential rules.

## Filesystem and network boundary

`run-dsh.sh` calls `isolate-run.sh`. There is no unsandboxed fallback. The profile is `bwrap --unshare-all --share-net`: user, mount, PID, UTS, IPC, and cgroup namespaces are new, and the network namespace is the host's on purpose.

The provider call cannot work with an empty network namespace. A test of that empty namespace fails to resolve `example.com`. The worker profile does not use it. Child tools can also open network connections. Do not treat the network as closed.

What the jail can see:

- the one job directory, read-write, mounted at `/work`
- the private Node and dsh install, read-only
- this prefix's dsh home (config and session logs), read-write
- read-only system directories needed to start Node: `/usr`, `/bin`, `/lib`, `/lib64`, and `/sbin` when they exist
- a few `/etc` files: resolver, CA certificates, hosts, nsswitch, passwd, and group

What it cannot see:

- the real home directory, other bots' files, `/root`, `/opt`, `/var`, and the host `/tmp`
- `/etc/shadow`
- environment variables other than the fixed jail set. `OPENCODE_API_KEY` is added only by `run-dsh.sh`, and only when it is already set. The wrapper does not copy it into a file.

`/tmp` inside the jail is a fresh tmpfs. A write there does not land on the host. Landlock still runs inside this mount namespace; it is not the boundary that hides other bots. A same-user Landlock process without this jail can read other bots' files. Do not run `dsh` by hand.

If `bwrap` is missing, not root-owned, or its startup probe fails, the wrapper exits 2 and does not run the command.

## Tested and untested

Tested on linux x64 with bubblewrap 0.9.0, Node `v24.22.2`, and `dsh` `0.2.2-rc.1`, with no provider key:

- package name, version, engine, registry, and integrity on the earlier install
- launcher and headless help, composed config, and disabled `tool-web`
- `deploy/test-isolation.sh`: outside reads and writes, host `/tmp`, `/etc/shadow`, symlinks, physical `..`, environment leakage, forced `workspace-write`, explicit provider-variable passthrough through `/bin/sh` only, public network still open, empty network namespace closed, symlink job rejected, missing `bwrap` fails closed, `dsh --version` inside the jail, and a no-key headless prompt stops with `MISSING_CREDENTIAL`
- the existing Node `v22.23.4` was not replaced

Not tested:

- any live completion, on OpenCode Go or on DeepSeek's own API
- whether `x-deepseek-harness-session-id` satisfies OpenCode's session check
- an arm64 install, beyond pinning the published checksums
- `node-pty` shell sessions; its Linux prebuild has no `spawn-helper`, and its install script was not run
- a full headless tool loop, because that needs a paid model call
- the parent's already-installed copy; this change does not edit `/home/box`

## Blockers before real work

1. Re-run `bash deploy/install-prefix.sh` from this commit and require `bash deploy/test-isolation.sh` to pass.
2. Approve the OpenCode Go subscription and the token prices above.
3. Put `OPENCODE_API_KEY` in the environment through the existing secret flow.
4. Expect the first real call to be a compatibility check. OpenCode still lists DeepSeek Harness as a client with incomplete session headers. A keyless empty POST to the Go URLs returned `MissingSessionID` before any model ran. No follow-up request was sent.

