#!/usr/bin/env bash
# Adversarial checks for isolate-run.sh. No provider key and no model call.
# MIT license. Copyright (c) 2026 Diginno. See the repository LICENSE.
set -euo pipefail
umask 077

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
ISOLATE="$SOURCE_DIR/isolate-run.sh"
PREFIX="${DSH_ORCH_PREFIX:-$HOME/.local/dsh-orchestrator}"
export DSH_ORCH_PREFIX="$PREFIX"
FAIL=0

say() { printf '%s\n' "$*"; }
pass() { say "PASS: $*"; }
fail() { FAIL=1; say "FAIL: $*"; }

[ -x "$ISOLATE" ] || { say "FAIL: isolate-run.sh is missing"; exit 1; }
[ -x /usr/bin/bwrap ] || [ -x /usr/local/bin/bwrap ] || { say "FAIL: bwrap is not installed"; exit 1; }
[ -x "$PREFIX/node/bin/node" ] || { say "FAIL: private node is missing; install the prefix first"; exit 1; }

run_job() {
  local name="$1"
  shift
  "$ISOLATE" --job "$name" -- "$@"
}

# 1. Outside read, outside write, private /tmp, symlink, and parent escape.
OUTSIDE="$(mktemp -d)"
printf '%s\n' 'other-bot-secret' > "$OUTSIDE/secret.txt"
chmod 600 "$OUTSIDE/secret.txt"
HOST_TMP="$(mktemp /tmp/other-bot-tmp.XXXXXX)"
printf '%s\n' 'host-tmp-secret' > "$HOST_TMP"
chmod 600 "$HOST_TMP"
JOB_READ="iso-read-$$"
mkdir -p "$PREFIX/work/$JOB_READ"
ln -s "$OUTSIDE/secret.txt" "$PREFIX/work/$JOB_READ/leak"
ln -s /etc/shadow "$PREFIX/work/$JOB_READ/shadow"
mkdir -p "$PREFIX/work/$JOB_READ/sub"
ln -s .. "$PREFIX/work/$JOB_READ/sub/up"
ln -s / "$PREFIX/work/$JOB_READ/rootlink"

export CANARY_OTHER_BOT=canary-value-42
export AWS_SECRET_ACCESS_KEY=not-a-real-cloud-secret
export SSH_AUTH_SOCK=/tmp/should-not-pass
export GITHUB_TOKEN=not-a-real-github-token
export DSH_PERMISSION_MODE=danger-full-access

set +e
RESULT="$(run_job "$JOB_READ" /bin/sh -c '
  host_secret="$1"
  host_tmp="$2"
  read_host=$(cat "$host_secret" 2>/dev/null || echo BLOCKED)
  read_link=$(cat /work/leak 2>/dev/null || echo BLOCKED)
  read_shadow=$(cat /etc/shadow 2>/dev/null || echo BLOCKED)
  read_shadow_link=$(cat /work/shadow 2>/dev/null || echo BLOCKED)
  read_tmp=$(cat "$host_tmp" 2>/dev/null || echo BLOCKED)
  ( echo pwned > "$host_secret" ) 2>/dev/null || true
  ( echo pwned > "$host_tmp" ) 2>/dev/null || true
  echo ok > /work/inside.txt
  echo jail > /tmp/jail-only.txt
  up_phys=$(cd -P /work/sub/up && pwd -P)
  root_phys=$(cd -P /work/.. && pwd -P)
  home_list=$(ls -A /home | tr "\n" ",")
  canary=${CANARY_OTHER_BOT-UNSET}
  aws=${AWS_SECRET_ACCESS_KEY-UNSET}
  sock=${SSH_AUTH_SOCK-UNSET}
  gh=${GITHUB_TOKEN-UNSET}
  key=${OPENCODE_API_KEY-UNSET}
  mode=${DSH_PERMISSION_MODE-UNSET}
  printf "read_host=%s\nread_link=%s\nread_shadow=%s\nread_shadow_link=%s\nread_tmp=%s\nup_phys=%s\nroot_phys=%s\nhome=%s\ncanary=%s\naws=%s\nsock=%s\ngh=%s\nkey=%s\nmode=%s\n" \
    "$read_host" "$read_link" "$read_shadow" "$read_shadow_link" "$read_tmp" \
    "$up_phys" "$root_phys" "$home_list" "$canary" "$aws" "$sock" "$gh" "$key" "$mode"
' _ "$OUTSIDE/secret.txt" "$HOST_TMP")"
RC=$?
set -e
unset DSH_PERMISSION_MODE

if [ "$RC" -eq 0 ]; then
  pass "jail command exited 0"
else
  fail "jail command exited $RC"
