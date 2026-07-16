# 🚀 Quick Setup Guide - Automatic Appcast

## Bước 1: Enable GitHub Pages

1. Vào repository trên GitHub: `https://github.com/xmannv/xkey`
2. Click **Settings** → **Pages** (menu bên trái)
3. Trong phần **Source**:
   - Chọn **Deploy from a branch**
   - Branch: **gh-pages**
   - Folder: **/ (root)**
4. Click **Save**

## Bước 2: Chạy Workflow Lần Đầu

Vì workflow chỉ trigger khi có release mới, bạn cần chạy thủ công lần đầu:

1. Vào **Actions** tab trên GitHub
2. Click workflow **Update Appcast** (bên trái)
3. Click nút **Run workflow** (bên phải)
4. Chọn branch **main**
5. Click **Run workflow** (xanh lá)
6. Đợi ~1-2 phút cho workflow chạy xong

## Bước 3: Verify

Sau khi workflow chạy xong, kiểm tra:

```bash
# Check appcast URL
curl https://xmannv.github.io/xkey/appcast.json
```

Hoặc mở trực tiếp trong browser:
👉 https://xmannv.github.io/xkey/appcast.json

## Bước 4: Test Update trong App

1. Build app mới với `Info.plist` đã update
2. Chạy app
3. Click **Check for Updates** trong menu
4. Sparkle sẽ fetch từ GitHub Pages!

## ✅ Xong!

Từ giờ, mỗi khi bạn tạo GitHub Release mới:
- ✨ Workflow tự động chạy
- 📝 `appcast.json` tự động update
- 🚀 Deploy lên GitHub Pages
- 🎉 User nhận update ngay!

## 🔧 Troubleshooting

### Workflow không chạy?

Kiểm tra:
- Workflow file có đúng path: `.github/workflows/update-appcast.yml`
- Repository có quyền **Actions** enabled (Settings → Actions → General)

### GitHub Pages không hoạt động?

- Đợi 1-2 phút sau khi enable
- Check deployment status: **Actions** tab → **pages build and deployment**
- Verify branch `gh-pages` đã được tạo

### Appcast không có signature?

Script giữ nguyên signature từ file cũ. Để thêm signature cho release mới:

1. Sign DMG: `./sparkle_tools.sh sign Release/LaVieKey.dmg`
2. Copy signature
3. Sau khi workflow chạy, update `appcast.json` trên `gh-pages` branch thủ công (hoặc tích hợp vào build script)

## 📚 Đọc thêm

Xem chi tiết: [APPCAST_AUTO_UPDATE.md](APPCAST_AUTO_UPDATE.md)
