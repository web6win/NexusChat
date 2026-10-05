# NexusChat

[English](README_EN.md) | 简体中文

> 基于 **Waku** 的去中心化聊天：**DID** 身份、**以太坊**生态、端到端加密。
> 一套 Flutter 程式码，同时覆盖 **H5 / 行动端（Android · iOS）/ 桌面端（Windows · macOS · Linux）**。
> 私钥与助记词**永不以明文落地**：本地保险库以你的密码（PBKDF2 + AES-256-GCM）加密存放。

---

## 一、核心特性

| 面向 | 实作 |
| --- | --- |
| 网路 | Waku v2（relay / store 语义），content topic 分流；可接 **nwaku REST 节点**，也可用**本机模拟**零依赖体验 |
| 身份 | BIP39 助记词 → BIP32 派生 → secp256k1 以太坊帐户 → `did:ethr:0x…`（亦可直接汇入私钥） |
| 加密 | X25519（一次性金钥 ↔ 对方静态金钥）→ HKDF-SHA256 → **AES-256-GCM** |
| 完整性 | 每则封包附 secp256k1 签章，接收端回推地址与 DID 比对，杜绝冒用 |
| **金钥保管** | **本地保险库**：PBKDF2-HMAC-SHA256（21 万 / 60 万次可选）+ AES-256-GCM；静态零明文 |
| **会话锁定** | 启动不自动解锁、闲置自动锁（预设 5 分钟）、手动锁定立即清空记忆体中的金钥 |
| 以太坊生态 | 余额查询、chain id、**ENS 正反解析**（EIP-137 namehash + registry / resolver 合约呼叫） |
| 钱包 | ETH / **TRON** / **Besu** 三链切换（同一把金钥派生），**已可签章并送出转帐**，附区块浏览器连结 |
| 讯息 | 文字、**图片**（压缩后传）、**语音**（录制 + 波形/播放） |
| **扫码** | **发现 → 扫一扫**：相机读取 QR Code；网址直接用外部浏览器开启，`did:ethr` / `0x` 地址 / ENS 可一键加入联络人 |
| 介面 | 响应式五栏导览（聊天 / 联络人 / 钱包 / 发现 / 设定）、Material 3、**日间 / 夜间**主题 |
| 多语 | English、简体中文、Español、हिन्दी、Français（英文为预设，可跟随系统） |
| 储存 | Hive（原生走档案系统，Web 走 IndexedDB），所有资料留在装置上 |

---

## 二、快速开始

```bash
# 1. 取得依赖
flutter pub get

# 2. H5
flutter run -d chrome          # 或 flutter build web --release

# 3. 桌面（Windows 需先安装 Visual Studio 2022「使用 C++ 的桌面开发」）
flutter run -d windows
flutter build windows --release

# 4. 行动端
flutter run -d android         # flutter build apk --release
flutter run -d ios             # 需要 Xcode，仅 macOS 可执行

# 5. 测试
flutter test                   # 40 项（保险库 / 私钥汇入 / TRON / 端到端加密 / 签章）
dart run tool/smoke.dart       # 核心逻辑冒烟测试（不依赖 flutter_test）
```

首次启动会进入引导页：**建立新身份**（12 个助记词）或**汇入既有助记词 / 私钥**。
建立与汇入流程都会要求**设定一组保险库密码**——它是日后解锁、改密码、汇出助记词的唯一凭据。

预设为「本机模拟」传输模式，开箱即有 3 位内建示范联络人与自动回覆，可直接体验完整的加密收发流程。

### 2.1 H5 部署与 CSP

`web/index.html` 内建 `Content-Security-Policy`。若自行加上更严格的策略，请务必保留：

- `script-src` 需含 `'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' blob:`
  以及 `https://www.gstatic.com/flutter-canvaskit/`（release 版的 CanvasKit 来源，
  **少了它网页会整片空白**）
