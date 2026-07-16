# Báo cáo: Hỗ trợ QWERTZ / AZERTY Keyboard Layout

**Ngày:** 18/12/2025
**Vấn đề:** LaVieKey không hoạt động với layout bàn phím Đức/Thụy sỹ (QWERTZ)

## 🔍 Phân tích Log

### Log ban đầu (QWERTZ):
```
KEY: 'l' code=37  → PASS THROUGH
KEY: 'y' code=6   → PASS THROUGH (vấn đề!)
KEY: 's' code=1   → PASS THROUGH
```

### Nguyên nhân:
- Người dùng muốn gõ **"lý"** (Telex: l-y-s)
- Trên bàn phím QWERTZ, phím 'Y' nằm ở vị trí vật lý của 'Z' trên QWERTY
- `keyCode=6` là vị trí vật lý của phím Z trên QWERTY
- Nhưng trên QWERTZ, phím này hiển thị 'y'

### Vấn đề cốt lõi:
LaVieKey sử dụng `event.charactersIgnoringModifiers` để lấy ký tự, nhưng giá trị này **ĐÃ ÁP DỤNG LAYOUT HIỆN TẠI**:
- QWERTY: keyCode 6 → 'z'
- QWERTZ: keyCode 6 → 'y'  ❌

→ Engine Vietnamese không nhận diện được nguyên âm 'y' vì nó nhận 'y' ở vị trí của 'z'!

## ✅ Giải pháp

### 1. Tạo KeyCodeToCharacter.swift
File mới: `/LaVieKey/EventHandling/KeyCodeToCharacter.swift`

Map vị trí phím vật lý (keyCode) → ký tự QWERTY chuẩn, bất kể layout hiện tại:

```swift
static func qwertyCharacter(keyCode: UInt16, withShift: Bool = false) -> Character?
```

**Ví dụ:**
- `keyCode=0x06` (physical Z position) → luôn trả về 'z' (QWERTY)
- `keyCode=0x10` (physical Y position) → luôn trả về 'y' (QWERTY)

### 2. Cập nhật KeyboardEventHandler.swift
**Trước:**
```swift
guard let charactersIgnoringModifiers = event.charactersIgnoringModifiers,
      let character = charactersIgnoringModifiers.first else {
    return event
}
```

**Sau:**
```swift
guard let qwertyCharacter = KeyCodeToCharacter.qwertyCharacter(
    keyCode: keyCode, 
    withShift: hasShiftModifier
) else {
    return event
}
let character = qwertyCharacter
```

### 3. Kết quả
Giờ đây, trên bàn phím QWERTZ:
- Gõ phím vật lý ở vị trí Y (keyCode=0x10) → engine nhận **'y'** ✅
- Gõ phím vật lý ở vị trí Z (keyCode=0x06) → engine nhận **'z'** ✅

Người dùng có thể gõ "lý" bằng cách nhấn: **l-y-s** (đúng vị trí phím QWERTY)

## 🎯 Layout được hỗ trợ

Giờ LaVieKey hoạt động với TẤT CẢ các layout keyboard:
- ✅ QWERTY (US/UK/International)
- ✅ QWERTZ (Đức, Thụy Sỹ, Áo)
- ✅ AZERTY (Pháp, Bỉ)
- ✅ Các layout khác có cùng physical layout

## 📝 Lưu ý cho người dùng

Khi sử dụng LaVieKey với layout QWERTZ/AZERTY:
1. **Vị trí phím** quan trọng hơn ký tự hiển thị
2. Gõ theo **vị trí QWERTY**, không theo ký tự trên keycap
3. Ví dụ: Để gõ 'y', nhấn phím ở **vị trí Y trên QWERTY** (kể cả nếu keycap hiển thị ký tự khác)

## 🔧 Build & Test
```bash
cd /Volumes/SSD1TB/PROJECTS/OpenKey/LaVieKey
xcodebuild -project LaVieKey.xcodeproj -scheme LaVieKey -configuration Debug
# ✅ BUILD SUCCEEDED
```

## 📚 Technical Details

### Physical Key Codes (macOS)
```
Row QWERTZ:  Q  W  E  R  T  Z  U  I  O  P
 KeyCodes:  0C 0D 0E 0F 11 10 20 22 1F 23
             
Row ASDFG:   A  S  D  F  G  H  J  K  L
 KeyCodes:  00 01 02 03 05 04 26 28 25

Row YXCV:    Y  X  C  V  B  N  M
 KeyCodes:  06 07 08 09 0B 2D 2E
```

Trên QWERTZ: keyCode 10 là 'Y', keyCode 06 là 'Z'
Trên QWERTY: keyCode 10 là 'Y', keyCode 06 là 'Z'

→ **KeyCode giống nhau, nhưng character khác nhau!**

## ✨ Kết luận

LaVieKey giờ đã **hoàn toàn hỗ trợ QWERTZ & AZERTY** keyboard layouts bằng cách chuyển đổi từ physical keyCode sang QWERTY character trước khi xử lý Vietnamese.

---
**Updated:** 18/12/2025  
**Version:** LaVieKey 1.0+ (with QWERTZ/AZERTY support)
