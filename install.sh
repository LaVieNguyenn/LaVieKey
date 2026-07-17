#!/bin/bash
#
# LaVieKey — trình cài một dòng lệnh.
#
#   curl -fsSL https://raw.githubusercontent.com/LaVieNguyenn/LaVieKey/main/install.sh | bash
#
# Tải bản .app mới nhất từ GitHub Releases, cài vào /Applications, gỡ cờ
# quarantine (khỏi phải chuột phải → Open), rồi mở app + trang cấp quyền.
# Không cần clone, không cần Xcode, không cần tài khoản Apple.

set -euo pipefail

APP_NAME="LaVieKey"
REPO="LaVieNguyenn/LaVieKey"
ASSET_URL="https://github.com/${REPO}/releases/latest/download/${APP_NAME}.zip"
INSTALL_DIR="/Applications"

echo "==> LaVieKey installer"

# macOS check
if [ "$(uname)" != "Darwin" ]; then
    echo "❌ Chỉ chạy trên macOS." >&2
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "📥 Đang tải ${APP_NAME} (bản mới nhất)..."
if ! curl -fL --progress-bar "$ASSET_URL" -o "$TMP/${APP_NAME}.zip"; then
    echo "❌ Tải thất bại. Kiểm tra mạng, hoặc xem repo đã có Release chưa:" >&2
    echo "   https://github.com/${REPO}/releases" >&2
    exit 1
fi

echo "📦 Giải nén..."
ditto -x -k "$TMP/${APP_NAME}.zip" "$TMP/extracted"

# Tìm .app (phòng khi zip có thư mục con)
APP_PATH="$(find "$TMP/extracted" -maxdepth 2 -name "${APP_NAME}.app" -type d | head -1)"
if [ -z "$APP_PATH" ]; then
    echo "❌ Không tìm thấy ${APP_NAME}.app trong gói tải về." >&2
    exit 1
fi

# Đóng phiên bản đang chạy (nếu có) để ghi đè an toàn
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "🔄 Đóng phiên bản đang chạy..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
fi

echo "📲 Cài vào ${INSTALL_DIR}/${APP_NAME}.app ..."
rm -rf "${INSTALL_DIR:?}/${APP_NAME}.app"
cp -R "$APP_PATH" "${INSTALL_DIR}/"

# Gỡ cờ quarantine → Gatekeeper không chặn, khỏi "chuột phải → Open"
echo "🔓 Gỡ cờ quarantine..."
xattr -dr com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

echo "🚀 Mở ${APP_NAME}..."
open "${INSTALL_DIR}/${APP_NAME}.app"

# Mở sẵn trang cấp quyền Accessibility (macOS bắt buộc thao tác tay)
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

cat <<'DONE'

✅ Đã cài xong LaVieKey!

Còn 2 bước THỦ CÔNG (macOS bắt buộc vì lý do bảo mật — không script nào làm thay được):

  1. Cấp quyền Accessibility
     Cửa sổ System Settings vừa mở → bật công tắc cho "LaVieKey".

  2. Đặt bàn phím macOS về "ABC"
     System Settings → Keyboard → Input Sources → dùng ABC (không bật Vietnamese
     của Apple, tránh gõ đúp).

Chuyển ngôn ngữ: bấm icon LaVieKey trên menu bar → LV (Việt) / E (Anh) / あ (Nhật).
DONE
