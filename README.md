# NexusChat

> 基於 **Waku** 的去中心化聊天：**DID** 身份、**以太坊**生態、端到端加密。
> 一套 Flutter 程式碼，同時覆蓋 **H5 / 行動端（Android · iOS）/ 桌面端（Windows · macOS · Linux）**。
> 私鑰與助記詞**永不以明文落地**：本地保險庫以你的密碼（PBKDF2 + AES-256-GCM）加密存放。

---

## 一、核心特性

| 面向 | 實作 |
| --- | --- |
| 網路 | Waku v2（relay / store 語義），content topic 分流；可接 **nwaku REST 節點**，也可用**本機模擬**零依賴體驗 |
| 身份 | BIP39 助記詞 → BIP32 派生 → secp256k1 以太坊帳戶 → `did:ethr:0x…`（亦可直接匯入私鑰） |
| 加密 | X25519（一次性金鑰 ↔ 對方靜態金鑰）→ HKDF-SHA256 → **AES-256-GCM** |
| 完整性 | 每則封包附 secp256k1 簽章，接收端回推地址與 DID 比對，杜絕冒用 |
| **金鑰保管** | **本地保險庫**：PBKDF2-HMAC-SHA256（21 萬 / 60 萬次可選）+ AES-256-GCM；靜態零明文 |
| **會話鎖定** | 啟動不自動解鎖、閒置自動鎖（預設 5 分鐘）、手動鎖定立即清空記憶體中的金鑰 |
| 以太坊生態 | 餘額查詢、chain id、**ENS 正反解析**（EIP-137 namehash + registry / resolver 合約呼叫） |
| 錢包 | ETH / **TRON** / **Besu** 三鏈切換（同一把金鑰派生），**已可簽章並送出轉帳**，附區塊瀏覽器連結 |
| 訊息 | 文字、**圖片**（壓縮後傳）、**語音**（錄製 + 波形/播放） |
| 介面 | 響應式三欄（桌面）/ 底部導覽（行動）、Material 3、**日間 / 夜間**主題 |
| 多語 | 繁體中文、简体中文、English、Español（可跟隨系統） |
| 儲存 | Hive（原生走檔案系統，Web 走 IndexedDB），所有資料留在裝置上 |

---

## 二、快速開始

```bash
# 1. 取得依賴
flutter pub get

# 2. H5
flutter run -d chrome          # 或 flutter build web --release

# 3. 桌面（Windows 需先安裝 Visual Studio 2022「使用 C++ 的桌面開發」）
flutter run -d windows
flutter build windows --release

# 4. 行動端
flutter run -d android         # flutter build apk --release
flutter run -d ios             # 需要 Xcode，僅 macOS 可執行

# 5. 測試
flutter test                   # 40 項（保險庫 / 私鑰匯入 / TRON / 端到端加密 / 簽章）
dart run tool/smoke.dart       # 核心邏輯冒煙測試（不依賴 flutter_test）
```

首次啟動會進入引導頁：**建立新身份**（12 個助記詞）或**匯入既有助記詞 / 私鑰**。
建立與匯入流程都會要求**設定一組保險庫密碼**——它是日後解鎖、改密碼、匯出助記詞的唯一憑據。

預設為「本機模擬」傳輸模式，開箱即有 3 位內建示範聯絡人與自動回覆，可直接體驗完整的加密收發流程。

### 2.1 H5 部署與 CSP

`web/index.html` 內建 `Content-Security-Policy`。若自行加上更嚴格的策略，請務必保留：

- `script-src` 需含 `'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' blob:`
  以及 `https://www.gstatic.com/flutter-canvaskit/`（release 版的 CanvasKit 來源，
  **少了它網頁會整片空白**）
- `worker-src` 需含 `blob:`（Flutter web worker）
- `font-src` 需含 `https://fonts.gstatic.com`

頁面另設定 `referrer=no-referrer`，避免把帶 DID 的路徑外洩給第三方資源。
部署時建議由伺服器再補 `X-Frame-Options`、`X-Content-Type-Options` 等標頭。