- `worker-src` 需含 `blob:`（Flutter web worker）
- `font-src` 需含 `https://fonts.gstatic.com`
- `script-src` 与 `worker-src` 需含 `https://cdn.jsdelivr.net/npm/zxing-wasm/`
  （发现 → 扫一扫：浏览器没有原生 `BarcodeDetector` 时，扫码引擎从这里载入）

页面另设定 `referrer=no-referrer`，避免把带 DID 的路径外泄给第三方资源。
部署时建议由伺服器再补 `X-Frame-Options`、`X-Content-Type-Options` 等标头。

### 2.2 发现 → 扫一扫

底部导览（桌面为左侧栏）的**发现**页提供相机扫码。扫到的内容依序按下列规则分派：

| 扫到的内容 | 行为 |
| --- | --- |
| 网址（`http(s)://…`，或 `example.com/path` 这类网域） | **直接用外部浏览器开启**，成功后自动返回发现页；开启失败则提示并恢复扫描 |
| `did:ethr:0x…` / `0x…` 地址 / `xxx.eth` | 弹出结果面板：可**加入联络人**（加入后直接开启该 DID 的对话）或复制 |
| 其他文字 | 显示内容并可复制 |

身份类内容刻意优先于网址判断，否则 `name.eth` 会被当成一般网域送进浏览器。

- 相机后端由 [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) 提供，
  支援 **Android / iOS / macOS / 浏览器**；**Windows 与 Linux 没有相机后端**，
  扫码页会显示不支援提示而不会崩溃。
- 相机权限：Android 已宣告 `CAMERA`；iOS / macOS 已在 `Info.plist` 写入
  `NSCameraUsageDescription`（macOS 另需 Camera entitlement）。
- 浏览器必须在 **HTTPS 或 localhost** 下才能取得相机（localhost 视为安全上下文）。

### 2.3 Android 发布签名

`flutter build apk --release` 若没有 `android/key.properties`，会用**本机自动产生的 debug 金钥**签名。debug 金钥每台机器 / 每次 CI runner 都不同，会导致安装失败 `-7：与已安装应用签名不同`、**新版无法覆盖旧版**。因此发布用的 APK 必须固定用同一把金钥签名。

一次性产生金钥（**务必妥善保存**，遗失后将无法再覆盖升级已发布的 App）：

```bash
keytool -genkeypair -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias nexuschat
```

把金钥放到 `android/app/upload-keystore.jks`，并在 `android/key.properties`（**已在 .gitignore，勿提交**）填入：

```properties
storePassword=你的keystore密码
keyPassword=你的金钥密码
keyAlias=nexuschat
storeFile=upload-keystore.jks   # 相对于 android/app/
```

此后本机 `flutter build apk --release` 会自动套用固定签名。CI（`.github/workflows/build-and-publish.yml`）请于仓库 Settings → Secrets 设定：

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` 的输出 |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` |
| `ANDROID_KEY_ALIAS` | `keyAlias`（例如 `nexuschat`） |

> `ANDROID_KEYSTORE_BASE64` 在 Windows PowerShell 可这样产生：
> `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))`（Git Bash / Linux / macOS 用 `base64 -w0 upload-keystore.jks`）。

设定后 workflow 会在 Android 构建前自动写入金钥与 `key.properties`；未设定则维持 debug 签名（仅供测试，不可用于发布）。

> 装置上若已安装**旧签名**版本，需先卸载一次再安装新版；此后同一把金钥签出的版本即可正常覆盖升级。

---

## 三、身份与金钥安全

### 3.1 威胁模型（先讲清楚极限）

- **原生 / 桌面**：密码解开后的秘密只存在于本程序记忆体，磁碟上没有明文。
- **Web**：浏览器里没有可信任的硬体金钥储存。凡是「应用能自动解开」的方案，
  能执行脚本的攻击者就能用同一条路径解开。因此 Web 端的目标是
  **静态零明文 + 最短暴露窗口 + 密码因子不可重放**，而不是声称绝对防窃。