fi
value() { printf '%s\n' "$RESULT" | sed -n "s/^$1=//p"; }
[ "$(value read_host)" = "BLOCKED" ] && pass "absolute outside read blocked" || fail "absolute outside read was not blocked"
[ "$(value read_link)" = "BLOCKED" ] && pass "job symlink read blocked" || fail "job symlink read was not blocked"
[ "$(value read_shadow)" = "BLOCKED" ] && pass "/etc/shadow unmounted" || fail "/etc/shadow was readable"
[ "$(value read_shadow_link)" = "BLOCKED" ] && pass "shadow symlink blocked" || fail "shadow symlink was readable"
[ "$(value read_tmp)" = "BLOCKED" ] && pass "host /tmp file unreadable" || fail "host /tmp file was readable"
[ "$(value up_phys)" = "/work" ] && pass "job symlink resolves inside the job mount" || fail "job symlink resolved to $(value up_phys)"
[ "$(value root_phys)" = "/" ] && pass "physical .. leaves the job at the jail root, not the host parent" || fail "physical .. resolved to $(value root_phys)"
[ "$(value home)" = "worker," ] && pass "home contains only the private worker directory" || fail "home listing: $(value home)"
[ "$(value canary)" = "UNSET" ] && pass "unrelated canary env dropped" || fail "canary env leaked"
[ "$(value aws)" = "UNSET" ] && pass "cloud credential env dropped" || fail "cloud credential env leaked"
[ "$(value sock)" = "UNSET" ] && pass "ssh agent socket env dropped" || fail "ssh agent socket env leaked"
[ "$(value gh)" = "UNSET" ] && pass "github token env dropped" || fail "github token env leaked"
[ "$(value key)" = "UNSET" ] && pass "provider key absent when not passed" || fail "provider key was visible without the pass flag"
[ "$(value mode)" = "workspace-write" ] && pass "permission mode forced to workspace-write" || fail "permission mode was $(value mode)"
[ "$(cat "$OUTSIDE/secret.txt")" = "other-bot-secret" ] && pass "outside file unchanged" || fail "outside file was modified"
[ "$(cat "$HOST_TMP")" = "host-tmp-secret" ] && pass "host tmp file unchanged" || fail "host tmp file was modified"
[ "$(cat "$PREFIX/work/$JOB_READ/inside.txt")" = "ok" ] && pass "job write is visible to the parent" || fail "job write missing"
[ ! -e /tmp/jail-only.txt ] && pass "jail /tmp does not appear on the host" || fail "jail /tmp leaked onto the host"

# 2. Provider-key passthrough is explicit, still with /bin/sh and no dsh task.
cred_var="$(printf '%s_%s_%s' OPENCODE API KEY)"
printf -v "$cred_var" '%s' 'synthetic-not-a-provider-key'
export "$cred_var"
set +e
"$ISOLATE" --job "iso-key-$$" --pass-provider-key -- /bin/sh -c '
  [ "${OPENCODE_API_KEY-}" = "synthetic-not-a-provider-key" ] || exit 3
  [ -z "${CANARY_OTHER_BOT-}" ] || exit 4
'
RC=$?
set -e
unset "$cred_var"
if [ "$RC" -eq 0 ]; then
  pass "only the named provider variable is passed, and only with the flag"
else
  fail "provider variable passthrough check exited $RC"
fi

# 3. Production profile keeps the host network. This is the documented boundary.
if [ -x /usr/bin/curl ] || [ -x /bin/curl ]; then
  set +e
  CODE="$(run_job "iso-net-$$" /usr/bin/curl -fsS --max-time 8 -o /dev/null -w "%{http_code}" https://example.com)"
  RC=$?
  set -e
  if [ "$RC" -eq 0 ] && [ "$CODE" = "200" ]; then
    pass "worker profile can reach the public network (example.com)"
  else
    fail "worker profile could not reach example.com (exit $RC code ${CODE:-none})"
  fi
  set +e
  bwrap --unshare-all --die-with-parent --clearenv --setenv PATH /usr/bin:/bin \
    --ro-bind /usr /usr --ro-bind /bin /bin \
    --ro-bind-try /lib /lib --ro-bind-try /lib64 /lib64 \
    --dir /etc --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --ro-bind-try /etc/ssl /etc/ssl \
    --tmpfs /tmp --proc /proc --dev /dev \
    -- /usr/bin/curl -fsS --max-time 5 -o /dev/null https://example.com >/dev/null 2>&1
  RC=$?
  set -e
  if [ "$RC" -ne 0 ]; then
    pass "an empty network namespace cannot reach example.com; the worker profile does not use that mode"
  else
    fail "empty network namespace still reached example.com"
  fi
else
  fail "curl is not installed, so the network boundary was not tested"
fi

