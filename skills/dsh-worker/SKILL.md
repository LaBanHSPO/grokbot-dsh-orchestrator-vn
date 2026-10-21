---
name: dsh-worker
description: >-
  Giao việc rẻ cho DeepSeek Harness (dsh) chạy trên box để tiết kiệm quota Grok
  Bot: xử lý file/data, viết script + test, nháp văn bản tiếng Việt, tóm tắt,
  batch song song. Dùng khi việc không cần browser, không gửi/ghi lên tài khoản
  thật.
---
# dsh-worker: Grok Bot điều phối, dsh thực thi

Grok Bot nhận việc, chia nhỏ, giao từng phần cho `dsh` (DeepSeek Harness) chạy headless trên box, rồi tự kiểm tra kết quả trước khi giao cho người dùng.

## Môi trường (đã cài sẵn trên box)
- Node 22 toàn máy, `dsh` nằm trong PATH (thường là `~/.local/bin/dsh`).
- Model mặc định `deepseek-v4.1-flash` qua OpenCode Go (`https://opencode.ai/zen/go/v1`), key ở env `OPENCODE_API_KEY` (không bao giờ in ra).
- Config chung: `~/.dsh/cordis.patch.yml`. Patch đổi model: `~/.dsh/patches/pro.patch.yml` (deepseek-v4-pro), `~/.dsh/patches/flash.patch.yml`.
- Nếu `dsh` không có: kiểm tra `node -v` >= 22.19 rồi `npm i -g @deepseek-ai/dsh`.

## Nên giao / không nên giao
Nên: xử lý CSV/Excel/log và làm báo cáo; viết script, test, tool nhỏ; nháp tiếng Việt (báo cáo tuần, recap, proposal, JD) để người duyệt; tóm tắt tài liệu/chat đã export ra file; batch nhiều phần song song.
Không: mọi thao tác gửi/ghi/xoá trên Lark, Zalo/lalo, Gmail, Drive, Cloudflare; việc cần browser hay đăng nhập; web search thật; quyết định tiền bạc/khách hàng. Những việc này Grok Bot tự làm.

## Các bước
1. Chia việc thành từng phần độc lập, mỗi phần một thư mục: `mkdir -p /tmp/work/<id>` và chép file đầu vào vào đó.
2. Viết prompt cho dsh: mục tiêu, file đầu vào, file đầu ra mong muốn (tên cụ thể), tiêu chí đạt, và **danh sách lệnh được phép**. Luôn ghi rõ: "Chỉ chạy lệnh đọc; không gửi, ghi, xoá gì lên Lark/Zalo/Gmail/Cloudflare. Không thêm nội dung không có trong dữ liệu." Nếu cần web: "dùng `curl` qua bash" (`web_fetch` bị chặn trên box, `web_search` không có key).
3. Chạy (Flash cho việc thường, Pro cho việc khó):
   ```sh
   cd /tmp/work/<id> && DSH_TELEMETRY_DISABLED=1 dsh --profile headless --json - < prompt.txt > run.jsonl
   # việc khó:
   cd /tmp/work/<id> && DSH_TELEMETRY_DISABLED=1 dsh --profile headless --patch ~/.dsh/patches/pro.patch.yml --json - < prompt.txt > run.jsonl
   ```
   Việc dài thì chạy nền (Shell block_until_ms 0); nhiều phần thì chạy song song, mỗi phần một thư mục.
4. Đọc exit code (0 = xong, 1 = lỗi), câu trả lời cuối trong `run.jsonl` và các file đầu ra.
5. Kiểm tra: tự tính lại vài số liệu, chạy lại test, đọc nháp xem có bịa thêm ý không. Sai thì nối tiếp phiên bằng `--session-id <id>` (phải chạy từ cùng thư mục) với chỉ dẫn sửa, hoặc chuyển sang Pro.
6. Gom kết quả, giao cho người dùng. Bất cứ thứ gì gửi ra ngoài vẫn đi qua bước duyệt/draft bình thường của Grok Bot.

## Lưu ý
- Mặc định sandbox `workspace-write`: chỉ ghi được trong thư mục đang chạy. Không dùng `DSH_PERMISSION_MODE=danger-full-access`.
- Lỗi `INVALID_REQUEST ... (400)` thỉnh thoảng xảy ra ở bước cuối: kiểm tra file đầu ra trước (thường đã xong), rồi nối tiếp bằng `--session-id <id>` (id ở dòng đầu `run.jsonl`) hoặc chạy lại một lần.
- Chi phí tham khảo: khoảng 0,005–0,02 USD mỗi việc với Flash.
- dsh đang ở developer preview, có thể đổi cú pháp; nếu lệnh lỗi, xem `dsh --help`.