- 换句话说：**保险库防的是「拿走你的资料库 / 硬碟 / IndexedDB」，
  防不了「在你正在用的页面里执行脚本」。** 请只从你信任的网址开启 H5 版。

### 3.2 保险库格式

```
password ──PBKDF2-HMAC-SHA256(iterations, salt)──> 32 bytes key
                                                     │
payload(JSON: mnemonic / privateKey …) ──AES-256-GCM─┘──> ct + mac
```

密文以 Map 存放，只有标头是公开的（它们不是秘密）：

```jsonc
{
  "v": 1,
  "kdf": "pbkdf2-hmac-sha256",
  "iterations": 210000,      // 210000 或 600000，写入标头，未来可无痛升级
  "salt": "…", "nonce": "…", // 每次加密独立随机
  "ct": "…", "mac": "…"      // AES-256-GCM，16 位元组认证标签
}
```

- **AAD** 绑定 `nexuschat/vault/v1`，避免别处的密文被移花接木。
- 解密失败统一回传 `bad-password`，**不区分「密码错」与「密文被窜改」**，避免成为猜测 oracle。
  其余错误码：`corrupt`（结构毁损）、`unsupported`（版本 / KDF 不认识）。
- **密码策略**：至少 8 位；纯数字、常见弱密码、重复或连续序列一律拒绝；
  强度标签 `weak / fair / good / strong`，`score ≥ 2` 才接受。
- 迭代次数取 21 万是为了让**纯 Dart 实作**（无 WebCrypto 加速）的首次解锁仍在一秒内；
  想要更高强度可在设定密码时选 60 万（OWASP 对 PBKDF2-HMAC-SHA256 的建议值）。

### 3.3 静态资料的存放方式

| 键 | 内容 | 说明 |
| --- | --- | --- |
| `identity_vault` | 保险库密文 | 助记词 / 私钥唯一的落地形式 |
| `identity_hint` | `did`、地址、TRON 地址、加密公钥 | **公开提示**，未解锁时也能显示名片 |
| `identity` | 旧版明文身份 | 仅供升级时迁移，迁移完成即失效 |

### 3.4 会话与锁定

- `Core.bootstrap()` **不会**自动解锁；必须 `unlock(password)` 才把金钥载入记忆体。
- `lock()` 停止 Waku 并清空记忆体中的身份物件。
- **闲置自动锁**：预设 5 分钟，可选 1 / 5 / 15 / 30 / 60 分钟或永不（0）。
- **切到背景立即锁**：预设关闭（浏览器频繁切分页会很恼人），要求高者可开启。
- **汇出助记词 / 私钥**：需先通过密码验证，显示后预设 **30 秒自动隐藏**，防肩窥与萤幕录制残留。
- **改密码**：以新密码重新封装整包密文，旧密文不再保留。
- **旧版升级**：启动时侦测到明文身份会导向 `/migrate`，设定密码后迁入保险库。

---

## 四、连上真实 Waku 节点

> 联络人清单显示黄色「同步中」＝还没拿到对方的加密公钥（key bundle）。
> 在本机模拟模式下讯息只在自己的 app 内打转，只有真正连上 Waku 网路，
> 且对方也上线发布过金钥包，状态才会转成绿色「已加密」。

### 4.1 一键起节点（推荐）

专案内附 `docker/docker-compose.yml`，内含**两个互相直连的 nwaku 节点**：

```bash
cd docker
bash deploy.sh        # 或 docker compose up -d（deploy.sh 会自动校正 peer ID）
docker compose logs -f nwaku-a nwaku-b
docker compose down
```

为什么要两个：gossipsub 在节点没有任何 peer 时会拒绝发布（`NoPeersToPublish`），
单节点上两个客户端是聊不起来的。这里让 A、B 互相以 `--staticnode` 直连，
**不依赖外网**，局域网即可跑通完整流程。

