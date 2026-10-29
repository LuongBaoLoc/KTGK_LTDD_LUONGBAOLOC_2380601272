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

1. Triển khai backend theo [hướng dẫn Render](docs/DEPLOY_RENDER.md).
2. Lấy URL HTTPS thật của service. Không điền URL minh họa vào bản nộp.
3. Cài Flutter stable (Dart >=3.8), Android SDK, JDK 17 trở lên. Kết nối điện thoại Android, bật USB debugging.
4. Trong `frontend`:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://TEN-SERVICE-THAT.onrender.com
```

Build APK dùng để cả nhóm cài:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://TEN-SERVICE-THAT.onrender.com
```

APK tại `frontend/build/app/outputs/flutter-apk/app-debug.apk`. Bản debug phục vụ học tập; phát hành chính thức cần keystore riêng. Không sửa API về localhost. Ứng dụng từ chối chạy API khi thiếu URL HTTPS.

## Vai trò và dùng thử

- Đăng ký email mặc định là phụ huynh; xác minh email bằng OTP. Đăng nhập mật khẩu luôn yêu cầu OTP.
- Admin đầu tiên: đặt `BOOTSTRAP_ADMIN_EMAIL` trên Render, đăng ký/xác minh email đó, khởi động lại service rồi đăng nhập lại.
- Admin cấp `staff` cho tài khoản nhân viên hoặc `child` cho tài khoản trẻ trong trang quản trị. Người dùng không tự cấp quyền.
- Phụ huynh tạo hồ sơ trẻ, thêm thiết bị, liên kết email tài khoản trẻ đã xác minh, tạo/duyệt thỏa thuận, gắn NFC và xem check-in.
- Trẻ đăng nhập sẽ vào không gian trẻ; chỉ thấy hồ sơ được phụ huynh liên kết. Có thể đề xuất thỏa thuận và check-in NFC.
- Nhân viên chỉ xem thống kê tổng hợp, không đọc hồ sơ gia đình.
- Đăng nhập OTP thành công → Tài khoản → Bật mở phiên bằng vân tay. Không lưu mật khẩu; phiên vân tay tối đa 12 giờ và bị xóa khi đăng xuất.

## Phạm vi thực tế

Đã có CRUD hồ sơ trẻ và thiết bị; thỏa thuận, quyền truy cập theo gia đình, OTP và OAuth phía backend; tích hợp vân tay/NFC thật qua plugin Flutter. Chưa có agent Android trên điện thoại trẻ để đo thời gian sử dụng/chặn ứng dụng hay khóa máy từ xa. Giới hạn là **kế hoạch được lưu**, không hiển thị số liệu sử dụng giả. Thiết bị là hồ sơ, chưa chứng minh ghép nối với phần cứng. NFC check-in không chứng minh vị trí hoặc chống sao chép thẻ.

Chỉ thực hiện vân tay và NFC theo yêu cầu; không QR/Barcode, khuôn mặt, GPS, video, cảm biến hay dịch thời gian thực. Hai khả năng này nằm trong mục e; cần xác nhận tiêu chí “3 trong 6” với giảng viên.

Xem [báo cáo](docs/BAO_CAO.md), [API](docs/API.md), [kịch bản kiểm thử](docs/TEST_PLAN.md).
