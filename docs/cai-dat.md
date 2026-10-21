# Cài đặt từng bước trên box của Grok Bot

Box của Grok Bot là một máy Linux dùng chung cho các bot của bạn. Bạn có thể **nhờ Grok Bot làm toàn bộ các bước dưới đây** — chỉ cần dán link file này và nói "cài giúp mình".

## 1. Node.js >= 22.19

`dsh` cần Node `^22.19.0` hoặc `>=24`. Kiểm tra:

```bash
node -v
```

Nếu thấp hơn (ví dụ Debian 13 có sẵn Node 20), nâng toàn máy bằng repo NodeSource:

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
  | sudo tee /etc/apt/sources.list.d/nodesource.list
printf 'Package: nodejs\nPin: origin deb.nodesource.com\nPin-Priority: 1001\n' \
  | sudo tee /etc/apt/preferences.d/nodesource-nodejs
sudo apt-get update
sudo apt-get install -s nodejs   # xem trước: gói nào bị gỡ
sudo apt-get install -y nodejs
node -v                          # v22.x
```

Lưu ý:

- **Đừng `apt remove nodejs`** trước: trên box có gói khác phụ thuộc `nodejs` (ví dụ `novnc` cho màn hình desktop). Cài đè bằng NodeSource giữ nguyên tên gói nên không vỡ phụ thuộc.
- Nếu trước đó có npm riêng ở `/usr/local/bin/npm`, nó sẽ đứng trước `/usr/bin/npm` trong PATH — gỡ đi để chỉ còn một npm.
- `pnpm` qua corepack: nếu `pnpm -v` báo lỗi `EACCES ... corepack/v1`, cài lại pnpm vào cache dùng chung bằng quyền root:
  `sudo env COREPACK_HOME=$COREPACK_HOME corepack install -g pnpm@<phiên-bản>`.

## 2. Cài dsh

```bash
npm i -g @deepseek-ai/dsh
dsh --version
dsh --help
```

## 3. Key OpenCode Go

1. Đăng ký gói **Go** tại OpenCode Console và copy API key (xem https://opencode.ai/docs/go/).
2. Nói với Grok Bot: *"Xin giúp mình secret tên `OPENCODE_API_KEY` cho dsh"*. Bot sẽ gửi yêu cầu để bạn nhập key an toàn; key được đưa vào biến môi trường của box.
3. **Không** dán key vào chat, file config, prompt hay repo.

Kiểm tra (không in giá trị):

```bash
bash -lc '[ -n "$OPENCODE_API_KEY" ] && echo "có key" || echo "chưa có key"'
```

## 4. Config dsh

Thư mục home của dsh mặc định là `~/.dsh` (đổi bằng biến `DSH_HOME`). Chép config:

```bash
mkdir -p ~/.dsh/patches
cp config/cordis.patch.yml.example ~/.dsh/cordis.patch.yml
cp config/patches/*.patch.yml ~/.dsh/patches/
```

Nội dung `~/.dsh/cordis.patch.yml` (áp dụng cho mọi profile):

```yaml
- id: llm-deepseek
  config:
    baseURL: https://opencode.ai/zen/go/v1
    apiKeyEnv: OPENCODE_API_KEY
    thinking: enabled
    reasoningEffort: high
    models:
      - id: deepseek-v4.1-flash
        name: DeepSeek-V4.1-Flash (OpenCode Go)
        contextWindow: 1000000
        systemPromptUpdate: in-history
        toolUpdate: addition-only
      - id: deepseek-v4-pro
        name: DeepSeek-V4-Pro (OpenCode Go)
        contextWindow: 1000000
- id: agent-default-model
  config:
    provider: deepseek-official
    model: deepseek-v4.1-flash
```

Vì sao dùng `cordis.patch.yml` thay cho `settings.yaml`: `settings.yaml` là định dạng cũ, dsh chỉ nhập **một lần** vào profile chạy đầu tiên rồi đổi tên thành `settings.yaml.imported`. File patch ở home áp dụng cho mọi profile và là nơi nên sửa.

Kiểm tra config đã ăn chưa:

```bash
dsh --profile headless --dump-config | grep -A12 "id: llm-deepseek$"
```

## 5. Đổi model theo từng lệnh

Không có cờ `--model`; dùng patch:

```bash
# mặc định: deepseek-v4.1-flash
dsh --profile headless "việc thường"
# việc khó: deepseek-v4-pro
dsh --profile headless --patch ~/.dsh/patches/pro.patch.yml "việc khó"
```

`--patch` phải đứng **trước** nội dung việc.

## 6. Chạy thử

```bash
mkdir -p /tmp/dsh-test && cd /tmp/dsh-test
DSH_TELEMETRY_DISABLED=1 dsh --profile headless "say hi"
echo "exit=$?"
```

Kết quả mong đợi: một câu chào và `exit=0`.

Các dạng chạy hữu ích:

| Mục đích | Lệnh |
|---|---|
| Prompt dài từ file | `dsh --profile headless - < prompt.txt` |
| Log sự kiện cho bot đọc | `dsh --profile headless --json - < prompt.txt > run.jsonl` |
| Nối tiếp phiên | `dsh --profile headless --session-id <id> "sửa lại..."` (chạy từ **cùng thư mục**) |
| Helper của repo | `scripts/run-dsh.sh [--pro] <thư-mục> <prompt>` |

`DSH_TELEMETRY_DISABLED=1` tắt gửi telemetry.

## 7. Xử lý sự cố

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `web_fetch`: *URL hostname resolves to a non-public IP address* | DNS của box trả địa chỉ dải `198.18.x.x`; dsh chặn mọi IP không public và không có tuỳ chọn tắt | Ghi trong prompt: "dùng `curl -L` qua bash, lưu ra file rồi đọc" |
| `web_search`: *no API key for DEEPSEEK_API_KEY* | Search của dsh dùng API DeepSeek chính chủ | Để Grok Bot tự search, đưa kết quả vào file cho dsh |
| `dsh: INVALID_REQUEST: DeepSeek Messages request failed (400)`, exit 1 | Lỗi phía API, thỉnh thoảng gặp ở bước cuối (đã thấy 2/8 lần chạy thử) | Kiểm tra file đầu ra trước — việc thường đã xong. Nối tiếp phiên từ cùng thư mục: `dsh --profile headless --session-id <id> "Tiếp tục và xác nhận kết quả"` (id nằm ở dòng đầu `run.jsonl`); hoặc chạy lại |
| `MISSING_CREDENTIAL` | Chưa có `OPENCODE_API_KEY` trong môi trường | Mở shell mới (`bash -lc`) hoặc nhờ Grok Bot xin lại secret |
| `EROFS: read-only file system` khi tool ghi vào `~/.config/...` | Sandbox mặc định `workspace-write`: chỉ ghi được trong thư mục đang chạy | Bình thường, đây là lớp an toàn. Không bật `DSH_PERMISSION_MODE=danger-full-access` |
| Lỗi *MissingSessionID* từ OpenCode khi tự gọi bằng curl | OpenCode Go bắt buộc header session | dsh tự gửi header riêng, không cần xử lý |
| nvm báo *not compatible with the "NPM_CONFIG_PREFIX" environment variable* | Box đặt sẵn `NPM_CONFIG_PREFIX`, nvm không chạy được | Dùng NodeSource (bước 1) thay cho nvm |
| `dsh: command not found` | Thư mục global bin của npm chưa có trong PATH | `npm prefix -g` để xem, thêm `<prefix>/bin` vào PATH |