> **staticnode 一定要写 IP，不能写 `/dns4/` 容器名**：nwaku 的 DNS 解析器在
> Docker 容器内会回传空阵列（`resolvedAddresses=[]`），用 `/dns4/nwaku-a/...`
> 会静默拨号失败。compose 已为两个节点配置固定 IP（`172.28.0.10` / `172.28.0.11`）。

| 服务 | REST 埠 | 说明 |
| --- | --- | --- |
| `nwaku-a` | `8645` | 给**客户端一**用（relay + store + filter + lightpush） |
| `nwaku-b` | `8646` | 给**客户端二**用，与 A 互相转发、各自保存讯息 |

客户端填法（设定 → 网路 → Waku 节点（REST））：

- **客户端一**：`http://<主机IP>:8645`（本机就是 `http://localhost:8645`）
- **客户端二**：`http://<主机IP>:8646`
- **两个客户端都填同一个节点也可以**（例如都填 `8645`）——relay 快取读走即清空，
  但 store 会持久保存，客户端两个来源合并去重，不会互相抢走讯息
- 节点已带 `--rest-allow-origin=*`，浏览器 H5 可直连，无需反代
- 手机实机：把 `<主机IP>` 换成电脑的区域网路 IP

> 注意：两个节点的私钥固定写在 `docker/.env`（仅供开发），所以 peer ID 稳定；
> 正式部署请换成自己的私钥。若要接公共 Waku 网路，给节点追加有效的
> `--dns-discovery-url`（官方 sandbox fleet 的 DNS 目前已停止解析）或
> `--staticnode` 到任一公共节点即可。

### 4.2 验证节点

```bash
curl http://127.0.0.1:8645/debug/v1/info    # 节点 A 资讯（含 peer ID）
curl http://127.0.0.1:8646/debug/v1/info    # 节点 B 资讯
curl http://127.0.0.1:8645/health           # Relay 应为 READY（代表有 peer）
```

### 4.3 端到端聊天测试

不需开浏览器，直接验证「金钥交换 → 加密私讯 → 双向收发 → 第三方窃听失败」：

```bash
# 两个客户端各连一个节点
dart run tool/e2e_waku.dart http://10.37.0.110:8645 http://10.37.0.110:8646

# 或两个客户端共用同一个节点
dart run tool/e2e_waku.dart http://10.37.0.110:8645 http://10.37.0.110:8645
```

14 项全过才算通；失败时会印出诊断（看到几则金钥包、各自的 `from` DID）。

埠号与镜像版本可用环境变数覆写：`REST_A_PORT`、`REST_B_PORT`、`TCP_A_PORT`、
`TCP_B_PORT`、`UDP_A_PORT`、`UDP_B_PORT`、`NWAKU_IMAGE`、`NWAKU_NODEKEY_A/B`
（见 `docker/docker-compose.yml`）。

> NexusChat 走 `/relay/v1/auto/messages`（自动分片，topic 是**路径段**，且 body 是
> **单一物件不是阵列**）、`GET /store/v3/messages?includeData=true`（拉历史）。
> 注意 store v3 回传的每笔是 `{"messageHash":..,"message":{..},"pubsubTopic":..}`
> 包装结构，真正栏位在 `message` 里，解析时必须拆开。
> relay 快取**读走即清空**，store 才持久，所以客户端两个来源合并去重。
> 客户端每 2 分钟自动重发一次金钥包，新加的联络人也能从 store 补到公钥。

传输层 `WakuTransport` 是抽象介面。日后要换成 JSON-RPC、Filter v2 WebSocket 推播，
或在原生端嵌入 waku 绑定，只需新增一个实作，UI 与业务层不必改动。

---

## 五、协定设计

### Content topics（Waku v2 惯例 `/{app}/{version}/{name}/{encoding}`）

