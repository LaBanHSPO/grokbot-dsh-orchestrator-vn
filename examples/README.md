# Ví dụ

## don-hang/

- `don_hang_tho.csv` — 42 dòng đơn hàng **giả** (có dòng trùng, ngày lộn xộn, giá "185k"/"185.000", thiếu số lượng).
- `prompt.txt` — prompt mẫu giao cho dsh.

Chạy:

```bash
mkdir -p /tmp/work/don-hang && cp examples/don-hang/don_hang_tho.csv /tmp/work/don-hang/
scripts/run-dsh.sh /tmp/work/don-hang examples/don-hang/prompt.txt
cat /tmp/work/don-hang/summary.md
```

Sau đó để Grok Bot tự tính lại tổng doanh thu từ CSV và so với `summary.md` trước khi tin kết quả.