# 4. Symlink job directory and unsafe names fail before a command runs.
LINK_TARGET="$PREFIX/work/iso-target-$$"
LINK_JOB="$PREFIX/work/iso-link-$$"
mkdir -p "$LINK_TARGET"
ln -s "$LINK_TARGET" "$LINK_JOB"
CANARY="$OUTSIDE/should-not-run"
rm -f "$CANARY"
set +e
"$ISOLATE" --job "iso-link-$$" -- /bin/sh -c "echo ran > '$CANARY'" >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" -eq 2 ] && [ ! -e "$CANARY" ]; then
  pass "symlink job directory is refused"
else
  fail "symlink job directory was not refused (exit $RC)"
fi
rm -f "$LINK_JOB"
set +e
"$ISOLATE" --job '../escape' -- /bin/true >/dev/null 2>&1
RC=$?
set -e
[ "$RC" -eq 2 ] && pass "path escape job name is refused" || fail "path escape job name exited $RC"

# 5. Sandbox unavailable fails closed and does not run the command.
if command -v unshare >/dev/null 2>&1; then
  CANARY="$OUTSIDE/unavailable-ran"
  rm -f "$CANARY"
  set +e
  UNAVAIL="$(unshare --user --map-root-user --mount bash -c '
    mount --bind /dev/null /usr/bin/bwrap
    if [ -e /usr/local/bin/bwrap ]; then mount --bind /dev/null /usr/local/bin/bwrap; fi
    "$1" --job "$2" -- /bin/sh -c "echo ran > \"$3\""
    echo exit:$?
  ' _ "$ISOLATE" "iso-unavailable-$$" "$CANARY")"
  set -e
  if printf '%s\n' "$UNAVAIL" | grep -q 'exit:2' && [ ! -e "$CANARY" ]; then
    pass "missing bwrap fails closed and does not run the command"
  else
    fail "unavailable sandbox did not fail closed: ${UNAVAIL:-no output}"
  fi
else
  fail "unshare is missing, so the unavailable-sandbox test did not run"
fi

# 6. dsh itself starts inside the jail and stops without a key. No model call.
DSH_BIN="/opt/runtime/node/bin/node"
DSH_JS="/opt/runtime/app/node_modules/@deepseek-ai/dsh/lib/bin.js"
VER_JOB="iso-ver-$$"
set +e
VER="$(run_job "$VER_JOB" "$DSH_BIN" "$DSH_JS" --version)"
RC=$?
set -e
if [ "$RC" -eq 0 ] && [ "$VER" = "0.2.2-rc.1" ]; then
  pass "dsh 0.2.2-rc.1 runs inside the jail"
else
  fail "dsh --version inside the jail returned exit $RC value ${VER:-none}"
fi

NOKEY_JOB="iso-nokey-$$"
mkdir -p "$PREFIX/work/$NOKEY_JOB"
printf '%s\n' 'say hi' > "$PREFIX/work/$NOKEY_JOB/prompt.txt"
env -u OPENCODE_API_KEY -u DEEPSEEK_API_KEY \
  "$ISOLATE" --job "$NOKEY_JOB" -- \
  "$DSH_BIN" "$DSH_JS" --profile headless --permission-mode workspace-write --json - \
  < "$PREFIX/work/$NOKEY_JOB/prompt.txt" > "$PREFIX/work/$NOKEY_JOB/run.jsonl" 2> "$PREFIX/work/$NOKEY_JOB/run.err" || true
if grep -q 'MISSING_CREDENTIAL' "$PREFIX/work/$NOKEY_JOB/run.err"; then
  pass "no-key headless run stops with MISSING_CREDENTIAL"
else
  fail "no-key headless run did not report MISSING_CREDENTIAL"
fi
if grep -q 'canary-value-42\|not-a-real-cloud-secret\|not-a-real-github-token' "$PREFIX/work/$NOKEY_JOB/run.err" "$PREFIX/work/$NOKEY_JOB/run.jsonl"; then
  fail "no-key dsh output contains an unrelated test secret"
else
  pass "no-key dsh output does not contain unrelated test secrets"
fi

rm -rf "$OUTSIDE" "$HOST_TMP" \
  "$PREFIX/work/$JOB_READ" \
  "$PREFIX/work/iso-key-$$" \
  "$PREFIX/work/iso-net-$$" \
  "$LINK_TARGET" \
  "$PREFIX/work/$VER_JOB" \
  "$PREFIX/work/$NOKEY_JOB"
rm -f "$PREFIX/work/iso-link-$$"

if [ "$FAIL" -eq 0 ]; then
  say ""
  say "ISOLATION PASS: filesystem and environment jail held; network stays available; no model call."
  exit 0
fi
say ""
say "ISOLATION FAIL"
exit 1
