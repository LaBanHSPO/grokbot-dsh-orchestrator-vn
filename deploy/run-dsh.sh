#!/usr/bin/env bash
# Run one headless dsh job in a scratch directory outside /tmp and outside any git checkout.
# Does not accept extra dsh flags. Does not print OPENCODE_API_KEY.
# MIT license. Copyright (c) 2026 Diginno. See the repository LICENSE.
set -euo pipefail
umask 077

PREFIX="${DSH_ORCH_PREFIX:-$HOME/.local/dsh-orchestrator}"
NODE="$PREFIX/node/bin/node"
DSH="$PREFIX/app/node_modules/.bin/dsh"
WORK_ROOT="$PREFIX/work"
export DSH_HOME="$PREFIX/home"
export DSH_TELEMETRY_DISABLED=1
export PATH="$PREFIX/node/bin:$PATH"

if [ "${DSH_PERMISSION_MODE:-workspace-write}" != "workspace-write" ]; then
  echo "Refusing to run with DSH_PERMISSION_MODE=${DSH_PERMISSION_MODE}" >&2
  exit 2
fi
export DSH_PERMISSION_MODE=workspace-write

PRO=0
if [ "${1:-}" = "--pro" ]; then
  PRO=1
  shift
fi
if [ "$#" -ne 2 ]; then
  echo "usage: run-dsh.sh [--pro] <job-name> <prompt-file>" >&2
  exit 2
fi
NAME="$1"
PROMPT_FILE="$2"
if ! [[ "$NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
  echo "job name must be one path segment made of letters, numbers, dots, underscores, or hyphens" >&2
  exit 2
fi
if [ ! -f "$PROMPT_FILE" ]; then
  echo "prompt file not found" >&2
  exit 2
fi
if grep -q "OPENCODE_API_KEY" "$PROMPT_FILE"; then
  echo "Refusing a prompt that names OPENCODE_API_KEY." >&2
  exit 2
fi
if [ -z "${OPENCODE_API_KEY-}" ]; then
  echo "OPENCODE_API_KEY is absent. Not running. Do not paste the key into chat or into a file." >&2
  exit 2
fi
[ -x "$NODE" ] && [ -x "$DSH" ] || { echo "dsh is not installed under $PREFIX" >&2; exit 2; }

mkdir -p "$WORK_ROOT"
WORKDIR="$WORK_ROOT/$NAME"
mkdir -p "$WORKDIR"
dir="$WORKDIR"
while [ "$dir" != "/" ]; do
  if [ -e "$dir/.git" ]; then
    echo "Refusing to run inside a git checkout: $dir" >&2
    exit 2
  fi
  dir="$(dirname "$dir")"
done

{
  echo "Safety rules for this run:"
  echo "- Work only on the files already in this directory."
  echo "- Do not read or write files outside this directory."
  echo "- Do not use the network and do not run curl, wget, ssh, git, or npm."
  echo "- Do not print environment variables, tokens, or keys."
  echo "- If the task needs a secret, a browser, an account, or a repository, stop and say so."
  echo
  cat "$PROMPT_FILE"
} > "$WORKDIR/prompt.txt"

PATCH_ARGS=()
if [ "$PRO" -eq 1 ]; then
  PATCH_ARGS=(--patch "$DSH_HOME/patches/pro.patch.yml")
fi

cd "$WORKDIR"
set +e
"$NODE" "$DSH" --profile headless "${PATCH_ARGS[@]}" --permission-mode workspace-write --json - < "$WORKDIR/prompt.txt" > run.jsonl 2> run.err
RC=$?
set -e

"$NODE" -e '
const fs = require("fs");
let text = "";
let reason = null;
for (const line of fs.readFileSync("run.jsonl", "utf8").split("\n")) {
  if (!line.trim()) continue;
  try {
    const event = JSON.parse(line);
    if (event.type === "final") {
      text = event.text || "";
      reason = event.reason || null;
    }
  } catch {}
}
fs.writeFileSync("final.txt", text);
const kind = reason && reason.kind ? reason.kind : "";
fs.writeFileSync("final.reason", kind);
' || true

echo "dsh finished: exit=$RC reason=$(cat final.reason 2>/dev/null || true) dir=$WORKDIR" >&2
if [ -s final.txt ]; then
  cat final.txt
fi
if [ "$RC" -eq 0 ] && [ "$(cat final.reason 2>/dev/null || true)" != "completed" ]; then
  echo "The process exited 0 but the final reason is not completed." >&2
  exit 1
fi
exit "$RC"
