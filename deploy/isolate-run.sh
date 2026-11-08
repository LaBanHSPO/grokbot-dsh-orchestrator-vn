#!/usr/bin/env bash
# Fail-closed bubblewrap launcher for one scratch job.
# The provider API needs the host network, so this profile uses --unshare-all
# and --share-net. It does not fall back to an unsandboxed command.
# MIT license. Copyright (c) 2026 Diginno. See the repository LICENSE.
set -euo pipefail
umask 077

PREFIX="${DSH_ORCH_PREFIX:-$HOME/.local/dsh-orchestrator}"
PASS_KEY=0
JOB=""

usage() {
  echo "usage: isolate-run.sh --job NAME [--pass-provider-key] -- command..." >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --job)
      [ "$#" -ge 2 ] || usage
      JOB="$2"
      shift 2
      ;;
    --pass-provider-key)
      PASS_KEY=1
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      usage
      ;;
  esac
done
[ -n "$JOB" ] && [ "$#" -ge 1 ] || usage
if ! [[ "$JOB" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
  echo "job name must be one safe path segment" >&2
  exit 2
fi

assert_no_symlink() {
  local abs="$1"
  local cur=""
  local part
  local IFS=/
  for part in $abs; do
    [ -n "$part" ] || continue
    cur="$cur/$part"
    if [ -L "$cur" ]; then
      echo "refusing symlink in path: $cur" >&2
      exit 2
    fi
  done
}

trusted_bwrap() {
  local candidate mode
  for candidate in /usr/bin/bwrap /usr/local/bin/bwrap; do
    [ -e "$candidate" ] || continue
    [ -f "$candidate" ] || continue
    [ ! -L "$candidate" ] || continue
    [ -x "$candidate" ] || continue
    [ "$(stat -c %u "$candidate")" = "0" ] || continue
    mode=$(stat -c %a "$candidate")
    mode=$((8#$mode))
    if [ $((mode & 022)) -ne 0 ]; then
      continue
    fi
    printf '%s\n' "$candidate"
    return 0
  done
  return 1
}

BWRAP="$(trusted_bwrap || true)"
if [ -z "$BWRAP" ]; then
  echo "sandbox unavailable: need a root-owned bwrap at /usr/bin/bwrap or /usr/local/bin/bwrap" >&2
  exit 2
fi

NODE_HOST="$PREFIX/node/bin/node"
APP_HOST="$PREFIX/app"
HOME_HOST="$PREFIX/home"
WORK_ROOT="$PREFIX/work"
[ -x "$NODE_HOST" ] || { echo "private node is missing under $PREFIX" >&2; exit 2; }
[ -d "$APP_HOST/node_modules" ] || { echo "dsh install is missing under $PREFIX" >&2; exit 2; }
[ -d "$HOME_HOST" ] || { echo "dsh home is missing under $PREFIX" >&2; exit 2; }
[ -d /usr ] && [ -d /bin ] || { echo "sandbox unavailable: system /usr or /bin is missing" >&2; exit 2; }
[ -e /etc/resolv.conf ] || { echo "sandbox unavailable: /etc/resolv.conf is missing" >&2; exit 2; }

assert_no_symlink "$PREFIX"
mkdir -p "$WORK_ROOT"
assert_no_symlink "$WORK_ROOT"
JOB_HOST="$WORK_ROOT/$JOB"
if [ -L "$JOB_HOST" ]; then
  echo "refusing symlink job directory" >&2
  exit 2
fi
if [ -e "$JOB_HOST" ] && [ ! -d "$JOB_HOST" ]; then
  echo "job path exists and is not a directory" >&2
  exit 2
fi
mkdir -p "$JOB_HOST"
assert_no_symlink "$JOB_HOST"
REAL_JOB="$(realpath -e "$JOB_HOST")"
REAL_ROOT="$(realpath -e "$WORK_ROOT")"
if [ "$REAL_JOB" != "$REAL_ROOT/$JOB" ]; then
  echo "refusing job path outside the work root" >&2
  exit 2
fi
dir="$REAL_JOB"
while [ "$dir" != "/" ]; do
  if [ -e "$dir/.git" ]; then
    echo "refusing to run inside a git checkout: $dir" >&2
    exit 2
  fi
  dir="$(dirname "$dir")"
done

if [ -x /usr/bin/true ]; then
  PROBE=/usr/bin/true
elif [ -x /bin/true ]; then
  PROBE=/bin/true
else
  echo "sandbox unavailable: true is not installed" >&2
  exit 2
fi

mkdir -p "$PREFIX/tmp"
DNS_FILE="$(mktemp "$PREFIX/tmp/resolv.XXXXXX")"
cleanup() {
  rm -f "$DNS_FILE"
}
trap cleanup EXIT
# Follow a symlink so a private /run does not hide the host resolver file.
cat /etc/resolv.conf > "$DNS_FILE"
chmod 644 "$DNS_FILE"

args=(
  --unshare-all
  --share-net
  --die-with-parent
  --new-session
  --hostname dsh-worker
  --clearenv
  --setenv PATH "/opt/runtime/node/bin:/usr/bin:/bin"
  --setenv HOME /home/worker
  --setenv TMPDIR /tmp
  --setenv DSH_HOME /opt/runtime/dsh-home
  --setenv DSH_TELEMETRY_DISABLED 1
  --setenv DSH_PERMISSION_MODE workspace-write
  --setenv LANG C.UTF-8
  --setenv LC_ALL C.UTF-8
  --ro-bind /usr /usr
  --ro-bind /bin /bin
  --dir /etc
  --ro-bind "$DNS_FILE" /etc/resolv.conf
  --tmpfs /tmp
  --tmpfs /home
  --dir /home/worker
  --tmpfs /run
  --tmpfs /var
  --proc /proc
  --dev /dev
  --ro-bind "$PREFIX/node" /opt/runtime/node
  --ro-bind "$APP_HOST" /opt/runtime/app
  --bind "$HOME_HOST" /opt/runtime/dsh-home
  --bind "$REAL_JOB" /work
  --chdir /work
)

add_ro() {
  if [ -d "$1" ] || [ -f "$1" ]; then
    args+=(--ro-bind "$1" "$2")
  fi
}
add_ro /lib /lib
add_ro /lib64 /lib64
add_ro /sbin /sbin
add_ro /etc/ssl /etc/ssl
add_ro /etc/ca-certificates /etc/ca-certificates
add_ro /etc/nsswitch.conf /etc/nsswitch.conf
add_ro /etc/hosts /etc/hosts
add_ro /etc/passwd /etc/passwd
add_ro /etc/group /etc/group

if [ "$PASS_KEY" -eq 1 ] && [ -n "${OPENCODE_API_KEY-}" ]; then
  args+=(--setenv OPENCODE_API_KEY "$OPENCODE_API_KEY")
fi

if ! "$BWRAP" "${args[@]}" -- /opt/runtime/node/bin/node -e 'process.exit(0)' >/dev/null; then
  echo "sandbox unavailable: bubblewrap or the private runtime failed its probe" >&2
  exit 2
fi
# Confirm the probe binary exists inside the same profile. A missing mount
# must not continue into the real command.
if ! "$BWRAP" "${args[@]}" -- "$PROBE" >/dev/null; then
  echo "sandbox unavailable: bubblewrap could not start a command" >&2
  exit 2
fi

"$BWRAP" "${args[@]}" -- "$@"
exit $?
