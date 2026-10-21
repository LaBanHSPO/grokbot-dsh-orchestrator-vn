# Use case cho SME Việt Nam

Mỗi use case gồm: việc gì, Grok Bot làm gì, dsh làm gì, và prompt mẫu cho dsh. Nguyên tắc chung:

- Grok Bot **lấy dữ liệu** (tải file, export từ Lark/Drive/Gmail…) và đặt vào một thư mục riêng, ví dụ `/tmp/work/<id>/`.
- dsh **chỉ làm trong thư mục đó**, xuất file kết quả.
- Grok Bot **kiểm tra lại** (tính lại vài số, đọc nháp) rồi mới gửi đi — sau khi bạn duyệt.

Đuôi nên thêm vào mọi prompt:

```text
Chỉ làm việc trong thư mục hiện tại. Không cài thêm gói. Không gửi, ghi, xoá gì lên Lark/Zalo/Gmail/Drive/Cloudflare.
Không thêm thông tin không có trong dữ liệu; chỗ nào thiếu thì ghi "chưa rõ".
```

---

## 1. Đối soát công nợ khách hàng

**Grok Bot:** export sổ công nợ (Excel → CSV) và sao kê ngân hàng tháng. **dsh:** khớp giao dịch, liệt kê lệch.

```text
Có 2 file: cong_no.csv (ma_kh, ten_kh, so_hoa_don, so_tien, han_tt) và sao_ke.csv (ngay, noi_dung, so_tien).
Viết doi_soat.py: khớp giao dịch sao kê với hoá đơn theo số hoá đơn hoặc tên khách trong nội dung chuyển khoản, sai lệch số tiền ≤ 1.000đ coi là khớp.
Xuất doi_soat.csv (so_hoa_don, ten_kh, so_tien_hd, so_tien_nhan, trang_thai: khop/thieu/thua/chua_tra) và bao_cao.md tiếng Việt: tổng phải thu, đã thu, còn nợ, danh sách quá hạn sắp theo số tiền.
```

## 2. Báo cáo tuần kiểu tin nhắn Lark

**Grok Bot:** gom ghi chú/task tuần (từ Lark Task, chat, file). **dsh:** viết nháp. **Grok Bot:** đưa bạn duyệt rồi mới gửi.

```text
Từ file ghi_chu_tuan.txt, viết báo cáo tuần 43/2026 gửi anh/chị quản lý theo kiểu tin nhắn Lark: tiêu đề, Đã hoàn thành, Đang làm, Vướng mắc & đề xuất, Kế hoạch tuần tới.
Giọng chuyên nghiệp nhưng gần gũi, emoji vừa phải, tối đa 250 từ. Chỉ dùng thông tin có trong ghi chú. Lưu vào bao_cao_tuan.md.
```

## 3. Tóm tắt chat Zalo đã export

**Grok Bot:** export lịch sử nhóm Zalo ra file văn bản. **dsh:** tóm tắt, rút việc cần làm.

```text
File zalo_nhom_kho.txt là lịch sử chat nhóm kho 7 ngày qua (mỗi dòng: thời gian - người gửi: nội dung).
Viết tom_tat.md tiếng Việt: 5–8 ý chính theo chủ đề, danh sách việc cần làm (ai, việc gì, hạn nếu có), các vấn đề lặp lại nhiều lần, câu hỏi chưa ai trả lời.
Không ghi số điện thoại hay thông tin cá nhân vào bản tóm tắt.
```

## 4. Xử lý đơn hàng CSV/Excel

**Grok Bot:** tải file đơn từ sàn/website. **dsh:** làm sạch, tổng hợp. (Xem ví dụ chạy được ở `examples/don-hang/`.)

```text
File don_hang.csv lấy từ sàn TMĐT, có dòng trùng, ngày nhiều định dạng, giá dạng "185k"/"185.000đ".
Viết clean.py: làm sạch, chỉ tính đơn "Đã giao", xuất result.csv (khách, tháng, số đơn, doanh thu) và summary.md: tổng doanh thu, top 5 sản phẩm, top 5 khách, tỉ lệ huỷ theo tháng.
```

## 5. Viết script tích hợp KiotViet / Pancake / n8n

**dsh:** viết code + test với dữ liệu giả. **Grok Bot:** review, gắn key thật và chạy khi bạn đồng ý.

```text
Viết sync_kiotviet.py: đọc danh sách sản phẩm từ file kiotviet_products.json (định dạng giống API KiotViet, đã có mẫu trong thư mục), chuẩn hoá thành products.csv (ma, ten, gia_ban, ton_kho, nhom).
Thêm test_sync.py dùng unittest với dữ liệu mẫu, chạy `python3 -m unittest -v` đến khi pass.
Không gọi API thật; đọc access token từ biến môi trường KIOTVIET_TOKEN nếu cần, không ghi token vào code.
```

Biến thể: "Viết workflow n8n dạng JSON nhận webhook đơn Pancake, lọc đơn > 2 triệu, đẩy sang Google Sheet" — dsh viết file `workflow.json`, bạn tự import vào n8n.

## 6. Nháp proposal / báo giá

```text
Từ brief_khach.md (nhu cầu khách) và bang_gia.md (bảng giá dịch vụ), viết proposal.md tiếng Việt: bối cảnh, mục tiêu, phạm vi công việc, lộ trình 4–6 tuần, báo giá theo hạng mục (chỉ dùng giá trong bang_gia.md), điều khoản thanh toán để trống chờ duyệt.
Đánh dấu [CẦN XÁC NHẬN] ở mọi chỗ phải giả định.
```

## 7. Nháp JD tuyển dụng

```text
Từ yeu_cau.txt (vị trí, kỹ năng, mức lương, địa điểm), viết jd.md tiếng Việt chuẩn đăng tuyển: giới thiệu ngắn công ty (chỉ dùng thông tin trong file), mô tả công việc, yêu cầu bắt buộc / ưu tiên, quyền lợi, cách ứng tuyển.
Kèm bản rút gọn 80 từ để đăng Facebook và 5 câu hỏi sàng lọc.
```

## 8. Batch tóm tắt tài liệu

**Grok Bot:** tải nhiều tài liệu vào các thư mục con, chạy nhiều dsh song song, gom kết quả.

```text
Thư mục docs/ có các file .md/.txt (hợp đồng, biên bản họp, quy trình). Với từng file, viết tóm tắt 5 dòng tiếng Việt vào tom_tat/<tên-file>.md: mục đích, các bên, mốc thời gian, số tiền (nếu có), việc cần làm.
Cuối cùng viết muc_luc.md: bảng tên file – loại tài liệu – một câu tóm tắt.
```

Chạy song song (mỗi phần một thư mục):

```bash
for d in /tmp/work/batch-*; do
  scripts/run-dsh.sh "$d" prompt_tom_tat.txt &
done
wait
```

## 9. Kiểm tra dữ liệu trước khi nhập hệ thống

```text
File khach_hang_moi.csv sắp nhập vào CRM. Kiểm tra: số điện thoại VN hợp lệ (10 số, đầu 03/05/07/08/09), email đúng định dạng, trùng khách theo SĐT/email, tỉnh/thành viết thống nhất.
Xuất loi.csv (dòng, cột, lỗi, gợi ý sửa) và sach.csv chỉ gồm dòng hợp lệ. Không tự sửa dữ liệu gốc.
```

---

**Không nên giao cho dsh:** đăng bài, gửi tin Zalo/Lark/Email, cập nhật CRM/kế toán thật, thao tác cần đăng nhập web, quyết định chi tiền. Những bước đó Grok Bot làm, sau khi bạn duyệt.
