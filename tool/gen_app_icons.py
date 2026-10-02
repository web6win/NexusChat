"""生成 NexusChat 各平台的應用程式圖示（方案 A：Nexus 節點星網）。

構圖意義
--------
中心青色大點是自己的 DID，外圍六個點是網路中的其他節點，連線是訊息路徑；
其中兩個點做成圓角方形，暗示對話氣泡 —— 呼叫「這是個聊天 App」。

為什麼不用 SVG 轉檔
------------------
各平台要的尺寸從 16px 到 1024px，而小尺寸的構圖必須改變：16px 放不下連線，
放大節點才認得出來。直接以幾何參數繪製才能針對尺寸切換構圖，這是單純
把 SVG 縮小做不到的。SVG 源檔仍保留在 design/logo/nexuschat.svg 供編輯。

構圖規則（依尺寸自動切換）
------------------------
- >= 64px  : full      連線 + 六節點 + 中心
- 40~63px  : compact6  去掉連線，節點放大
- < 40px   : compact4  再精簡成中心 + 四個正交點

用法
----
    python tool/gen_app_icons.py

需要 Pillow（pip install Pillow）。CI 不需要執行這個腳本 —— 圖示是簽入
版本庫的產物。
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------- 品牌色票
# 與 lib/core/theme/app_theme.dart 的 AppColors 一致。
BRAND = (0x6C, 0x5C, 0xE7)
BRAND_ALT = (0x8E, 0x7B, 0xFF)
ACCENT = (0x22, 0xD3, 0xEE)
WHITE = (255, 255, 255)

# ------------------------------------------------------------ 幾何（1024 為基準）
CORNER = 228 / 1024  # squircle 圓角
RING = 244 / 1024  # 外圍節點到中心的距離
LINE_W = 26 / 1024  # 連線寬度
LINE_ALPHA = 0.55
CORE_R = 90 / 1024  # 中心節點半徑
DOT_R = 44 / 1024  # 圓形外圍節點半徑
BUBBLE = 84 / 1024  # 氣泡（圓角方）外圍節點邊長
BUBBLE_R = 26 / 1024  # 氣泡圓角

COS30 = math.cos(math.radians(30))  # 六邊形分布的 x 分量

# (x, y, 形狀)：形狀為 'bubble'（對話氣泡）或 'dot'（一般節點）
NODES: list[tuple[float, float, str]] = [
    (0.5, 0.5 - RING, "bubble"),
    (0.5 + RING * COS30, 0.5 - RING * 0.5, "dot"),
    (0.5 + RING * COS30, 0.5 + RING * 0.5, "bubble"),
    (0.5, 0.5 + RING, "dot"),
    (0.5 - RING * COS30, 0.5 + RING * 0.5, "dot"),
    (0.5 - RING * COS30, 0.5 - RING * 0.5, "dot"),
]

# compact4 用的正交四點（對稱、好認）
CROSS = 0.95  # 相對 RING 的距離係數


def _lerp(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(c1, c2))


def _gradient(size: int) -> Image.Image:
    """左上 → 右下的品牌漸層（小圖生成後放大，避免逐像素跑大圖）。"""
    n = 256
    tile = Image.new("RGB", (n, n))
    px = tile.load()
    for y in range(n):
        for x in range(n):
            t = (x + y) / (2 * (n - 1))
            px[x, y] = _lerp(BRAND, BRAND_ALT, t)
    return tile.resize((size, size), Image.BICUBIC)


def _style_for(size: int) -> str:
    if size >= 64:
        return "full"
    if size >= 40:
        return "compact6"
    return "compact4"


def _params(style: str):
    """依構圖樣式回傳 (是否畫連線, 節點半徑, 氣泡邊長, 中心半徑, 節點列表)。"""
    if style == "full":
        return True, DOT_R, BUBBLE, CORE_R, NODES
    if style == "compact6":
        # 去掉連線，節點放大填補空隙。
        return False, DOT_R * 1.28, BUBBLE * 1.22, CORE_R * 1.12, NODES
    # compact4：只留中心與四個正交點，點更大。
    r = RING * CROSS
    return (
        False,
        DOT_R * 1.75,
        BUBBLE,
        CORE_R * 1.5,
        [
            (0.5, 0.5 - r, "dot"),
            (0.5 + r, 0.5, "dot"),
            (0.5, 0.5 + r, "dot"),
            (0.5 - r, 0.5, "dot"),
        ],
    )


def render(
    size: int,
    *,
    rounded: bool = True,
    maskable: bool = False,
    style: str | None = None,
    supersample: int | None = None,
    transparent: bool = False,
    content_scale: float = 1.0,
) -> Image.Image:
    """畫出指定尺寸的圖示。

    - [rounded]       背景是否為 squircle（iOS / Android 由系統裁切，要用滿幅方形）
    - [maskable]      PWA maskable：背景滿幅、圖形縮到 80% 安全區內
    - [style]         覆寫自動選擇的構圖
    - [transparent]   不畫背景（Android 自適應圖示的前景層）
    - [content_scale] 圖形額外縮放
    """
    style = style or _style_for(size)
    # 小尺寸用更高的超取樣倍率换取乾淨的邊緣。
    ss = supersample or (8 if size <= 48 else (6 if size <= 128 else 4))
    s = size * ss

    draw_lines, dot_r, bubble, core_r, nodes = _params(style)

    # 圖形整體縮放（maskable 需要留出安全區）。
    scale = (0.8 if maskable else 1.0) * content_scale

    # ------------------------------------------------------------ 背景
    if transparent:
        bg = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    else:
        bg = _gradient(s).convert("RGBA")
        if rounded and not maskable:
            mask = Image.new("L", (s, s), 0)
            ImageDraw.Draw(mask).rounded_rectangle(
                [0, 0, s - 1, s - 1], radius=CORNER * s, fill=255
            )
            bg.putalpha(mask)

    def place(v: float) -> float:
        """把 0..1 的座標換算成畫布座標，並套用 maskable 的縮放。"""
        return (0.5 + (v - 0.5) * scale) * s

    # ------------------------------------------------------------ 連線
    if draw_lines:
        lines = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        d = ImageDraw.Draw(lines)
        cx, cy = place(0.5), place(0.5)
        for nx, ny, _ in nodes:
            d.line(
                [cx, cy, place(nx), place(ny)],
                fill=WHITE + (255,),
                width=max(1, int(LINE_W * scale * s)),
                joint="curve",
            )
        # 連線是半透明的：畫完再壓 alpha，避免 ImageDraw 直接覆蓋底色。
        # 用查表而不是 lambda —— 大尺寸的像素數很多，逐點呼叫 Python 太慢。
        alpha_lut = [int(i * LINE_ALPHA) for i in range(256)]
        lines.putalpha(lines.split()[3].point(alpha_lut))
        bg = Image.alpha_composite(bg, lines)

    # ------------------------------------------------------------ 外圍節點
    nodes_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(nodes_layer)
    for nx, ny, kind in nodes:
        x, y = place(nx), place(ny)
        if kind == "bubble":
            half = bubble * scale * s / 2
            d.rounded_rectangle(
                [x - half, y - half, x + half, y + half],
                radius=BUBBLE_R * scale * s,
                fill=WHITE + (255,),
            )
        else:
            r = dot_r * scale * s
            d.ellipse([x - r, y - r, x + r, y + r], fill=WHITE + (255,))
    bg = Image.alpha_composite(bg, nodes_layer)

    # ------------------------------------------------------------ 中心
    core = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    r = core_r * scale * s
    ImageDraw.Draw(core).ellipse(
        [place(0.5) - r, place(0.5) - r, place(0.5) + r, place(0.5) + r],
        fill=ACCENT + (255,),
    )
    bg = Image.alpha_composite(bg, core)

    out = bg.resize((size, size), Image.LANCZOS)

    # 滿幅不透明的圖（iOS / macOS / Android 滿版、PWA maskable）不需要 alpha：
    # App Store 明確不接受帶透明通道的圖示，順手去掉也省一點體積。
    solid = (not rounded) or maskable
    if solid and not transparent:
        return out.convert("RGB")
    return out


# --------------------------------------------------------------- 產出清單
ANDROID = [
    ("mipmap-mdpi", 48),
    ("mipmap-hdpi", 72),
    ("mipmap-xhdpi", 96),
    ("mipmap-xxhdpi", 144),
    ("mipmap-xxxhdpi", 192),
]

# iOS：與 AppIcon.appiconset/Contents.json 對應（系統裁圓角，故用滿幅方形）
IOS = [
    "Icon-App-20x20@1x.png",  # 20
    "Icon-App-20x20@2x.png",  # 40
    "Icon-App-20x20@3x.png",  # 60
    "Icon-App-29x29@1x.png",  # 29
    "Icon-App-29x29@2x.png",  # 58
    "Icon-App-29x29@3x.png",  # 87
    "Icon-App-40x40@1x.png",  # 40
    "Icon-App-40x40@2x.png",  # 80
    "Icon-App-40x40@3x.png",  # 120
    "Icon-App-60x60@2x.png",  # 120
    "Icon-App-60x60@3x.png",  # 180
    "Icon-App-76x76@1x.png",  # 76
    "Icon-App-76x76@2x.png",  # 152
    "Icon-App-83.5x83.5@2x.png",  # 167
    "Icon-App-1024x1024@1x.png",  # 1024
]

IOS_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

# macOS：檔名即像素邊長
MACOS = [16, 32, 64, 128, 256, 512, 1024]

# Windows ICO 內嵌尺寸
WINDOWS_ICO = [16, 24, 32, 48, 64, 128, 256]

# Android 自適應圖示的兩份 XML（與前景 PNG 配套，一起由腳本產出以免版本走鐘）。
ADAPTIVE_ICON_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- 自適應圖示（Android 8+）。前景由 tool/gen_app_icons.py 產生，
     背景是品牌漸層；系統可裁成任意形狀都不會切到圖形。 -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""

ADAPTIVE_BACKGROUND_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- 品牌漸層（左上 → 右下），與其他平台的圖示底色一致。 -->
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <gradient
        android:angle="315"
        android:startColor="#6C5CE7"
        android:endColor="#8E7BFF"
        android:type="linear" />
</shape>
"""