---

## 三、身份與金鑰安全

### 3.1 威脅模型（先講清楚極限）

- **原生 / 桌面**：密碼解開後的秘密只存在於本程序記憶體，磁碟上沒有明文。
- **Web**：瀏覽器裡沒有可信任的硬體金鑰儲存。凡是「應用能自動解開」的方案，
  能執行腳本的攻擊者就能用同一條路徑解開。因此 Web 端的目標是
  **靜態零明文 + 最短暴露窗口 + 密碼因子不可重放**，而不是聲稱絕對防竊。
- 換句話說：**保險庫防的是「拿走你的資料庫 / 硬碟 / IndexedDB」，
  防不了「在你正在用的頁面裡執行腳本」。** 請只從你信任的網址開啟 H5 版。

### 3.2 保險庫格式

```
password ──PBKDF2-HMAC-SHA256(iterations, salt)──> 32 bytes key
                                                     │
payload(JSON: mnemonic / privateKey …) ──AES-256-GCM─┘──> ct + mac
```

密文以 Map 存放，只有標頭是公開的（它們不是秘密）：

```jsonc
{
  "v": 1,
  "kdf": "pbkdf2-hmac-sha256",
  "iterations": 210000,      // 210000 或 600000，寫入標頭，未來可無痛升級
  "salt": "…", "nonce": "…", // 每次加密獨立隨機
  "ct": "…", "mac": "…"      // AES-256-GCM，16 位元組認證標籤
}
```

- **AAD** 綁定 `nexuschat/vault/v1`，避免別處的密文被移花接木。
- 解密失敗統一回傳 `bad-password`，**不區分「密碼錯」與「密文被竄改」**，避免成為猜測 oracle。
  其餘錯誤碼：`corrupt`（結構毀損）、`unsupported`（版本 / KDF 不認識）。
- **密碼策略**：至少 8 位；純數字、常見弱密碼、重複或連續序列一律拒絕；
  強度標籤 `weak / fair / good / strong`，`score ≥ 2` 才接受。
- 迭代次數取 21 萬是為了讓**純 Dart 實作**（無 WebCrypto 加速）的首次解鎖仍在一秒內；
  想要更高強度可在設定密碼時選 60 萬（OWASP 對 PBKDF2-HMAC-SHA256 的建議值）。

### 3.3 靜態資料的存放方式

| 鍵 | 內容 | 說明 |
| --- | --- | --- |
| `identity_vault` | 保險庫密文 | 助記詞 / 私鑰唯一的落地形式 |
| `identity_hint` | `did`、地址、TRON 地址、加密公鑰 | **公開提示**，未解鎖時也能顯示名片 |
| `identity` | 舊版明文身份 | 僅供升級時遷移，遷移完成即失效 |

### 3.4 會話與鎖定

- `Core.bootstrap()` **不會**自動解鎖；必須 `unlock(password)` 才把金鑰載入記憶體。
- `lock()` 停止 Waku 並清空記憶體中的身份物件。
- **閒置自動鎖**：預設 5 分鐘，可選 1 / 5 / 15 / 30 / 60 分鐘或永不（0）。
- **切到背景立即鎖**：預設關閉（瀏覽器頻繁切分頁會很惱人），要求高者可開啟。
- **匯出助記詞 / 私鑰**：需先通過密碼驗證，顯示後預設 **30 秒自動隱藏**，防肩窺與螢幕錄製殘留。
- **改密碼**：以新密碼重新封裝整包密文，舊密文不再保留。
- **舊版升級**：啟動時偵測到明文身份會導向 `/migrate`，設定密碼後遷入保險庫。

---

## 四、連上真實 Waku 節點

> 聯絡人清單顯示黃色「同步中」＝還沒拿到對方的加密公鑰（key bundle）。
> 在本機模擬模式下訊息只在自己的 app 內打轉，只有真正連上 Waku 網路，
> 且對方也上線發布過金鑰包，狀態才會轉成綠色「已加密」。

