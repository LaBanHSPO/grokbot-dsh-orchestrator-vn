#!/usr/bin/env bash
# Check the private install without calling a model API and without printing secrets.
# MIT license. Copyright (c) 2026 Diginno. See the repository LICENSE.
set -euo pipefail

PREFIX="${DSH_ORCH_PREFIX:-$HOME/.local/dsh-orchestrator}"
NODE="$PREFIX/node/bin/node"
DSH="$PREFIX/app/node_modules/.bin/dsh"
export DSH_HOME="$PREFIX/home"
export DSH_TELEMETRY_DISABLED=1
export DSH_PERMISSION_MODE=workspace-write
export PATH="$PREFIX/node/bin:$PATH"

fail() { echo "FAIL: $*" >&2; exit 1; }

script_dir="$(cd "$(dirname "$0")" && pwd)"
[ -x "$NODE" ] || fail "private node is missing"
[ -x "$script_dir/isolate-run.sh" ] || fail "isolate-run.sh is missing beside verify.sh"
[ "$("$NODE" -v)" = "v24.22.2" ] || fail "private node is not v24.22.2"
[ -x "$DSH" ] || fail "dsh is missing"
[ "$("$NODE" "$DSH" --version)" = "0.2.2-rc.1" ] || fail "dsh version is not 0.2.2-rc.1"

launcher_help="$(mktemp)"
headless_help="$(mktemp)"
DUMP="$(mktemp)"
trap 'rm -f "$DUMP" "$launcher_help" "$headless_help"' EXIT
"$NODE" "$DSH" --help > "$launcher_help"
"$NODE" "$DSH" --profile headless --help > "$headless_help"
grep -q -- "--profile" "$launcher_help" || fail "launcher help has no --profile"
grep -q -- "--json" "$headless_help" || fail "headless help has no --json"
grep -q -- "--permission-mode" "$headless_help" || fail "headless help has no --permission-mode"

"$NODE" "$DSH" --profile headless --dump-config > "$DUMP"
grep -q "baseURL: https://opencode.ai/zen/go/v1" "$DUMP" || fail "OpenCode base URL is not in the composed config"
grep -q "apiKeyEnv: OPENCODE_API_KEY" "$DUMP" || fail "OPENCODE_API_KEY is not the model credential name"
grep -q "id: deepseek-v4.1-flash" "$DUMP" || fail "flash model id is missing"
grep -q "mode: !!js process.env.DSH_PERMISSION_MODE ?? 'workspace-write'" "$DUMP" || fail "default sandbox mode is not workspace-write"
awk '
  /^- id: tool-web$/ { row = 1; next }
  row && /^- id: / { row = 0 }
  row && /disabled: true/ { found = 1 }
  END { exit found ? 0 : 1 }
' "$DUMP" || fail "tool-web was not disabled"

# Presence only. The value is never printed.
if [ -n "${OPENCODE_API_KEY-}" ]; then
  echo "credential status: present"
else
  echo "credential status: absent"
fi
echo "verify ok: dsh 0.2.2-rc.1 on node v24.22.2; no model request was sent"