> 注意：本专案产品名为 **NexusChat**，线上协定与内部常数统一以 `nexuschat` 作为识别字（content topic、`nexuschat|1|…` 签章前缀、`nexuschat/enc/v1` 等）。以下以产品名 **NexusChat** 称呼本专案。

| Topic | 用途 |
| --- | --- |
| `/nexuschat/1/keys/json` | 金钥包：广播自己的 X25519 公钥与昵称 |
| `/nexuschat/1/dm-<hash>/json` | 一对一讯息，`hash` 由双方 DID 排序后杂凑（两端算出同一个 topic） |
| `/nexuschat/1/inbox-<hash>/json` | **收件匣**：`hash` 只由收件人自己的 DID 派生 |
| `/nexuschat/1/presence/json` | 在线 / 输入中（ephemeral，不进 store） |
| `/nexuschat/1/g-<hash>/json` | 群组聊天（预留） |

> 每一则私讯都会**同时**发到 `dm-*` 与对方的 `inbox-*`，收件端靠 `id` 去重。
> 为什么需要收件匣：`dm-*` 只有在「收件人已把发送者加进联络人」时才会被轮询，
> 对方还不认识你时那则讯息永远不会被取走。每个客户端固定轮询
> `keys` + 自己的 `inbox-*`，所以**第一次来讯不需要事先加联络人**——
> 收到后会自动替对方建立名片，并用封包里附的 `pub.enc` 立刻回覆。

### 封包格式

```jsonc
{
  "v": 1,
  "id": "uuid-v4",
  "type": "chat | receipt | typing | keybundle",
  "from": "did:ethr:0x…",          // 明文
  "to":   "did:ethr:0x…",          // 明文
  "ts": 1700000000000,             // 明文
  "body": { "ct": "…", "mac": "…", "nonce": "…", "eph": "…" },  // 加密给收件人
  "self": { "ct": "…", "mac": "…", "nonce": "…", "eph": "…" },  // 加密给自己的副本
  "sig":  "r:s:v"                  // secp256k1 签章
}
```

- 签章内容（正规化字串）：`nexuschat|1|{id}|{type}|{from}|{to}|{ts}|{cipherText}`
- 加密 AAD：`{from}|{to}|{ts}`，防止封包被搬到别的对话重放
- `self` 副本让多装置从 Waku store 还原自己的送出纪录

### 金钥派生

```
助记词 (BIP39)
  └─ seed (PBKDF2-HMAC-SHA512)
       ├─ m/44'/60'/0'/0/0   → secp256k1 → 以太坊地址 → did:ethr:0x…
       │                                              ↘ 同一把金钥 → TRON T 地址
       └─ m/10016'/0'        → X25519 讯息加密金钥（与 EVM 帐户路径隔离）
```

---

## 六、专案结构

