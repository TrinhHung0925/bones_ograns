# Giải phẫu 3D (bones_ograns)

Ứng dụng Flutter học giải phẫu người bằng mô hình 3D tương tác: xoay/zoom, chạm để
chọn bộ phận, bật/tắt hệ cơ quan, ẩn/làm mờ/tách riêng, tìm kiếm, phát âm tên và đố vui vị trí.

## Chạy app

```sh
flutter pub get
flutter run
```

Mô hình đã build sẵn trong `assets/anatomy/`, không cần chạy pipeline để chạy app.

## Kiến trúc

```
lib/
  data/            BodySystem (12 hệ), AnatomyRepository (đọc parts.json)
  viewer/          AssetServer (HTTP loopback) + AnatomyViewerController (lệnh/sự kiện)
  features/
    explore/       màn hình chính, bảng hệ cơ quan, thẻ bộ phận, tìm kiếm
    quiz/          QuizSession (logic thuần) + QuizScreen
    about/         ghi nguồn giấy phép
  services/        Pronouncer (flutter_tts)
assets/
  viewer/          trang three.js (index.html, viewer.js, vendor/three r186)
  anatomy/         models/<hệ>.glb (nén meshopt) + parts.json
tools/anatomy_pipeline/   script tạo assets/anatomy từ BodyParts3D
```

- **Render**: three.js chạy trong `webview_flutter`. Flutter phục vụ trang và GLB qua
  `http://127.0.0.1:<port>` (WebView chặn ES module/fetch trên `file://`).
- **Giao tiếp**: Flutter → JS bằng `window.anatomy.call({cmd, args})`, các lệnh chạy tuần tự;
  JS → Flutter qua kênh `Bridge` (`ready`, `systemLoading`, `systemLoaded`, `tap`, `doubleTap`, `error`).
  Muốn đổi engine (Thermion, Unity…) chỉ cần thay phần hiện thực `AnatomyViewerController`.
- **ID bộ phận** = FMA concept id, đồng thời là tên node trong GLB.

## Build lại mô hình

Cần Python 3 và Node 20+. Script tự tải BodyParts3D (~150MB) vào `tools/anatomy_pipeline/raw/`.

```sh
tools/anatomy_pipeline/build.sh
```

- `build_index.py`: phân loại 2.234 element vào 12 hệ theo cây FMA is_a/part_of + luật theo tên.
- `build_glb.mjs`: gộp element theo concept, đổi trục (Z-up mm → Y-up m), weld, giản lược
  (meshoptimizer), tính normal, nén `EXT_meshopt_compression`; ghi mỗi hệ một GLB.

`test/data/anatomy_repository_test.dart` kiểm tra `parts.json` khớp với node trong các GLB.

## Giấy phép dữ liệu

Mô hình: BodyParts3D, (c) The Database Center for Life Science, CC BY-SA 2.1 Japan.
Bản đã chỉnh sửa (giản lược/nén) phải phân phối theo cùng giấy phép và giữ ghi nguồn
(màn hình *Thông tin* trong app). three.js: MIT.