### 4.1 一鍵起節點（推薦）

專案內附 `docker/docker-compose.yml`，內含**兩個互相直連的 nwaku 節點**：

```bash
cd docker
bash deploy.sh        # 或 docker compose up -d（deploy.sh 會自動校正 peer ID）
docker compose logs -f nwaku-a nwaku-b
docker compose down
```

為什麼要兩個：gossipsub 在節點沒有任何 peer 時會拒絕發布（`NoPeersToPublish`），
單節點上兩個客戶端是聊不起來的。這裡讓 A、B 互相以 `--staticnode` 直連，
**不依賴外網**，局域網即可跑通完整流程。

> **staticnode 一定要寫 IP，不能寫 `/dns4/` 容器名**：nwaku 的 DNS 解析器在
> Docker 容器內會回傳空陣列（`resolvedAddresses=[]`），用 `/dns4/nwaku-a/...`
> 會靜默撥號失敗。compose 已為兩個節點配置固定 IP（`172.28.0.10` / `172.28.0.11`）。

| 服務 | REST 埠 | 說明 |
| --- | --- | --- |
| `nwaku-a` | `8645` | 給**客戶端一**用（relay + store + filter + lightpush） |
| `nwaku-b` | `8646` | 給**客戶端二**用，與 A 互相轉發、各自保存訊息 |

客戶端填法（設定 → 網路 → Waku 節點（REST））：

- **客戶端一**：`http://<主機IP>:8645`（本機就是 `http://localhost:8645`）
- **客戶端二**：`http://<主機IP>:8646`
- **兩個客戶端都填同一個節點也可以**（例如都填 `8645`）——relay 快取讀走即清空，
  但 store 會持久保存，客戶端兩個來源合併去重，不會互相搶走訊息
- 節點已帶 `--rest-allow-origin=*`，瀏覽器 H5 可直連，無需反代
- 手機實機：把 `<主機IP>` 換成電腦的區域網路 IP

> 注意：兩個節點的私鑰固定寫在 `docker/.env`（僅供開發），所以 peer ID 穩定；
> 正式部署請換成自己的私鑰。若要接公共 Waku 網路，給節點追加有效的
> `--dns-discovery-url`（官方 sandbox fleet 的 DNS 目前已停止解析）或
> `--staticnode` 到任一公共節點即可。

### 4.2 驗證節點

```bash
curl http://127.0.0.1:8645/debug/v1/info    # 節點 A 資訊（含 peer ID）
curl http://127.0.0.1:8646/debug/v1/info    # 節點 B 資訊
curl http://127.0.0.1:8645/health           # Relay 應為 READY（代表有 peer）
```

### 4.3 端到端聊天測試

不需開瀏覽器，直接驗證「金鑰交換 → 加密私訊 → 雙向收發 → 第三方竊聽失敗」：

```bash
# 兩個客戶端各連一個節點
dart run tool/e2e_waku.dart http://10.37.0.110:8645 http://10.37.0.110:8646

# 或兩個客戶端共用同一個節點
dart run tool/e2e_waku.dart http://10.37.0.110:8645 http://10.37.0.110:8645
```

14 項全過才算通；失敗時會印出診斷（看到幾則金鑰包、各自的 `from` DID）。

埠號與鏡像版本可用環境變數覆寫：`REST_A_PORT`、`REST_B_PORT`、`TCP_A_PORT`、
`TCP_B_PORT`、`UDP_A_PORT`、`UDP_B_PORT`、`NWAKU_IMAGE`、`NWAKU_NODEKEY_A/B`
（見 `docker/docker-compose.yml`）。

