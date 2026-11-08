#!/usr/bin/env bash
# Private install of Node.js 24.22.2 and @deepseek-ai/dsh@0.2.2-rc.1.
# Writes only under $DSH_ORCH_PREFIX (default: $HOME/.local/dsh-orchestrator).
# Does not use sudo, apt, nvm, or a system-wide npm install.
# MIT license. Copyright (c) 2026 Diginno. See the repository LICENSE.
set -euo pipefail
umask 077

PREFIX="${DSH_ORCH_PREFIX:-$HOME/.local/dsh-orchestrator}"
NODE_VERSION="24.22.2"
DSH_VERSION="0.2.2-rc.1"
DSH_INTEGRITY="sha512-ijR9UEVYkG15Q/Q79JzvzLBzQOQfc63VLr9n6flpwHPhr5IKn2UxthnSoto/P9l7qGd7pPvI1Ra6TW7LH3oKpg=="
LANDLOCK_VERSION="0.1.2"

if [ "$(uname -s)" != "Linux" ]; then
  echo "This installer supports Linux only." >&2
  exit 2
fi
case "$(uname -m)" in
  x86_64)
    NODE_ARCH="linux-x64"
    NODE_SHA="48cc0e21e048790e54c0cf5749c2725005313d652651c40b7a21feb9697aaf75"
    LANDLOCK_PKG="@deepseek-ai/node-addon-system-linux-x64"
    LANDLOCK_INTEGRITY="sha512-S2aPVHvYCpNCppCFyNlooMYuTB7ucK5lvD9oXQQ42v5Z2s5AoaiCdjz9r2l+ED2rI5oS1x0cUZmKjJH2dxV0pg=="
    ;;
  aarch64)
    NODE_ARCH="linux-arm64"
    NODE_SHA="eb187837a2230d4047161ac0be008584e16b46f726e9c9490ee35dc6b17d9ba8"
    LANDLOCK_PKG="@deepseek-ai/node-addon-system-linux-arm64"
    LANDLOCK_INTEGRITY="sha512-Z/DQtqgEYzjBzb2ocHGjMzx51W7xDILkJKKj89nyErr8gZMNiLs+JNL1uKzJqc3VLZB+vYCPaHGyQ3oX6EzEmA=="
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 2
    ;;
esac

if [ "$(id -u)" -eq 0 ] && [ "${DSH_ORCH_ALLOW_ROOT:-}" != "1" ]; then
  echo "Refusing to run as root. Run as the bot user so other apps stay untouched." >&2
  exit 2
