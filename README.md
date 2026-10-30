# Triển khai Render

Cách chạy chính: triển khai backend lên Render theo [hướng dẫn](docs/DEPLOY_RENDER.md), sau đó chạy Flutter với URL HTTPS của service. Cách chạy nội bộ trong docs/CHAY_LOCAL.md chỉ dùng khi cần phát triển.

# LuongBaoLoc_2380601272 — ChildGuard

Ứng dụng Flutter Android quản lý hồ sơ điện thoại trẻ em, kế hoạch thời gian số và thỏa thuận tích cực giữa phụ huynh với trẻ.

## Cấu trúc

```text
frontend/       Flutter Android (Dart); không dùng React Native/Expo
backend/        Node.js / Express REST API, PostgreSQL
docs/           Báo cáo công nghệ, triển khai, API và kịch bản kiểm thử
render.yaml     Blueprint triển khai backend + PostgreSQL
```

## Bắt đầu

1. Backend hiện dùng `https://luongbaoloc-2380601272-api-th10.onrender.com` (health check: `/health`).
2. Cài Flutter stable (Dart >=3.8), Android SDK, JDK 17 trở lên. Kết nối điện thoại Android, bật USB debugging.
3. Chạy các lệnh sau từ thư mục gốc của repository:

```powershell
Set-Location frontend
flutter pub get
flutter run
```

Build APK dùng để cả nhóm cài:

```powershell
Set-Location frontend
flutter build apk --debug
```

APK tại `frontend/build/app/outputs/flutter-apk/app-debug.apk`. Bản debug phục vụ học tập; phát hành chính thức cần keystore riêng. Không sửa API về localhost. Ứng dụng từ chối chạy API khi thiếu URL HTTPS.

## Bật đăng nhập Google

Để nút “Tiếp tục với Google” hoạt động:

1. Trong Google Cloud Console, tạo OAuth Client ID loại **Web application**.
2. Thêm Authorized redirect URI: `https://luongbaoloc-2380601272-api-th10.onrender.com/auth/google/callback`.
3. Trong Render, mở service API → **Environment**, đặt `GOOGLE_CLIENT_ID` và `GOOGLE_CLIENT_SECRET` theo OAuth client vừa tạo. Không đưa client secret vào ứng dụng Flutter, Git hoặc chat.
4. Lưu thay đổi và đợi Render deploy lại service. `PUBLIC_URL` được khai báo sẵn trong `render.yaml`; sau khi cập nhật Blueprint, kiểm tra giá trị này trong Environment phải khớp URL API.
5. Nếu ứng dụng OAuth đang ở chế độ Testing, thêm tài khoản Google cần đăng nhập vào danh sách Test users trong Google Cloud Console.

## Vai trò và dùng thử

- Đăng ký email mặc định là phụ huynh; xác minh email bằng OTP. Đăng nhập mật khẩu luôn yêu cầu OTP.
- Admin đầu tiên: đặt `BOOTSTRAP_ADMIN_EMAIL` trên Render, đăng ký/xác minh email đó, khởi động lại service rồi đăng nhập lại.
- Admin cấp `staff` cho tài khoản nhân viên hoặc `child` cho tài khoản trẻ trong trang quản trị. Người dùng không tự cấp quyền.
- Phụ huynh tạo hồ sơ trẻ, thêm thiết bị, liên kết email tài khoản trẻ đã xác minh, tạo/duyệt thỏa thuận, gắn NFC và xem check-in.
- Phụ huynh cài khung giờ nhận thưởng NFC theo giờ Việt Nam. Trẻ quét đúng thẻ trong khung giờ được cộng 30 phút vào hạn mức ngày, tối đa một lần mỗi ngày; check-in ngoài khung giờ không được ghi nhận.
- Trẻ đăng nhập sẽ vào không gian trẻ; chỉ thấy hồ sơ được phụ huynh liên kết. Có thể đề xuất thỏa thuận và check-in NFC.
- Nhân viên chỉ xem thống kê tổng hợp, không đọc hồ sơ gia đình.
- Đăng nhập OTP thành công → Tài khoản → Bật mở phiên bằng vân tay. Không lưu mật khẩu; phiên vân tay tối đa 12 giờ và bị xóa khi đăng xuất.

## Phạm vi thực tế

Đã có CRUD hồ sơ trẻ và thiết bị; thỏa thuận, quyền truy cập theo gia đình, OTP và OAuth phía backend; tích hợp vân tay/NFC thật qua plugin Flutter. Thưởng NFC cập nhật hạn mức kế hoạch trong ngày nhưng chưa có agent Android trên điện thoại trẻ để đo thời gian sử dụng/chặn ứng dụng hay khóa máy từ xa. Giới hạn là **kế hoạch được lưu**, không hiển thị số liệu sử dụng giả. Thiết bị là hồ sơ, chưa chứng minh ghép nối với phần cứng. NFC check-in không chứng minh vị trí hoặc chống sao chép thẻ.

Chỉ thực hiện vân tay và NFC theo yêu cầu; không QR/Barcode, khuôn mặt, GPS, video, cảm biến hay dịch thời gian thực. Hai khả năng này nằm trong mục e; cần xác nhận tiêu chí “3 trong 6” với giảng viên.

Xem [báo cáo](docs/BAO_CAO.md), [API](docs/API.md), [kịch bản kiểm thử](docs/TEST_PLAN.md).