> NexusChat 走 `/relay/v1/auto/messages`（自動分片，topic 是**路徑段**，且 body 是
> **單一物件不是陣列**）、`GET /store/v3/messages?includeData=true`（拉歷史）。
> 注意 store v3 回傳的每筆是 `{"messageHash":..,"message":{..},"pubsubTopic":..}`
> 包裝結構，真正欄位在 `message` 裡，解析時必須拆開。
> relay 快取**讀走即清空**，store 才持久，所以客戶端兩個來源合併去重。
> 客戶端每 2 分鐘自動重發一次金鑰包，新加的聯絡人也能從 store 補到公鑰。

傳輸層 `WakuTransport` 是抽象介面。日後要換成 JSON-RPC、Filter v2 WebSocket 推播，
或在原生端嵌入 waku 綁定，只需新增一個實作，UI 與業務層不必改動。

---

## 五、協定設計

### Content topics（Waku v2 慣例 `/{app}/{version}/{name}/{encoding}`）

> 注意：本專案產品名為 **NexusChat**，線上協定與內部常數統一以 `nexuschat` 作為識別字（content topic、`nexuschat|1|…` 簽章前綴、`nexuschat/enc/v1` 等）。以下以產品名 **NexusChat** 稱呼本專案。

| Topic | 用途 |
| --- | --- |
| `/nexuschat/1/keys/json` | 金鑰包：廣播自己的 X25519 公鑰與暱稱 |
| `/nexuschat/1/dm-<hash>/json` | 一對一訊息，`hash` 由雙方 DID 排序後雜湊（兩端算出同一個 topic） |
| `/nexuschat/1/inbox-<hash>/json` | **收件匣**：`hash` 只由收件人自己的 DID 派生 |
| `/nexuschat/1/presence/json` | 在線 / 輸入中（ephemeral，不進 store） |
| `/nexuschat/1/g-<hash>/json` | 群組聊天（預留） |

> 每一則私訊都會**同時**發到 `dm-*` 與對方的 `inbox-*`，收件端靠 `id` 去重。
> 為什麼需要收件匣：`dm-*` 只有在「收件人已把發送者加進聯絡人」時才會被輪詢，
> 對方還不認識你時那則訊息永遠不會被取走。每個客戶端固定輪詢
> `keys` + 自己的 `inbox-*`，所以**第一次來訊不需要事先加聯絡人**——
> 收到後會自動替對方建立名片，並用封包裡附的 `pub.enc` 立刻回覆。

### 封包格式

```jsonc
{
  "v": 1,
  "id": "uuid-v4",
  "type": "chat | receipt | typing | keybundle",
  "from": "did:ethr:0x…",          // 明文
  "to":   "did:ethr:0x…",          // 明文
  "ts": 1700000000000,             // 明文
  "body": { "ct": "…", "mac": "…", "nonce": "…", "eph": "…" },  // 加密給收件人
  "self": { "ct": "…", "mac": "…", "nonce": "…", "eph": "…" },  // 加密給自己的副本
  "sig":  "r:s:v"                  // secp256k1 簽章
}
```

- 簽章內容（正規化字串）：`nexuschat|1|{id}|{type}|{from}|{to}|{ts}|{cipherText}`
- 加密 AAD：`{from}|{to}|{ts}`，防止封包被搬到別的對話重放
- `self` 副本讓多裝置從 Waku store 還原自己的送出紀錄

### 金鑰派生

```
助記詞 (BIP39)
  └─ seed (PBKDF2-HMAC-SHA512)
       ├─ m/44'/60'/0'/0/0   → secp256k1 → 以太坊地址 → did:ethr:0x…
       │                                              ↘ 同一把金鑰 → TRON T 地址
       └─ m/10016'/0'        → X25519 訊息加密金鑰（與 EVM 帳戶路徑隔離）
```

---

## 六、專案結構

