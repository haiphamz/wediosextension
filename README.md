# Trình Duyệt Web iOS Hỗ Trợ Chrome Extension (Extension Browser)

Dự án ứng dụng trình duyệt web trên nền tảng **iOS (Swift / SwiftUI + WKWebView)** có khả năng **nạp và thực thi các Extension của máy tính (Chrome / WebExtension)** linh hoạt, tương thích đầy đủ các API `chrome.*`, sử dụng bộ nhận diện thương hiệu và **Logo trích xuất trực tiếp từ tệp zip**.

---

## 🚀 Tính Năng Chính

1. **Khả Năng Nạp Extension Linh Hoạt như Máy Tính:**
   - Hỗ trợ chuẩn **Chrome Extension Manifest V2 và Manifest V3**.
   - Cài đặt trực tiếp extension bằng cách chọn tệp **`.zip`** từ ứng dụng **Tệp (Files / iCloud Drive / On My iPhone)**.
   - Tự động giải nén, phân tích cú pháp `manifest.json`, nhận diện content scripts, css, quyền hạn và giao diện popup.
   - Bật / Tắt từng Extension theo nhu cầu ngay trong danh sách quản lý.

2. **Bộ Cầu Nối Chrome Extension API (WebExtension Bridge) Hoàn Thiện:**
   - **`chrome.storage`** (`local`, `sync`, `session`): Hỗ trợ cả **Callback** và **Promise (async/await)**. Dữ liệu được đồng bộ thời gian thực giữa các tab web, giao diện popup và lưu vĩnh viễn vào `UserDefaults` của iOS.
   - **`chrome.runtime`**: `sendMessage`, `onMessage`, `getURL`, `getManifest`, `id`, `lastError`.
   - **`chrome.tabs`**: `query` (lấy tab đang kích hoạt), `sendMessage` (popup gửi lệnh sang trang web), `create`, `update`.
   - **`chrome.action` / `browserAction`**: Mở popup và tương tác giao diện.
   - Hỗ trợ bí danh **`window.browser`** chuẩn WebExtension.

3. **Cơ Chế Khớp URL Chuẩn Desktop (Chrome Match Patterns):**
   - Hỗ trợ các mẫu pattern như `<all_urls>`, `*://*.soundcloud.com/*`, `https://example.com/*`.
   - Tự động nạp đúng script tương ứng với thời điểm `document_start`, `document_end` hoặc `document_idle`.

4. **Giao Diện Trình Duyệt Tối Giản & Tiện Lợi:**
   - Thanh địa chỉ thông minh: Tự động nhận diện đường link hoặc từ khóa tìm kiếm (Google Search).
   - Nút điều hướng chuẩn: Lùi (Back), Tiến (Forward), Tải lại (Reload).
   - **Desktop / Mobile Mode Switch**: Cho phép chuyển đổi linh hoạt giữa User-Agent máy tính (Mac Safari / Chrome) và User-Agent di động.
   - **Nút Thao Tác Nhanh Extension**: Nút icon của extension hiển thị trực tiếp trên thanh công cụ (giống Chrome trên PC), bấm vào sẽ mở giao diện `popup.html` dạng Sheet/Popover.
   - **Menu Quản lý Extension (Biểu tượng mảnh ghép Puzzle)**: Quản lý danh sách, gỡ cài đặt, nạp file zip mới.

5. **Phát Nhạc Chạy Nền Không Gián Đoạn (Background Audio):**
   - Đã cấu hình `AVAudioSession.Category.playback` và `UIBackgroundModes: ["audio"]` trong `Info.plist`, cho phép nghe nhạc SoundCloud, YouTube, podcast khi khóa màn hình hoặc chuyển sang ứng dụng khác.

6. **Logo & Tài Nguyên Chuẩn:**
   - Sử dụng logo gốc từ tệp zip (`AppIcon60x60@2x.png` và `AppIcon76x76@2x~ipad.png`), đã được giải mã CgBI và sinh đầy đủ bộ `AppIcon.appiconset` (1024x1024, iPad, iPhone, Spotlight, Settings).
   - Tích hợp sẵn bộ Extension **SoundCloud Auto Crossfader & Cue Manager v4.1** làm extension mẫu mặc định.

