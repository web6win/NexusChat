#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_download_index.py — 產生 docs/download/index.html 下載總表，並匯出
docs/version.json 給 App 內「版本更新」功能比對。

掃描 <download_dir> 下的各平台子資料夾，列出可下載的建構產物，
並附上檔案大小與 SHA-256。index.html 本身與 .nojekyll / CNAME / README
等輔助檔案會被自動忽略，不會出現在下載清單中。

會遞迴走訪子資料夾，因為 CI 上傳 Android 產物時保留了
build/app/outputs/ 的相對結構（flutter-apk/… 與 bundle/release/…）。
不遞迴的話，只有子資料夾、沒有直接子檔案的平台會被整段略過。

每個平台區塊會附一個「掃碼下載」的 QR Code（指向該平台主下載檔的
絕對網址），頁首另有一個指向整個下載中心的大 QR，方便手機直接掃碼。

用法:
    python3 gen_download_index.py <download_dir> <output_index_html> \
        [app_version] [git_commit] [--base-url URL] [--version-out PATH]

範例:
    python3 tool/gen_download_index.py docs/download docs/download/index.html \
        1.0.0+9 abc1234 --base-url https://nchat.web6.win \
        --version-out docs/version.json
"""

import hashlib
import html
import json
import os
import sys
from datetime import datetime, timezone

# 平台顯示順序與名稱（繁體中文為主，附英文）。
PLATFORM_META = [
    ("windows", "Windows", "Windows"),
    ("macos", "macOS", "macOS"),
    ("linux", "Linux", "Linux"),
    ("android", "Android", "Android"),
    ("ios", "iOS", "iPhone / iPad"),
]

# 各平台標題下方的補充說明（沒有對應鍵就不顯示）。
PLATFORM_NOTES = {
    "android": "手機一般下載 flutter-apk/app-release.apk（通用，適用所有機型）；"
               "想縮小體積可改用對應 ABI 的版本，bundle/ 內的 AAB 供 Google Play 上架使用。",
    "ios": "iOS 版本需要簽署憑證才能安裝，僅在倉庫設定簽署 secrets 後才會出現。",
}

# 檔名 → 一句話說明，讓使用者不必猜 ABI 差異。
FILE_LABELS = {
    "app-release.apk": "通用 APK（所有 ABI）",
    "app-arm64-v8a-release.apk": "arm64-v8a（多數現代手機）",
    "app-armeabi-v7a-release.apk": "armeabi-v7a（較舊手機）",
    "app-x86_64-release.apk": "x86_64（模擬器）",
    "app-release.aab": "AAB（Google Play 上架用）",
    "windows-release.zip": "解壓後執行 NexusChat.exe",
    "macos-release.zip": "解壓後開啟 NexusChat.app",
    "linux-bundle.tar.gz": "解壓後執行 nexuschat",
}

# 排序優先序：可安裝的成品在前，上架包在後。
EXTENSION_ORDER = {".apk": 0, ".zip": 0, ".tar.gz": 0, ".ipa": 1, ".aab": 2}

# 不列入下載清單的輔助檔案。
SKIP_FILES = {"index.html", "checksums.sha256", ".nojekyll", "cname", "readme.md"}
BRAND = "#6C5CE7"

# version.json 裡各平台對應的鍵；Android 會額外展開各 ABI 變體。
PLATFORM_JSON_KEY = {
    "windows": "windows",
    "macos": "macos",
    "linux": "linux",
    "android": "android",
    "ios": "ios",
}
# Android 變體檔名 → version.json 鍵。
ANDROID_VARIANT_KEYS = {
    "app-release.apk": "android",
    "app-arm64-v8a-release.apk": "android_arm64_v8a",
    "app-armeabi-v7a-release.apk": "android_armeabi_v7a",
    "app-x86_64-release.apk": "android_x86_64",
    "app-release.aab": "android_aab",
}


def human_size(num: int) -> str:
    units = ["B", "KB", "MB", "GB", "TB"]
    f = float(num)
    for u in units:
        if f < 1024 or u == units[-1]:
            return f"{f:.1f} {u}" if u != "B" else f"{int(f)} B"
        f /= 1024
    return f"{f:.1f} TB"


def sha256_of(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def sort_key(rel_path: str):
    lower = rel_path.lower()
    # .tar.gz 需先於 os.path.splitext 判斷，否則會被當成 .gz。
    if lower.endswith(".tar.gz"):
        rank = 0
    else:
        rank = EXTENSION_ORDER.get(os.path.splitext(lower)[1], 3)
    return (rank, rel_path)


def collect_platform(download_dir: str, name: str):
    """收集某平台資料夾下的所有檔案（含子資料夾）。

    回傳 (相對路徑, 大小, sha256) 清單；相對路徑一律使用 `/` 分隔，
    因為它就是網頁上的連結（例如 flutter-apk/app-release.apk）。
    """
    folder = os.path.join(download_dir, name)
    if not os.path.isdir(folder):
        return None
    files = []
    for root, dirs, names in os.walk(folder):
        # 略過隱藏資料夾（例如 .git），並讓走訪順序穩定。
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for entry in sorted(names):
            if entry.lower() in SKIP_FILES or entry.startswith("."):
                continue
            full = os.path.join(root, entry)
            rel = os.path.relpath(full, folder).replace(os.sep, "/")
            files.append((rel, os.path.getsize(full), sha256_of(full)))
    files.sort(key=lambda item: sort_key(item[0]))
    return files


def abs_url(base: str, rel: str) -> str:
    """把相對路徑補成絕對網址；base 為空則維持相對（QR 無意義但頁面連結仍可用）。"""
    if not base:
        return rel
    return base.rstrip("/") + "/" + rel.lstrip("/")


def primary_url(name: str, files, base: str) -> str:
    """挑一個「主下載檔」的絕對網址，用於 QR 與 version.json。

    Android 偏好通用 app-release.apk；其餘平台取清單第一個。
    """
    if name == "android":
        for rel, _, _ in files:
            if os.path.basename(rel) == "app-release.apk":
                return abs_url(base, f"download/{name}/{rel}")
    if files:
        return abs_url(base, f"download/{name}/{files[0][0]}")
    return abs_url(base, f"download/{name}/")


def build_downloads_map(platforms_files, base: str) -> dict:
    """組出 version.json 的 downloads 對照表。"""
    downloads: dict = {}
    for name, files in platforms_files:
        if not files:
            continue
        downloads[PLATFORM_JSON_KEY.get(name, name)] = primary_url(name, files, base)
        if name == "android":
            for rel, _, _ in files:
                key = ANDROID_VARIANT_KEYS.get(os.path.basename(rel))
                if key:
                    downloads[key] = abs_url(base, f"download/{name}/{rel}")
    return downloads


def render_rows(name: str, files, base: str) -> str:
    rows = []
    for rel, size, digest in files:
        label = FILE_LABELS.get(os.path.basename(rel))
        label_html = (
            f'<span class="label">{html.escape(label)}</span>' if label else ""
        )
        href = f"{html.escape(name)}/{html.escape(rel)}"
        rows.append(f"""
        <li class="file">
          <span class="name"><a href="{href}" download>{html.escape(rel)}</a>{label_html}</span>
          <span class="meta">{human_size(size)}</span>
          <span class="hash" title="SHA-256">{html.escape(digest[:16])}…</span>
        </li>""")
    return "".join(rows)


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: gen_download_index.py <download_dir> <output_index_html> "
              "[version] [commit] [--base-url URL] [--version-out PATH]",
              file=sys.stderr)
        return 2

    download_dir = sys.argv[1]
    out_path = sys.argv[2]
    app_version = "dev"
    git_commit = "unknown"
    base_url = "https://nchat.web6.win"  # 預設自訂網域；可用 --base-url 覆寫。
    version_out = None

    i = 3
    positional = 0
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == "--base-url":
            i += 1
            base_url = sys.argv[i] if i < len(sys.argv) else base_url
        elif arg == "--version-out":
            i += 1
            version_out = sys.argv[i] if i < len(sys.argv) else None
        elif arg.startswith("--"):
            print(f"unknown option: {arg}", file=sys.stderr)
            return 2
        else:
            if positional == 0:
                app_version = arg
            elif positional == 1:
                git_commit = arg
            positional += 1
        i += 1

    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    # 組合平台：已知順序優先，其餘依字母排序補在後方。
    known = [n for n, _, _ in PLATFORM_META]
    present_known = [n for n in known if os.path.isdir(os.path.join(download_dir, n))]
    extras = sorted(
        n for n in os.listdir(download_dir)
        if os.path.isdir(os.path.join(download_dir, n))
        and n not in known
        and n.lower() not in SKIP_FILES
    )
    meta_map = {n: (zh, en) for n, zh, en in PLATFORM_META}

    platforms = []
    for n in present_known + extras:
        zh, en = meta_map.get(n, (n.title(), n.title()))
        platforms.append((n, zh, en))

    platforms_files = []
    sections = []
    for name, zh, en in platforms:
        files = collect_platform(download_dir, name)
        if not files:
            continue
        platforms_files.append((name, files))
        note = PLATFORM_NOTES.get(name)
        note_html = f'\n      <p class="note">{html.escape(note)}</p>' if note else ""
        qr_url = primary_url(name, files, base_url)
        qr_html = (
            f'<div class="qr"><div class="qr-img" data-url="{html.escape(qr_url)}"></div>'
            f'<span class="qr-cap">掃碼下載</span></div>'
        )
        sections.append(f"""
    <section class="platform">
      <div class="platform-head">
        <h2>{html.escape(zh)} <small>{html.escape(en)}</small></h2>
        {qr_html}
      </div>{note_html}
      <ul class="files">{render_rows(name, files, base_url)}
      </ul>
    </section>""")

    if not sections:
        sections.append(
            '<section class="platform"><h2>尚無可用的下載</h2>'
            '<p>建構產物將在本次 CI 完成後出現。</p></section>'
        )

    download_page_url = abs_url(base_url, "download/")
    hero_qr = (
        f'<div class="qr-hero"><div class="qr-img" data-url="{html.escape(download_page_url)}"></div>'
        f'<span class="qr-cap">掃碼開啟下載中心</span></div>'
    )

    html_doc = f"""<!DOCTYPE html>
