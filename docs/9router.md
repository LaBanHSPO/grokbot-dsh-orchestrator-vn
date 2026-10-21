# Tuỳ chọn: chạy dsh qua 9router

> ⚠️ **Chưa kiểm thử.** Trang này ghi lại hướng tích hợp, chưa chạy thật với repo này.

## 9router là gì

[9router](https://github.com/decolua/9router) (https://9router.com, gói npm `9router`, giấy phép MIT) là router AI chạy cục bộ: một endpoint OpenAI-compatible (`http://localhost:20128/v1`) đứng trước 40–60+ nhà cung cấp, tự chuyển từ gói subscription → model rẻ → model miễn phí khi hết hạn mức. Theo README, nó còn hỗ trợ Claude Code và dịch qua lại giữa các định dạng OpenAI/Claude/Gemini.

## Ghép với dsh

Adapter DeepSeek của dsh chỉ nói giao thức **Anthropic Messages** (`/v1/messages`). Hai hướng:

1. **Trỏ thẳng adapter DeepSeek** (nếu 9router phục vụ `/v1/messages`, như khi dùng cho Claude Code):

   ```yaml
   # ~/.dsh/cordis.patch.yml
   - id: llm-deepseek
     config:
       baseURL: http://localhost:20128/v1
       apiKeyEnv: NINEROUTER_API_KEY   # key lấy từ dashboard 9router
   - id: agent-default-model
     config:
       provider: deepseek-official
       model: <tên-model-hoặc-combo-trong-9router>
   ```

2. **Dùng adapter `dsh-llm-pi-ai`** của dsh với giao thức `openai-completions` trỏ tới `http://localhost:20128/v1` (xem README gói `@deepseek-ai/dsh-llm-pi-ai`).

Kiểm tra bằng `dsh --profile headless "say hi"` trước khi giao việc thật.

## Cân nhắc trước khi dùng

- **Điều khoản dịch vụ:** 9router hỗ trợ đăng nhập bằng OAuth/cookie của các gói subscription (Claude Code, Codex, Copilot…). Dùng gói cá nhân qua proxy bên thứ ba **có thể vi phạm điều khoản** của nhà cung cấp và bị khoá tài khoản. Tự đọc ToS từng bên.
- **Bảo mật:** router giữ key/cookie của nhiều tài khoản. Chỉ chạy trên máy bạn kiểm soát, không mở cổng ra Internet.
- **Vận hành:** thêm một dịch vụ cần giữ chạy liên tục. Với khối lượng vừa phải, OpenCode Go (xem [cai-dat.md](cai-dat.md)) đã đủ rẻ và đơn giản hơn.