```
lib/
├── main.dart                  # 入口：初始化 Core、装载硬体键盘/生命周期监听后注入 ProviderScope
├── app/
│   └── core.dart              # 核心容器（储存 / 身份 / 保险库 / 密码学 / Waku / 示范机器人）
├── core/
│   ├── l10n/                  # 四语文案与 Localizations delegate
│   ├── theme/                 # Material 3 主题、调色盘、圆角与间距尺度
│   └── utils/                 # Hex/Base64、时间与金额格式化
├── data/
│   ├── crypto/                # 身份派生、DID、加解密与签章、TRON 地址编码
│   ├── security/              # ★ 保险库（PBKDF2 + AES-GCM）与密码策略
│   ├── waku/                  # content topics、封包、传输层（REST / 本机回路）
│   ├── ethereum/              # 余额、chain id、ENS、转帐签章与广播
│   ├── media/                 # 图片压缩、录音与播放（原生 / Web 双实作）
│   ├── models/                # 设定、安全设定、链、联络人、对话、讯息、身份提示
│   ├── repositories/          # 各资料表的读写
│   └── storage/               # Hive 封装（含保险库键）
├── state/
│   └── controllers.dart       # Riverpod：设定 / 身份 / 会话锁 / 安全 / 联络人 / 聊天 / 钱包
├── ui/
│   ├── router.dart            # go_router（migration → locked → unlocked 重定向链、?peer= 深层连结）
│   └── shell.dart             # 响应式壳层（NavigationRail / NavigationBar）
└── features/
    ├── onboarding/            # 欢迎 / 建立身份（含密码设定）/ 汇入
    ├── lock/                  # ★ 解锁页
    ├── security/              # ★ 旧明文迁移页、密码输入元件
    ├── chats/                 # 对话列表与聊天页（文字 / 图片 / 语音）
    ├── contacts/              # 联络人（同步中 / 已加密状态）
    ├── wallet/                # 收款 QR、转帐页
    ├── discover/              # 发现页、扫一扫（相机扫码与结果分派）
    └── settings/              # 设定页、身份页（汇出需密码验证）
test/
├── vault_test.dart            # 保险库：还原正确性、密文不含秘密、窜改与错误码
├── private_key_import_test.dart
├── tron_address_test.dart     # TRON 地址派生与 Base58Check 校验
├── tron_tx_test.dart
└── widget_test.dart           # 端到端加解密、签章不可伪造
```

---

## 七、测试

```bash
flutter test                   # 40 项全过
dart run tool/smoke.dart       # 不依赖 flutter_test 的核心逻辑冒烟
dart run tool/e2e_waku.dart <nodeA> <nodeB>   # 真实节点端到端（14 项）
```

---

## 八、目前限制与后续

- **推播**：目前以 4 秒轮询取得新讯息；接上 Filter v2 的 WebSocket 后可改成即时推播。
- **群组聊天**：topic 与资料模型已预留，加密方案预计改用 sender keys。
- **前向保密**：已使用一次性 X25519 金钥，尚未实作 Signal 式的棘轮（Double Ratchet）。
- **多装置**：`self` 副本与 store 已具备基础，尚未做装置间的金钥同步与撤销。
- **ENS**：以 JSON-RPC 直接呼叫 registry / resolver；反向解析需要该地址已设定反向纪录。
- **多媒体大小**：图片会先压缩再上 Waku，未做分片；大档（影片）尚未支援。
- **扫码**：仅 Android / iOS / macOS / 浏览器可用（mobile_scanner 的平台限制），
  Windows 与 Linux 显示「不支援扫码」；尚未支援「从相簿图片辨识 QR Code」。
- **Web 安全边界**：见 3.1 —— 浏览器内无法对抗同源脚本注入，请只从信任的来源开启。

---

## 九、安全提醒

- 助记词是**唯一**能还原身份的方式，请离线保存；任何人取得它便能完全控制你的身份。
- **保险库密码无法找回**。忘了密码 ＝ 本地身份永久无法解锁，只能重新汇入助记词重建。
  （这不是缺陷：能找回的密码，代表系统里存在第二条不需要你知道的解密路径。）
- 汇出助记词后请立即收好，页面会在 30 秒后自动隐藏，但**剪贴簿不会自动清除**，请自行覆盖。
- 本专案尚未经过第三方安全审计，请勿直接用于承载高敏感资讯的正式场景。

---

## 十、开源授权

Copyright © 2026 WEB6 contributors

本专案以 **GNU General Public License v3.0（GPL-3.0）** 授权释出，完整条款见 [`LICENSE`](LICENSE)。

- 可自由使用、复制、修改与散布（**含商业用途**）。
- **衍生作品必须以相同授权（GPL-3.0）释出**，并保留着作权与授权声明。
- 散布时必须一并提供完整的**对应原始码**（或提供取得方式）。
- 本软体**不附任何担保**，详见条款第 15、16 节。

第三方套件（Flutter 外挂等）各自沿用其原始授权，请参考 `pubspec.yaml` 与各套件说明。
