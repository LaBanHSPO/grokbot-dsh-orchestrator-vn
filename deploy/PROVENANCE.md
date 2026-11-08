# Provenance

This directory is a reviewed install bundle for the parent Linux box. It does not contain an API key, a token, or `node_modules`.

## Source repository

| Field | Value |
|---|---|
| Repository | https://github.com/LaBanHSPO/grokbot-dsh-orchestrator-vn |
| Commit | `5b6c9392c86bbeeeb6263bc54375abf607c3ef60` |
| Commit time | 2026-10-21 21:58:43 +0700 |
| Subject | Bản đầu tiên: Grok Bot điều phối, DeepSeek Harness làm worker giá rẻ |
| Content license | CC BY 4.0 for text and the skill. MIT for `scripts/` and `config/` in the source repo. |
| Suggested credit | Dựa trên `grokbot-dsh-orchestrator-vn` của Diginno (CC BY 4.0). |

The original GitHub path named in the README is `diginno-net`. This bundle was taken from the accessible `LaBanHSPO` repository at the commit above. No fork was created.

## Runtime pins, checked on 2026-11-08

| Component | Pin |
|---|---|
| npm registry | `https://registry.npmjs.org/` |
| Package | `@deepseek-ai/dsh@0.2.2-rc.1` |
| Package integrity | `sha512-ijR9UEVYkG15Q/Q79JzvzLBzQOQfc63VLr9n6flpwHPhr5IKn2UxthnSoto/P9l7qGd7pPvI1Ra6TW7LH3oKpg==` |
| Tarball sha1 | `95d1cf510061a57c97b4a68d43336658bcec6af1` |
| Tarball sha256 | `ad21968aed0337a326b853507a23b30eacbbec4d67ab07f3b6fde69b75b19cd6` |
| Upstream repository | https://github.com/deepseek-ai/deepseek-harness (`apps/cli`) |
| npm maintainers | `imccyu`, `tianyicui-deepseek` |
| Engines | `node >= 24.9.0` |
| dist-tag `latest` at check time | `0.2.2-rc.1` (published 2026-11-04) |
| Node.js | `24.22.2` from `https://nodejs.org/dist/v24.22.2/` |
| `linux-x64` sha256 | `48cc0e21e048790e54c0cf5749c2725005313d652651c40b7a21feb9697aaf75` |
| `linux-arm64` sha256 | `eb187837a2230d4047161ac0be008584e16b46f726e9c9490ee35dc6b17d9ba8` |
| Landlock launcher | `@deepseek-ai/node-addon-system-linux-x64@0.1.2` integrity `sha512-S2aPVHvYCpNCppCFyNlooMYuTB7ucK5lvD9oXQQ42v5Z2s5AoaiCdjz9r2l+ED2rI5oS1x0cUZmKjJH2dxV0pg==` |
| Landlock launcher, arm64, not executed here | `@deepseek-ai/node-addon-system-linux-arm64@0.1.2` integrity `sha512-Z/DQtqgEYzjBzb2ocHGjMzx51W7xDILkJKKj89nyErr8gZMNiLs+JNL1uKzJqc3VLZB+vYCPaHGyQ3oX6EzEmA==` |

`npm install` is run with `--ignore-scripts`. The inspected lifecycle scripts that this skips include native builds for `koffi` and `node-pty`, a `chmod` of `node-pty`'s `spawn-helper`, and `protobufjs`'s postinstall. The Linux x64 `node-pty` tarball ships `pty.node` and does not ship `spawn-helper`. The Landlock launcher is a prebuilt binary in its own tarball and does not need those scripts.

## Config schema that was checked

`dsh --profile headless --patch <file> --dump-config` accepted the model overlay. The composed row is `llm-deepseek` / `@deepseek-ai/dsh-llm-deepseek-api-key` with:

- `baseURL: https://opencode.ai/zen/go/v1`
- `apiKeyEnv: OPENCODE_API_KEY`
- model ids `deepseek-v4.1-flash` and `deepseek-v4-pro`
- `agent-default-model.model: deepseek-v4.1-flash`

Current upstream defaults, when that overlay is absent, are `model: deepseek-flash` and base URL `https://api.deepseek.com/anthropic`. The overlay replaces that catalog. `tool-web` is additionally set to `disabled: true` in this bundle; the dump kept the row and marked it disabled.

The Messages adapter posts to `{baseURL}/messages` with `x-api-key` and `anthropic-version: 2023-06-01`. It also sends `x-deepseek-harness-session-id` when it has a session id.
