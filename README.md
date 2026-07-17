# LaVieKey

<div align="center">

  **Bộ gõ đa ngôn ngữ cá nhân hoá cho macOS**

  [![macOS](https://img.shields.io/badge/macOS-12.0+-green.svg)](https://www.apple.com/macos/)
  [![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
  [![Base](https://img.shields.io/badge/base-xmannv%2Fxkey-lightgrey.svg)](https://github.com/xmannv/xkey)
</div>

---

## 📖 Giới thiệu

**LaVieKey** là bộ gõ cho macOS, được phát triển và tuỳ biến bởi [LaVieNguyenn](https://github.com/LaVieNguyenn) dựa trên mã nguồn mở của [XKey](https://github.com/xmannv/xkey). Hỗ trợ **Tiếng Việt** (Telex/VNI) và **Tiếng Nhật** (romaji → kana), đang mở rộng thêm.

### 💡 Ý tưởng từ đâu?

Dự án bắt đầu từ việc tự viết một bộ gõ riêng (LVKey) bằng InputMethodKit. Quá trình đó cho thấy giới hạn cố hữu của IMKit trên macOS: dùng marked-text thì Enter/⌘A phải bấm hai lần, dùng direct-edit thì vỡ autocomplete của trình duyệt. Cách tiếp cận CGEvent của XKey (bắt phím toàn cục và chèn ký tự trực tiếp) giải quyết được cả hai vấn đề, nên LaVieKey chọn fork XKey làm nền tảng và phát triển tiếp theo nhu cầu sử dụng cá nhân.

### ✨ Tính năng chính

- ⚡ **Swift native** — phản hồi tức thì, tối ưu cho macOS 12.0+
- 🇻🇳 **Tiếng Việt**: Telex / VNI / Simple Telex, kiểm tra chính tả và khôi phục phím tự do
- 🇯🇵 **Tiếng Nhật (giai đoạn 1)**: gõ romaji → hiragana/katakana (`konnichiha` → こんにちは)
- 🌐 **Chuyển ngôn ngữ nhanh**: Tiếng Việt / English / 日本語 ngay trên menu bar
- 🧠 **Smart Switch** — tự nhớ ngôn ngữ gõ theo từng ứng dụng
- 📝 **Macro & Quick Typing** — gõ tắt, mở rộng cụm từ
- 🎨 **Giao diện đổi màu** — 9 màu nhấn + chế độ Sáng/Tối/Theo hệ thống
- 🛠️ **Debug Window** — theo dõi real-time hoạt động của engine
- 🔒 **Chạy hoàn toàn local** — không thu thập dữ liệu, không đồng bộ cloud

> LaVieKey **không có auto-update và iCloud sync** — đây là bản build cá nhân, cập nhật bằng cách build lại từ mã nguồn.

---

## 🚀 Cài đặt

### Cách nhanh nhất — một dòng lệnh (khuyên dùng)

Không cần clone, không cần Xcode, không cần tài khoản Apple. Mở Terminal và chạy:

```bash
curl -fsSL https://raw.githubusercontent.com/LaVieNguyenn/LaVieKey/main/install.sh | bash
```

Lệnh này tải bản mới nhất từ [Releases](https://github.com/LaVieNguyenn/LaVieKey/releases), cài vào `/Applications`, gỡ cờ chặn của macOS và mở app. Sau đó chỉ cần làm 2 bước thủ công (macOS bắt buộc): **cấp quyền Accessibility** và **đặt bàn phím về ABC** — script sẽ mở sẵn trang cài đặt cho bạn.

> Cập nhật lên bản mới: chạy lại đúng lệnh trên.

---

### Cách tự build (dành cho nhà phát triển)

### Yêu cầu

| Thứ cần có | Ghi chú |
|---|---|
| **macOS 12.0** trở lên | Đã test trên macOS 26 (Tahoe) |
| **Xcode 15+** | Cần `xcodebuild`. Cài từ App Store. **Không cần** đăng nhập Apple ID, **không cần** tài khoản Developer. |

> Build mặc định ký **ad-hoc** (`codesign -`) nên hoàn toàn không đụng tới tài khoản Apple. Đánh đổi: chữ ký ad-hoc đổi mỗi lần build, nên **sau mỗi lần cập nhật phải bật lại quyền Accessibility** một lần. (Muốn tránh: đặt biến `LOCAL_SIGN_ID` = SHA-1 của một chứng chỉ Apple Development trước khi chạy script.)

### Các bước

**1. Clone mã nguồn**

```bash
git clone https://github.com/LaVieNguyenn/LaVieKey.git
cd LaVieKey
```

**2. Build**

```bash
ENABLE_CODESIGN=false ENABLE_SPARKLE_SIGN=false ENABLE_DMG=false ./build_release.sh
```

Script sẽ tự động:
- Build universal binary (Intel + Apple Silicon)
- Ký ad-hoc (không cần tài khoản Apple)
- Tạo `Release/LaVieKey.app` (đã nhúng sẵn bộ gõ `LaVieKeyIM.app`)
- Cài bộ gõ vào `~/Library/Input Methods/`

**3. Chép app vào Applications và mở**

```bash
cp -R Release/LaVieKey.app /Applications/
open /Applications/LaVieKey.app
```

**4. Cấp quyền Accessibility** *(bắt buộc — macOS yêu cầu, không thể tự động)*

- Mở **System Settings → Privacy & Security → Accessibility**
- Bật công tắc cho **LaVieKey**
- Nếu đã có mục LaVieKey cũ trong danh sách: xoá đi rồi thêm lại (tránh macOS nhớ chữ ký cũ)

**5. Đặt input source của macOS về `ABC`**

- **System Settings → Keyboard → Input Sources**
- Dùng **ABC** (hoặc U.S.), **không** bật Vietnamese của Apple — nếu bật cả hai sẽ gõ đúp.
- LaVieKey chạy ngầm và tự xử lý tiếng Việt/Nhật trên nền bàn phím ABC.

Xong! Icon LaVieKey (chữ **LV**) xuất hiện trên menu bar.

---

## ⌨️ Sử dụng

### Chuyển ngôn ngữ

- **Menu bar** → bấm icon LaVieKey → mục **"Ngôn ngữ gõ"** → chọn Tiếng Việt / English / 日本語.
- **Phím tắt** `⌘⇧V` (đổi được trong Cài đặt): bật/tắt nhanh tiếng Việt.
- Icon menu bar cho biết chế độ hiện tại: **LV** (Việt) · **E** (Anh) · **あ** (Nhật).

### Gõ tiếng Việt

Kiểu Telex mặc định: `tieengs` → tiếng, `Vieejt` → Việt, `dd` → đ. Đổi kiểu gõ (VNI, Simple Telex) trong **Cài đặt → Tiếng Việt**.

### Gõ tiếng Nhật (romaji → kana)

| Gõ | Ra |
|---|---|
| `konnichiha` | こんにちは |
| `arigatou` | ありがとう |
| `gakkou` | がっこう (phụ âm đôi → っ) |
| `kyou` | きょう |
| `nn` hoặc `n'` | ん |
| `ko-hi-` (katakana) | コーヒー (dấu `-` là trường âm ー) |

Đổi Hiragana ⇄ Katakana và dấu câu Nhật trong **Cài đặt → Tiếng Nhật**. *(Chuyển kana → kanji thuộc giai đoạn 2, chưa có.)*

---

## 🔄 Cập nhật lên bản mới

```bash
cd LaVieKey
git pull
ENABLE_CODESIGN=false ENABLE_SPARKLE_SIGN=false ENABLE_DMG=false ./build_release.sh
cp -R Release/LaVieKey.app /Applications/
```

Quyền Accessibility giữ nguyên qua các lần build (nhờ ký Apple Development), không phải cấp lại.

---

## 🧯 Xử lý sự cố

| Triệu chứng | Cách xử lý |
|---|---|
| **Không gõ được tiếng Việt/Nhật** | Kiểm tra quyền Accessibility (bước 4). Thử tắt/bật lại công tắc LaVieKey. |
| **Gõ ra chữ đúp** (vd `wwindow`) | Đang bật cả Vietnamese IM của Apple. Chuyển input source về **ABC** (bước 5). |
| **Sau khi cập nhật, gõ không ăn nữa** | Chữ ký ad-hoc đổi mỗi bản build → cấp lại quyền Accessibility (xoá LaVieKey khỏi danh sách rồi bật lại). |
| **App không mở được sau khi build** | Chạy `open /Applications/LaVieKey.app` từ Terminal để xem lỗi, hoặc kiểm tra `~/LaVieKey_Debug.log`. |
| **Cửa sổ Cài đặt không lên** | Bấm icon menu bar → "Mở cài đặt". |

---

## 🛠️ Dành cho nhà phát triển

- Mở `LaVieKey.xcodeproj` bằng Xcode để chỉnh sửa/debug.
- Hai target: **LaVieKey** (app chính, chế độ CGEvent) và **LaVieKeyIM** (bộ gõ IMKit, thử nghiệm).
- Chạy test: mở project trong Xcode → `⌘U` (target `LaVieKeyTests`). *(Chạy test qua CLI vướng bước ký test-host với tài khoản cá nhân.)*
- Bản Release đầy đủ (Developer ID + notarize + DMG): xem các cờ `ENABLE_*` ở đầu `build_release.sh` — cần tài khoản Apple Developer trả phí.

---

## 🙏 Ghi công

- [XKey](https://github.com/xmannv/xkey) của **xmannv** — mã nguồn nền tảng của LaVieKey
- [OpenKey](https://github.com/tuyenvm/OpenKey) của **tuyenvm** — tham chiếu logic gõ tiếng Việt
- Từ điển tiếng Việt: [hunspell-vi](https://github.com/xmannv/hunspell-vi)

## 📄 Giấy phép

[MIT](LICENSE) — kế thừa từ dự án gốc XKey.
