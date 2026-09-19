#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_download_index.py — 產生 docs/download/index.html 下載總表。

掃描 <download_dir> 下的各平台子資料夾，列出可下載的建構產物，
並附上檔案大小與 SHA-256。index.html 本身與 .nojekyll / CNAME / README
等輔助檔案會被自動忽略，不會出現在下載清單中。

用法:
    python3 gen_download_index.py <download_dir> <output_index_html> [app_version] [git_commit]

範例:
    python3 tool/gen_download_index.py docs/download docs/download/index.html 1.0.0 abc1234
"""

import hashlib
import html
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

# 不列入下載清單的輔助檔案。
SKIP_FILES = {"index.html", "checksums.sha256", ".nojekyll", "cname", "readme.md"}
BRAND = "#6C5CE7"


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


def collect_platform(download_dir: str, name: str):
    folder = os.path.join(download_dir, name)
    if not os.path.isdir(folder):
        return None
    files = []
    for entry in sorted(os.listdir(folder)):
        full = os.path.join(folder, entry)
        if not os.path.isfile(full):
            continue
        if entry.lower() in SKIP_FILES:
            continue
        files.append((entry, os.path.getsize(full), sha256_of(full)))
    return files


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: gen_download_index.py <download_dir> <output_index_html> [version] [commit]",
              file=sys.stderr)
        return 2

    download_dir = sys.argv[1]
    out_path = sys.argv[2]
    app_version = sys.argv[3] if len(sys.argv) > 3 else "dev"
    git_commit = (sys.argv[4] if len(sys.argv) > 4 else "unknown")[:8]
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

    sections = []
    for name, zh, en in platforms:
        files = collect_platform(download_dir, name)
        if not files:
            continue
        rows = []
        for fname, size, digest in files:
            rows.append(f"""
        <li class="file">
          <a href="{html.escape(name)}/{html.escape(fname)}" download>{html.escape(fname)}</a>
          <span class="meta">{human_size(size)}</span>
          <span class="hash" title="SHA-256">{html.escape(digest[:16])}…</span>
        </li>""")
        sections.append(f"""
    <section class="platform">
      <h2>{html.escape(zh)} <small>{html.escape(en)}</small></h2>
      <ul class="files">{''.join(rows)}
      </ul>
    </section>""")

    if not sections:
        sections.append(
            '<section class="platform"><h2>尚無可用的下載</h2>'
            '<p>建構產物將在本次 CI 完成後出現。</p></section>'
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
  .platform {{ background:#fff;border:1px solid #e7e8f0;border-radius:14px;padding:18px 20px;margin-bottom:18px; }}
  @media (prefers-color-scheme: dark) {{ .platform {{ background:#13151f;border-color:#262a3a; }} }}
  .platform h2 {{ margin:0 0 12px;font-size:19px; }}
  .platform h2 small {{ color:#8a8da0;font-weight:400;font-size:13px;margin-left:6px; }}
  ul.files {{ list-style:none;margin:0;padding:0; }}
  li.file {{ display:flex;flex-wrap:wrap;align-items:center;gap:10px;padding:10px 0;border-top:1px dashed #eceef5; }}
  li.file:first-child {{ border-top:none; }}
  li.file a {{ color:var(--brand);font-weight:600;text-decoration:none;word-break:break-all; }}
  li.file a:hover {{ text-decoration:underline; }}
  .meta {{ margin-left:auto;color:#8a8da0;font-size:13px;white-space:nowrap; }}
  .hash {{ color:#8a8da0;font-size:12px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace; }}
  footer {{ text-align:center;color:#8a8da0;font-size:12px;padding:0 18px 40px; }}
  footer code {{ background:rgba(108,92,231,.1);padding:1px 6px;border-radius:6px; }}
</style>
</head>
<body>
<header>
  <div class="logo">💬</div>
  <h1>NexusChat 下載中心</h1>
  <p>去中心化聊天 · Waku 網路 · 端對端加密</p>
</header>
<main>
  <a class="web-cta" href="../">🌐 直接開啟網頁版（Web App）</a>
{''.join(sections)}
</main>
<footer>
  版本 <code>{html.escape(app_version)}</code> · 建構 <code>{html.escape(git_commit)}</code> · {html.escape(now)}<br>
  所有桌面與行動版本均為 CI 自動建構產物。
</footer>
</body>
</html>
"""
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(html_doc)
    print(f"written: {out_path} ({len(html_doc)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
