# LaVieKey

<div align="center">

  **Bộ gõ tiếng Việt cá nhân hoá cho macOS**

  [![macOS](https://img.shields.io/badge/macOS-12.0+-green.svg)](https://www.apple.com/macos/)
  [![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
  [![Base](https://img.shields.io/badge/base-xmannv%2Fxkey-lightgrey.svg)](https://github.com/xmannv/xkey)
</div>

---

## 📖 Giới thiệu

**LaVieKey** là bộ gõ tiếng Việt cho macOS, được phát triển và tuỳ biến bởi [LaVieNguyenn](https://github.com/LaVieNguyenn) dựa trên mã nguồn mở của [XKey](https://github.com/xmannv/xkey).

### 💡 Ý tưởng từ đâu?

Dự án bắt đầu từ việc tự viết một bộ gõ riêng (LVKey) bằng InputMethodKit. Quá trình đó cho thấy giới hạn cố hữu của IMKit trên macOS: dùng marked-text thì Enter/⌘A phải bấm hai lần, dùng direct-edit thì vỡ autocomplete của trình duyệt. Cách tiếp cận CGEvent của XKey (bắt phím toàn cục và chèn ký tự trực tiếp) giải quyết được cả hai vấn đề, nên LaVieKey chọn fork XKey làm nền tảng và phát triển tiếp theo nhu cầu sử dụng cá nhân:

- Gõ Telex thuận theo thói quen thực tế (thêm dấu ở cuối từ, hủy telex khi gõ tiếng Anh…)
- Sửa các lỗi gõ trong môi trường đặc thù (Spotlight, ô địa chỉ trình duyệt, terminal…)
- Giao diện và cấu hình gọn theo đúng những gì người dùng cần

### ✨ Tính năng chính

- ⚡ **Swift native** — phản hồi tức thì, tối ưu cho macOS 12.0+
- ⌨️ **Telex / VNI / Simple Telex** với kiểm tra chính tả và khôi phục phím tự do
- 🧠 **Smart Switch** — tự nhớ ngôn ngữ gõ theo từng ứng dụng
- 📝 **Macro & Quick Typing** — gõ tắt, mở rộng cụm từ
- 🛠️ **Debug Window** — theo dõi real-time hoạt động của engine
- 🔒 **Chạy hoàn toàn local** — không thu thập dữ liệu, không đồng bộ cloud
- 🎛️ **Dual Mode** — CGEvent (mặc định) và Input Method Kit (thử nghiệm)

> LaVieKey **không có auto-update và iCloud sync** — đây là bản build cá nhân, cập nhật bằng cách build từ mã nguồn.

---

## 🚀 Cài đặt & Build

Yêu cầu: Xcode 15+, macOS 12.0+.

```bash
git clone https://github.com/LaVieNguyenn/LaVieKey.git
cd LaVieKey

# Build bản dùng cá nhân (ad-hoc sign, không cần tài khoản Developer trả phí)
ENABLE_CODESIGN=false ENABLE_SPARKLE_SIGN=false ENABLE_DMG=false ./build_release.sh
```

Script sẽ tạo `Release/LaVieKey.app` (kèm bộ gõ IMKit nhúng sẵn) và tự cài bộ gõ vào `~/Library/Input Methods/`.

Sau đó:
1. Chép `Release/LaVieKey.app` vào `/Applications` và mở app
2. Cấp quyền **Accessibility** (System Settings → Privacy & Security → Accessibility)
3. Để input source của macOS ở **ABC** (không bật Vietnamese của Apple, tránh gõ đúp)

---

## 🙏 Ghi công

- [XKey](https://github.com/xmannv/xkey) của **xmannv** — mã nguồn nền tảng của LaVieKey
- [OpenKey](https://github.com/tuyenvm/OpenKey) của **tuyenvm** — tham chiếu logic gõ tiếng Việt
- Từ điển tiếng Việt: [hunspell-vi](https://github.com/xmannv/hunspell-vi)

## 📄 Giấy phép

[MIT](LICENSE) — kế thừa từ dự án gốc XKey.