---

## 📁 Cấu Trúc Dự Án

```
f:\App\scl\
├── ExtensionBrowser\                     # Dự án Xcode hoàn chỉnh
│   ├── ExtensionBrowser.xcodeproj/       # File cấu hình Xcode Project
│   └── ExtensionBrowser/
│       ├── App/
│       │   ├── ExtensionBrowserApp.swift # Entry point ứng dụng SwiftUI & AudioSession
│       │   └── Info.plist                # Khai báo cấu hình, quyền hạn & background audio
│       ├── Core/
│       │   ├── WebExtensionModel.swift   # Struct Manifest V2/V3, Extension Model
│       │   ├── MatchPattern.swift        # Thuật toán regex khớp URL (*://*.domain/*)
│       │   ├── ZipExtractor.swift        # Bộ giải nén file zip thuần túy qua zlib
│       │   ├── WebExtensionManager.swift # Quản lý nạp, quét và lưu trữ extension
│       │   └── WebExtensionBridge.swift  # Native WKScriptMessageHandler cho Storage & Runtime
│       ├── Views/
│       │   ├── ContentView.swift         # Giao diện trình duyệt, toolbar, address bar
│       │   ├── BrowserWebView.swift      # Wrapper WKWebView với Desktop UA & script injection
│       │   ├── ExtensionManagerView.swift# Danh sách quản lý extension & document picker
│       │   └── ExtensionPopupView.swift  # WKWebView hiển thị popup.html của extension
│       └── Resources/
│           ├── Assets.xcassets/          # Bộ icon đầy đủ từ logo tệp zip
│           ├── Scripts/                  # extension_bridge.js (Chrome API shim)
│           └── DefaultExtensions/        # Extension SoundCloud Crossfader tích hợp sẵn
│               └── soundcloud_cue/
├── SoundCloudBrowser.ipa                 # File .ipa đã cập nhật để cài trực tiếp
├── SoundCloudCrossfader_Extension.zip    # Tệp zip extension mẫu dùng để test nạp extension
└── source_extension/                     # Mã nguồn extension & script bridge
```

---

## 🛠 Hướng Dẫn Sử Dụng

### Cách 1: Mở và Biên Dịch Bằng Xcode (Khuyến nghị cho lập trình viên)
1. Mở thư mục `ExtensionBrowser/ExtensionBrowser.xcodeproj` trên macOS bằng **Xcode 15+**.
2. Chọn thiết bị đích (iPhone / iPad Simulator hoặc thiết bị thật kết nối cáp).
3. Bấm **Cmd + R** để chạy ứng dụng.

### Cách 2: Cài Đặt File `.ipa` Trực Tiếp Lên iPhone / iPad
1. Sử dụng các công cụ sideload phổ biến:
   - **TrollStore** (cho thiết bị hỗ trợ).
   - **AltStore** / **SideStore**.
   - **Sideloadly** trên máy tính Windows/Mac.
   - **Scarlet** / **Esig**.
2. Chọn tệp [SoundCloudBrowser.ipa](file:///f:/App/scl/SoundCloudBrowser.ipa) để cài đặt.
3. Khi mở ứng dụng, extension SoundCloud Auto Crossfader v4.1 đã được nạp sẵn.

### Cách 3: Thử Nghiệm Nạp Thêm Extension Từ File ZIP
1. Mở ứng dụng trình duyệt.
2. Bấm vào biểu tượng **Mảnh ghép Extension** ở góc trên bên phải.
3. Bấm **"Cài Extension từ file ZIP"**.
4. Chọn tệp [SoundCloudCrossfader_Extension.zip](file:///f:/App/scl/SoundCloudCrossfader_Extension.zip) (hoặc bất kỳ file zip extension Chrome nào khác có `manifest.json`).
5. Extension sẽ xuất hiện ngay lập tức trong danh sách và kích hoạt trên các trang web phù hợp.