```
lib/
├── main.dart                  # 入口：初始化 Core、裝載硬體鍵盤/生命週期監聽後注入 ProviderScope
├── app/
│   └── core.dart              # 核心容器（儲存 / 身份 / 保險庫 / 密碼學 / Waku / 示範機器人）
├── core/
│   ├── l10n/                  # 四語文案與 Localizations delegate
│   ├── theme/                 # Material 3 主題、調色盤、圓角與間距尺度
│   └── utils/                 # Hex/Base64、時間與金額格式化
├── data/
│   ├── crypto/                # 身份派生、DID、加解密與簽章、TRON 地址編碼
│   ├── security/              # ★ 保險庫（PBKDF2 + AES-GCM）與密碼策略
│   ├── waku/                  # content topics、封包、傳輸層（REST / 本機迴路）
│   ├── ethereum/              # 餘額、chain id、ENS、轉帳簽章與廣播
│   ├── media/                 # 圖片壓縮、錄音與播放（原生 / Web 雙實作）
│   ├── models/                # 設定、安全設定、鏈、聯絡人、對話、訊息、身份提示
│   ├── repositories/          # 各資料表的讀寫
│   └── storage/               # Hive 封裝（含保險庫鍵）
├── state/
│   └── controllers.dart       # Riverpod：設定 / 身份 / 會話鎖 / 安全 / 聯絡人 / 聊天 / 錢包
├── ui/
│   ├── router.dart            # go_router（migration → locked → unlocked 重定向鏈、?peer= 深層連結）
│   └── shell.dart             # 響應式殼層（NavigationRail / NavigationBar）
└── features/
    ├── onboarding/            # 歡迎 / 建立身份（含密碼設定）/ 匯入
    ├── lock/                  # ★ 解鎖頁
    ├── security/              # ★ 舊明文遷移頁、密碼輸入元件
    ├── chats/                 # 對話列表與聊天頁（文字 / 圖片 / 語音）
    ├── contacts/              # 聯絡人（同步中 / 已加密狀態）
    ├── wallet/                # 收款 QR、轉帳頁
    └── settings/              # 設定頁、身份頁（匯出需密碼驗證）
test/
├── vault_test.dart            # 保險庫：還原正確性、密文不含秘密、竄改與錯誤碼
├── private_key_import_test.dart
├── tron_address_test.dart     # TRON 地址派生與 Base58Check 校驗
├── tron_tx_test.dart
└── widget_test.dart           # 端到端加解密、簽章不可偽造
```

---

## 七、測試

```bash
flutter test                   # 40 項全過
dart run tool/smoke.dart       # 不依賴 flutter_test 的核心邏輯冒煙
dart run tool/e2e_waku.dart <nodeA> <nodeB>   # 真實節點端到端（14 項）
```

---

## 八、目前限制與後續

- **推播**：目前以 4 秒輪詢取得新訊息；接上 Filter v2 的 WebSocket 後可改成即時推播。
- **群組聊天**：topic 與資料模型已預留，加密方案預計改用 sender keys。
- **前向保密**：已使用一次性 X25519 金鑰，尚未實作 Signal 式的棘輪（Double Ratchet）。
- **多裝置**：`self` 副本與 store 已具備基礎，尚未做裝置間的金鑰同步與撤銷。
- **ENS**：以 JSON-RPC 直接呼叫 registry / resolver；反向解析需要該地址已設定反向紀錄。
- **多媒體大小**：圖片會先壓縮再上 Waku，未做分片；大檔（影片）尚未支援。
- **Web 安全邊界**：見 3.1 —— 瀏覽器內無法對抗同源腳本注入，請只從信任的來源開啟。

---

## 九、安全提醒

- 助記詞是**唯一**能還原身份的方式，請離線保存；任何人取得它便能完全控制你的身份。
- **保險庫密碼無法找回**。忘了密碼 ＝ 本地身份永久無法解鎖，只能重新匯入助記詞重建。
  （這不是缺陷：能找回的密碼，代表系統裡存在第二條不需要你知道的解密路徑。）
- 匯出助記詞後請立即收好，頁面會在 30 秒後自動隱藏，但**剪貼簿不會自動清除**，請自行覆蓋。
- 本專案尚未經過第三方安全審計，請勿直接用於承載高敏感資訊的正式場景。