fi
case "$PREFIX" in
  "$HOME"/*) ;;
  *)
    echo "Refusing prefix outside the home directory: $PREFIX" >&2
    exit 2
    ;;
esac

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE_DIR="$PREFIX/node"
APP_DIR="$PREFIX/app"
HOME_DIR="$PREFIX/home"
WORK_DIR="$PREFIX/work"
BIN_DIR="$PREFIX/bin"
mkdir -p "$NODE_DIR" "$APP_DIR" "$HOME_DIR/patches" "$WORK_DIR" "$BIN_DIR"

install_node() {
  local current=""
  if [ -x "$NODE_DIR/bin/node" ]; then
    current="$("$NODE_DIR/bin/node" -v || true)"
  fi
  if [ "$current" = "v$NODE_VERSION" ]; then
    return 0
  fi
  local url="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-$NODE_ARCH.tar.xz"
  local tmp
  tmp="$(mktemp)"
  curl -fsSL "$url" -o "$tmp"
  echo "$NODE_SHA  $tmp" | sha256sum -c -
  tar -xJf "$tmp" -C "$NODE_DIR" --strip-components=1
  rm -f "$tmp"
  [ "$("$NODE_DIR/bin/node" -v)" = "v$NODE_VERSION" ]
}

install_dsh() {
  export PATH="$NODE_DIR/bin:$PATH"
  export NPM_CONFIG_IGNORE_SCRIPTS=true
  export npm_config_ignore_scripts=true
  export npm_config_cache="$PREFIX/npm-cache"
  export NPM_CONFIG_UPDATE_NOTIFIER=false
  cat > "$APP_DIR/package.json" <<EOF
{
  "name": "dsh-orchestrator-prefix",
  "private": true,
  "description": "Pinned private install. No secrets.",
  "dependencies": {
    "@deepseek-ai/dsh": "$DSH_VERSION",
    "$LANDLOCK_PKG": "$LANDLOCK_VERSION"
  }
}
EOF
  (
    cd "$APP_DIR"
    npm install --ignore-scripts --engine-strict --no-audit --no-fund --package-lock
  )
  "$NODE_DIR/bin/node" - "$APP_DIR/package-lock.json" "$DSH_INTEGRITY" "$LANDLOCK_PKG" "$LANDLOCK_INTEGRITY" <<'JS'
const fs = require("fs");
const lockPath = process.argv[2];
const dshIntegrity = process.argv[3];
const landlockName = process.argv[4];
const landlockIntegrity = process.argv[5];
const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
const packages = lock.packages || {};
function find(name) {
  return Object.entries(packages).find(([key, value]) => {
    return value && value.version && (key === `node_modules/${name}` || key.endsWith(`/node_modules/${name}`));
  });
}
const dsh = find("@deepseek-ai/dsh");
if (!dsh || dsh[1].version !== "0.2.2-rc.1" || dsh[1].integrity !== dshIntegrity) {
  console.error("dsh integrity check failed");
  process.exit(1);
}
if (!String(dsh[1].resolved || "").startsWith("https://registry.npmjs.org/")) {
  console.error("dsh did not resolve from registry.npmjs.org");
  process.exit(1);
}
const landlock = find(landlockName);
if (!landlock || landlock[1].version !== "0.1.2" || landlock[1].integrity !== landlockIntegrity) {
  console.error("landlock launcher integrity check failed");
  process.exit(1);
}
if (!String(landlock[1].resolved || "").startsWith("https://registry.npmjs.org/")) {
  console.error("landlock launcher did not resolve from registry.npmjs.org");
  process.exit(1);
}
JS
  [ -x "$APP_DIR/node_modules/.bin/dsh" ]
  [ -x "$APP_DIR/node_modules/$LANDLOCK_PKG/bin/landlock-run" ]
}

copy_config() {
  if [ ! -f "$HOME_DIR/cordis.patch.yml" ]; then
    cp "$SOURCE_DIR/config/cordis.patch.yml" "$HOME_DIR/cordis.patch.yml"
  fi
  if [ ! -f "$HOME_DIR/patches/flash.patch.yml" ]; then
    cp "$SOURCE_DIR/config/patches/flash.patch.yml" "$HOME_DIR/patches/flash.patch.yml"
  fi
  if [ ! -f "$HOME_DIR/patches/pro.patch.yml" ]; then
    cp "$SOURCE_DIR/config/patches/pro.patch.yml" "$HOME_DIR/patches/pro.patch.yml"
  fi
  chmod 600 "$HOME_DIR/cordis.patch.yml" "$HOME_DIR/patches/"*.patch.yml
}

link_wrapper() {
  # Copy the wrapper so the installed tree does not depend on this repo path.
  cp "$SOURCE_DIR/run-dsh.sh" "$BIN_DIR/run-dsh.sh"
  cp "$SOURCE_DIR/verify.sh" "$BIN_DIR/verify.sh"
  chmod 700 "$BIN_DIR/run-dsh.sh" "$BIN_DIR/verify.sh"
}

install_node
install_dsh
copy_config
link_wrapper
DSH_ORCH_PREFIX="$PREFIX" "$BIN_DIR/verify.sh"
echo "Installed under $PREFIX"
echo "Live model calls are not part of this installer."
