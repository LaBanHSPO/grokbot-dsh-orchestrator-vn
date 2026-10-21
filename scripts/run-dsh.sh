#!/usr/bin/env bash
# Chạy một việc headless bằng DeepSeek Harness (dsh) trong thư mục làm việc riêng.
#
# Dùng:
#   scripts/run-dsh.sh [--pro] <thu-muc-lam-viec> <file-prompt | "prompt">
#
# Ví dụ:
#   scripts/run-dsh.sh /tmp/work/don-hang examples/don-hang/prompt.txt
#   scripts/run-dsh.sh --pro /tmp/work/hop-dong "Đọc hop_dong.md và liệt kê rủi ro"
#
# Kết quả:
#   <thu-muc>/run.jsonl   luồng sự kiện JSON (tool_call, tool_result, final...)
#   <thu-muc>/final.txt   câu trả lời cuối
#   exit code 0 = xong, 1 = lỗi (xem <thu-muc>/run.err)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_DIR="${DSH_PATCH_DIR:-$SCRIPT_DIR/../config/patches}"
MODEL_PATCH=""

if [ "${1:-}" = "--pro" ]; then
  MODEL_PATCH="$PATCH_DIR/pro.patch.yml"
  shift
fi

if [ $# -lt 2 ]; then
  sed -n '2,15p' "$0"
  exit 2
fi

WORKDIR="$1"; shift
PROMPT_ARG="$*"

command -v dsh >/dev/null || { echo "Không tìm thấy dsh. Cài: npm i -g @deepseek-ai/dsh" >&2; exit 2; }
[ -n "${OPENCODE_API_KEY-}" ] || echo "Cảnh báo: chưa có biến OPENCODE_API_KEY trong môi trường." >&2

mkdir -p "$WORKDIR"
if [ -f "$PROMPT_ARG" ]; then
  PROMPT_FILE="$(cd "$(dirname "$PROMPT_ARG")" && pwd)/$(basename "$PROMPT_ARG")"
else
  PROMPT_FILE="$WORKDIR/prompt.txt"
  printf '%s\n' "$PROMPT_ARG" > "$PROMPT_FILE"
fi

cd "$WORKDIR"
ARGS=(--profile headless --json -)
[ -n "$MODEL_PATCH" ] && ARGS=(--patch "$MODEL_PATCH" "${ARGS[@]}")

START=$(date +%s)
set +e
DSH_TELEMETRY_DISABLED=1 dsh "${ARGS[@]}" < "$PROMPT_FILE" > run.jsonl 2> run.err
RC=$?
set -e
END=$(date +%s)

# Lấy câu trả lời cuối từ sự kiện "final"
node -e '
const fs=require("fs");let t="";
for (const l of fs.readFileSync("run.jsonl","utf8").split("\n")) {
  if (!l.trim()) continue;
  try { const e=JSON.parse(l); if (e.type==="final") t=e.text||""; } catch {}
}
fs.writeFileSync("final.txt", t);' || true

echo "dsh xong: exit=$RC, $((END-START))s, thư mục: $WORKDIR" >&2
[ -s final.txt ] && cat final.txt
exit $RC