<html lang="zh-Hant">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>NexusChat · 下載中心</title>
<style>
  :root {{ --brand: {BRAND}; }}
  * {{ box-sizing: border-box; }}
  body {{ margin:0; font-family: system-ui, -apple-system, "Segoe UI", Roboto, "PingFang TC", "Microsoft JhengHei", sans-serif;
         background:#f6f7fb; color:#1b1d29; line-height:1.6; }}
  @media (prefers-color-scheme: dark) {{ body {{ background:#0b0d14; color:#e8e9f0; }} }}
  header {{ padding:48px 20px 28px; text-align:center;
           background:linear-gradient(135deg, #6c5ce7, #8e7bff); color:#fff; }}
  header .logo {{ width:56px;height:56px;border-radius:18px;background:rgba(255,255,255,.18);
           display:inline-flex;align-items:center;justify-content:center;font-size:26px;margin-bottom:10px; }}
  header h1 {{ margin:0;font-size:26px; }}
  header p {{ margin:6px 0 0;opacity:.9; }}
  main {{ max-width:860px;margin:0 auto;padding:28px 18px 64px; }}
  .web-cta {{ display:block;text-align:center;margin:0 0 28px;padding:16px;
           border:1px solid var(--brand);border-radius:14px;color:var(--brand);
           text-decoration:none;font-weight:600;background:rgba(108,92,231,.06); }}
  .qr-hero {{ display:flex;flex-direction:column;align-items:center;gap:8px;margin:22px auto 0; }}
  .platform {{ background:#fff;border:1px solid #e7e8f0;border-radius:14px;padding:18px 20px;margin-bottom:18px; }}
  @media (prefers-color-scheme: dark) {{ .platform {{ background:#13151f;border-color:#262a3a; }} }}
  .platform-head {{ display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap; }}
  .platform h2 {{ margin:0;font-size:19px; }}
  .platform h2 small {{ color:#8a8da0;font-weight:400;font-size:13px;margin-left:6px; }}
  .note {{ margin:8px 0 12px;color:#8a8da0;font-size:12.5px; }}
  ul.files {{ list-style:none;margin:0;padding:0; }}
  li.file {{ display:flex;flex-wrap:wrap;align-items:center;gap:10px;padding:10px 0;border-top:1px dashed #eceef5; }}
  li.file:first-child {{ border-top:none; }}
  .name {{ flex:1 1 260px;min-width:0; }}
  li.file a {{ color:var(--brand);font-weight:600;text-decoration:none;word-break:break-all; }}
  li.file a:hover {{ text-decoration:underline; }}
  .label {{ color:#8a8da0;font-size:12.5px;margin-left:8px; }}
  .meta {{ margin-left:auto;color:#8a8da0;font-size:13px;white-space:nowrap; }}
  .hash {{ color:#8a8da0;font-size:12px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace; }}
  .qr {{ display:flex;flex-direction:column;align-items:center;gap:4px;flex:0 0 auto; }}
  .qr-img {{ width:96px;height:96px;padding:6px;background:#fff;border-radius:10px;
            box-shadow:0 2px 10px rgba(15,23,42,.15); }}
  .qr-cap {{ color:#8a8da0;font-size:11px; }}
  footer {{ text-align:center;color:#8a8da0;font-size:12px;padding:0 18px 40px; }}
  footer code {{ background:rgba(108,92,231,.1);padding:1px 6px;border-radius:6px; }}
</style>
</head>
<body>
<header>
  <div class="logo">💬</div>
  <h1>NexusChat 下載中心</h1>
  <p>去中心化聊天 · Waku 網路 · 端對端加密</p>
  {hero_qr}
</header>
<main>
  <a class="web-cta" href="../">🌐 直接開啟網頁版（Web App）</a>
{''.join(sections)}
</main>
<footer>
  版本 <code>{html.escape(app_version)}</code> · 建構 <code>{html.escape(git_commit)}</code> · {html.escape(now)}<br>
  所有桌面與行動版本均為 CI 自動建構產物。
</footer>
<!-- 用戶端渲染 QR：依 data-url 產生，避免把圖檔提交進倉庫。 -->
<script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
<script>
  document.querySelectorAll('.qr-img').forEach(function (el) {{
    if (window.QRCode) {{
      new QRCode(el, {{ text: el.dataset.url, width: 96, height: 96,
        correctLevel: QRCode.CorrectLevel.M }});
    }}
  }});
</script>
</body>
</html>
"""
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(html_doc)
    print(f"written: {out_path} ({len(html_doc)} bytes)")

    # 匯出 version.json 給 App 內版本更新比對。
    if version_out:
        # app_version 可能是 "1.0.0+9"，拆出 name 與 build_number。
        if "+" in app_version:
            vname, vbuild = app_version.split("+", 1)
        else:
            vname, vbuild = app_version, "0"
        payload = {
            "app_name": "nexuschat",
            "version": vname,
            "build_number": vbuild,
            "package_name": "nexuschat",
            "published_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "download_page": download_page_url,
            "downloads": build_downloads_map(platforms_files, base_url),
        }
        os.makedirs(os.path.dirname(version_out), exist_ok=True)
        with open(version_out, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        print(f"written: {version_out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