def write_text(rel: str, content: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"  {rel}")


def main() -> None:
    written: list[Path] = []

    def emit(rel: str, img: Image.Image) -> None:
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
        written.append(path)
        print(f"  {rel}  ({img.width}x{img.height})")

    # ------------------------------------------------------------ 源圖
    print("design/logo/nexuschat.svg 用的構圖：full")
    master = render(1024, rounded=True)
    emit("design/logo/nexuschat-1024.png", master)

    # ------------------------------------------------------------ Android
    print("Android:")
    for folder, size in ANDROID:
        emit(
            f"android/app/src/main/res/{folder}/ic_launcher.png",
            render(size, rounded=False),
        )

    # Android 自適應圖示（Android 8+）：108dp 畫布上有 72dp 安全區，
    # 前景只放圖形（透明背景），背景交給 drawable 的漸層，這樣啟動器
    # 不論裁成圓形、圓角方形還是水滴形都不會切到圖形。
    for folder, size in ANDROID:
        emit(
            f"android/app/src/main/res/{folder}/ic_launcher_foreground.png",
            render(
                size * 108 // 48,
                rounded=False,
                transparent=True,
                content_scale=1.15,
            ),
        )

    write_text(
        "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml",
        ADAPTIVE_ICON_XML,
    )
    write_text(
        "android/app/src/main/res/drawable/ic_launcher_background.xml",
        ADAPTIVE_BACKGROUND_XML,
    )

    # ------------------------------------------------------------ iOS
    print("iOS:")
    for name in IOS:
        emit(
            f"ios/Runner/Assets.xcassets/AppIcon.appiconset/{name}",
            render(IOS_SIZES[name], rounded=False),
        )

    # ------------------------------------------------------------ macOS
    print("macOS:")
    for size in MACOS:
        emit(
            f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png",
            render(size, rounded=False),
        )

    # ------------------------------------------------------------ Windows
    print("Windows:")
    ico_sizes = [render(s, rounded=True) for s in WINDOWS_ICO]
    ico_path = ROOT / "windows/runner/resources/app_icon.ico"
    ico_path.parent.mkdir(parents=True, exist_ok=True)
    ico_sizes[0].save(ico_path, format="ICO", append_images=ico_sizes[1:])
    written.append(ico_path)
    print(f"  windows/runner/resources/app_icon.ico  ({', '.join(map(str, WINDOWS_ICO))})")

    # ------------------------------------------------------------ Web / PWA
    print("Web:")
    emit("web/favicon.png", render(64, rounded=True))
    emit("web/icons/Icon-192.png", render(192, rounded=False))
    emit("web/icons/Icon-512.png", render(512, rounded=False))
    emit("web/icons/Icon-maskable-192.png", render(192, maskable=True))
    emit("web/icons/Icon-maskable-512.png", render(512, maskable=True))

    print(f"\n完成，共 {len(written)} 個檔案。")


if __name__ == "__main__":
    main()
