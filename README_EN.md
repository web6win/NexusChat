# NexusChat

English | [繁體中文](README.md)

> Decentralized chat built on **Waku**: **DID** identity, the **Ethereum** ecosystem, end-to-end encryption.
> One Flutter codebase covering **H5 / mobile (Android · iOS) / desktop (Windows · macOS · Linux)**.
> Private keys and mnemonics are **never stored in plaintext**: the local vault is encrypted with your password (PBKDF2 + AES-256-GCM).

---

## 1. Core Features

| Area | Implementation |
| --- | --- |
| Network | Waku v2 (relay / store semantics), content-topic fan-out; connect to a **nwaku REST node**, or use the **local simulator** for a zero-dependency trial |
| Identity | BIP39 mnemonic → BIP32 derivation → secp256k1 Ethereum account → `did:ethr:0x…` (a raw private key can also be imported) |
| Encryption | X25519 (ephemeral key ↔ recipient static key) → HKDF-SHA256 → **AES-256-GCM** |
| Integrity | Every packet carries a secp256k1 signature; the recipient recovers the address and compares it against the DID, ruling out impersonation |
| **Key custody** | **Local vault**: PBKDF2-HMAC-SHA256 (210k / 600k iterations, selectable) + AES-256-GCM; zero plaintext at rest |
| **Session locking** | No auto-unlock at startup, idle auto-lock (5 minutes by default), and manual lock that immediately wipes keys from memory |
| Ethereum ecosystem | Balance lookup, chain id, **forward and reverse ENS resolution** (EIP-137 namehash + registry / resolver contract calls) |
| Wallet | ETH / **TRON** / **Besu** switchable (derived from the same key); **signing and broadcasting transfers already work**, with block-explorer links |
| Messages | Text, **images** (compressed before sending), **voice** (recording + waveform / playback) |
| **Scanning** | **Discover → Scan**: read QR codes with the camera; URLs open directly in the external browser, and `did:ethr` / `0x` addresses / ENS names can be added as a contact in one tap |
| Interface | Responsive navigation (Chats / Contacts / Wallet / Discover / Settings), Material 3, **light / dark** themes |
| Languages | 繁體中文, 简体中文, English, Español (can follow the system) |
| Storage | Hive (filesystem on native, IndexedDB on web); all data stays on the device |

---

## 2. Quick Start

```bash
# 1. Fetch dependencies
flutter pub get

# 2. H5
flutter run -d chrome          # or flutter build web --release

# 3. Desktop (on Windows, install Visual Studio 2022 "Desktop development with C++" first)
flutter run -d windows
flutter build windows --release

# 4. Mobile
flutter run -d android         # flutter build apk --release
flutter run -d ios             # requires Xcode, macOS only

# 5. Tests
flutter test                   # 40 tests (vault / private-key import / TRON / E2E encryption / signatures)
dart run tool/smoke.dart       # core-logic smoke test (does not depend on flutter_test)
```

The first launch opens the onboarding flow: **create a new identity** (12-word mnemonic) or **import an existing mnemonic / private key**.
Both flows require you to **set a vault password** — it is the only credential for unlocking, changing the password, and exporting the mnemonic later.

The default transport is the **local simulator**: three built-in demo contacts with auto-replies, so you can try the full encrypted send/receive flow out of the box.

### 2.1 H5 Deployment and CSP

`web/index.html` ships a `Content-Security-Policy`. If you tighten it further, make sure to keep:

- `script-src` must include `'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' blob:`
  plus `https://www.gstatic.com/flutter-canvaskit/` (the CanvasKit source for release builds —
  **without it the page renders completely blank**)
- `worker-src` must include `blob:` (Flutter web worker)
- `font-src` must include `https://fonts.gstatic.com`
- `script-src` and `worker-src` must include `https://cdn.jsdelivr.net/npm/zxing-wasm/`
  (Discover → Scan: the scanning engine is loaded from here when the browser has no native `BarcodeDetector`)

The page also sets `referrer=no-referrer` so that paths carrying a DID are not leaked to third-party resources.
When deploying, add `X-Frame-Options`, `X-Content-Type-Options`, and similar headers at the server.

### 2.2 Discover → Scan

The **Discover** tab (bottom bar on mobile, left rail on desktop) provides camera scanning. Scanned content is dispatched in this order:

| Scanned content | Behavior |
| --- | --- |
| A URL (`http(s)://…`, or a bare domain such as `example.com/path`) | **Opened directly in the external browser**; returns to Discover on success. If opening fails, a message is shown and scanning resumes |
| `did:ethr:0x…` / `0x…` address / `xxx.eth` | A result sheet appears: **add as contact** (then the chat for that DID opens) or copy |
| Any other text | The content is displayed and can be copied |

Identity-like content is deliberately evaluated before URLs, otherwise `name.eth` would be handed to the browser as an ordinary domain.

- The camera backend comes from [`mobile_scanner`](https://pub.dev/packages/mobile_scanner),
  which supports **Android / iOS / macOS / web**. **Windows and Linux have no camera backend** —
  the scan page shows an unsupported notice instead of crashing.
- Camera permission: `CAMERA` is declared on Android; `NSCameraUsageDescription` is set in `Info.plist`
  on iOS / macOS (macOS additionally needs the Camera entitlement).
- In a browser, the camera is only available over **HTTPS or localhost** (localhost counts as a secure context).

### 2.3 Android release signing

Without `android/key.properties`, `flutter build apk --release` is signed with an **auto-generated debug key**. That key differs per machine / CI runner, so installs fail with `-7: signatures do not match the previously installed version` and **new builds cannot upgrade older installs**. Release APKs must always be signed with one fixed key.

Generate the key once (keep it safe — if you lose it you can no longer upgrade published installs):

```bash
keytool -genkeypair -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias nexuschat
```

Put it at `android/app/upload-keystore.jks` and fill in `android/key.properties` (**already git-ignored — never commit**):

```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=nexuschat
storeFile=upload-keystore.jks   # relative to android/app/
```

Local `flutter build apk --release` will then use the fixed signature. For CI (`.github/workflows/build-and-publish.yml`), set these repo Settings → Secrets:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | output of `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` |
| `ANDROID_KEY_ALIAS` | `keyAlias` (e.g. `nexuschat`) |

> On Windows PowerShell, produce `ANDROID_KEYSTORE_BASE64` with
> `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))` (Git Bash / Linux / macOS: `base64 -w0 upload-keystore.jks`).

The workflow then writes the keystore and `key.properties` before the Android build; without them it falls back to debug signing (testing only, not for release).

> A device with an older, differently-signed build must **uninstall once** before installing the new one; afterwards, builds signed with the same key upgrade normally.

---

## 3. Identity and Key Security

### 3.1 Threat Model (Limits First)

- **Native / desktop**: after the password unlocks them, secrets live only in this process's memory; there is no plaintext on disk.
- **Web**: browsers have no trustworthy hardware key store. Any scheme where "the app can unlock automatically"
  can be used by an attacker able to run script through the very same path. The web build therefore targets
  **zero plaintext at rest + the shortest exposure window + a non-replayable password factor**,
  rather than claiming absolute theft-resistance.
- In other words: **the vault protects against "someone taking your database / disk / IndexedDB" —
  not against "script running inside the page you are already using."** Only open the H5 build from a URL you trust.

### 3.2 Vault Format

```
password ──PBKDF2-HMAC-SHA256(iterations, salt)──> 32 bytes key
                                                     │
payload(JSON: mnemonic / privateKey …) ──AES-256-GCM─┘──> ct + mac
```

The ciphertext is stored as a Map; only the header is public (none of it is secret):

```jsonc
{
  "v": 1,
  "kdf": "pbkdf2-hmac-sha256",
  "iterations": 210000,      // 210000 or 600000, written to the header for painless future upgrades
  "salt": "…", "nonce": "…", // freshly random on every encryption
  "ct": "…", "mac": "…"      // AES-256-GCM, 16-byte authentication tag
}
```

- **AAD** is bound to `nexuschat/vault/v1` so ciphertext from elsewhere cannot be swapped in.
- Decryption failure always returns `bad-password`, **without distinguishing "wrong password" from "tampered ciphertext"**,
  so it cannot be used as a guessing oracle. Other error codes: `corrupt` (structural damage), `unsupported` (unknown version / KDF).
- **Password policy**: at least 8 characters; digits-only, common weak passwords, and repeated or sequential strings are all rejected.
  Strength labels are `weak / fair / good / strong`, and `score ≥ 2` is required.
- 210,000 iterations keeps the first unlock under a second even with the **pure-Dart implementation**
  (no WebCrypto acceleration); choose 600,000 when setting the password for higher strength
  (OWASP's recommendation for PBKDF2-HMAC-SHA256).

### 3.3 Data at Rest

| Key | Content | Notes |
| --- | --- | --- |
| `identity_vault` | Vault ciphertext | The only form in which the mnemonic / private key is persisted |
| `identity_hint` | `did`, address, TRON address, encryption public key | **Public hint**: lets the card render while locked |
| `identity` | Legacy plaintext identity | Only for upgrade-time migration; invalid once migration completes |

### 3.4 Sessions and Locking

- `Core.bootstrap()` does **not** auto-unlock; `unlock(password)` is required before keys enter memory.
- `lock()` stops Waku and clears the identity object from memory.
- **Idle auto-lock**: 5 minutes by default; 1 / 5 / 15 / 30 / 60 minutes, or never (0).
- **Lock immediately when backgrounded**: off by default (browsers switch tabs constantly, which would be annoying); enable it if you need it.
- **Exporting the mnemonic / private key**: requires password verification first, and the value is **hidden again after 30 seconds** by default, guarding against shoulder surfing and screen-recording residue.
- **Changing the password**: the whole ciphertext is re-wrapped with the new password; the old ciphertext is not kept.
- **Legacy upgrade**: if a plaintext identity is detected at startup, the app routes to `/migrate`; after a password is set, it is migrated into the vault.

---

## 4. Connecting to a Real Waku Node

> A yellow "syncing" state in the contact list means the peer's encryption public key (key bundle) has not arrived yet.
> In local-simulator mode messages only circulate inside your own app; the state turns green ("encrypted")
> only when you are truly on the Waku network **and** the peer has published a key bundle.

### 4.1 One-Command Node Setup (Recommended)

`docker/docker-compose.yml` ships **two nwaku nodes connected directly to each other**:

```bash
cd docker
bash deploy.sh        # or docker compose up -d (deploy.sh fixes up the peer IDs automatically)
docker compose logs -f nwaku-a nwaku-b
docker compose down
```

Why two: gossipsub refuses to publish when a node has no peers at all (`NoPeersToPublish`),
so two clients on a single node cannot talk to each other. Here A and B are wired together with `--staticnode`,
requiring **no internet** — a LAN is enough to run the whole flow.

> **staticnode must use an IP, not a `/dns4/` container name**: nwaku's DNS resolver returns an empty array
> (`resolvedAddresses=[]`) inside Docker containers, so `/dns4/nwaku-a/...` fails to dial silently.
> The compose file already assigns fixed IPs to both nodes (`172.28.0.10` / `172.28.0.11`).

| Service | REST port | Notes |
| --- | --- | --- |
| `nwaku-a` | `8645` | For **client one** (relay + store + filter + lightpush) |
| `nwaku-b` | `8646` | For **client two**; forwards with A and stores messages independently |

How to fill it in on the client (Settings → Network → Waku node (REST)):

- **Client one**: `http://<hostIP>:8645` (on the same machine: `http://localhost:8645`)
- **Client two**: `http://<hostIP>:8646`
- **Both clients may use the same node** (e.g. both `8645`) — the relay cache is drained once read,
  but store persists, and the client merges and de-duplicates both sources, so they do not steal messages from each other
- The nodes run with `--rest-allow-origin=*`, so the browser H5 build can connect directly with no reverse proxy
- On a physical phone: replace `<hostIP>` with the computer's LAN IP

> Note: both node private keys are hard-coded in `docker/.env` (development only), which keeps peer IDs stable;
> use your own keys for real deployments. To join the public Waku network, add a working
> `--dns-discovery-url` (the official sandbox fleet's DNS no longer resolves) or a `--staticnode`
> pointing at any public node.

### 4.2 Verifying the Nodes

```bash
curl http://127.0.0.1:8645/debug/v1/info    # node A info (includes peer ID)
curl http://127.0.0.1:8646/debug/v1/info    # node B info
curl http://127.0.0.1:8645/health           # Relay should be READY (meaning it has peers)
```

### 4.3 End-to-End Chat Test

No browser needed — this verifies "key exchange → encrypted DM → bidirectional send/receive → third-party eavesdropping fails":

```bash
# each client on its own node
dart run tool/e2e_waku.dart http://10.37.0.110:8645 http://10.37.0.110:8646

# or both clients sharing one node
dart run tool/e2e_waku.dart http://10.37.0.110:8645 http://10.37.0.110:8645
```

All 14 checks must pass; on failure it prints diagnostics (how many key bundles were seen, and each one's `from` DID).

Ports and image versions can be overridden with environment variables: `REST_A_PORT`, `REST_B_PORT`, `TCP_A_PORT`,
`TCP_B_PORT`, `UDP_A_PORT`, `UDP_B_PORT`, `NWAKU_IMAGE`, `NWAKU_NODEKEY_A/B`
(see `docker/docker-compose.yml`).

> NexusChat uses `/relay/v1/auto/messages` (auto-sharding, the topic is a **path segment**, and the body is
> **a single object, not an array**) and `GET /store/v3/messages?includeData=true` (fetch history).
> Note that store v3 returns each entry wrapped as `{"messageHash":..,"message":{..},"pubsubTopic":..}`;
> the real fields are inside `message` and must be unwrapped when parsing.
> The relay cache is **drained once read**; only store persists, so the client merges and de-duplicates both sources.
> Clients re-publish their key bundle every 2 minutes, so newly added contacts can still pick up the public key from store.

The transport layer `WakuTransport` is an abstract interface. Moving to JSON-RPC, Filter v2 WebSocket push,
or embedding native waku bindings later only requires adding one implementation — the UI and business layers need no changes.

---

## 5. Protocol Design

### Content topics (Waku v2 convention `/{app}/{version}/{name}/{encoding}`)

> Note: the product is named **NexusChat**, while the wire protocol and internal constants uniformly use `nexuschat` as the identifier (content topics, the `nexuschat|1|…` signature prefix, `nexuschat/enc/v1`, and so on). Below, the project is referred to by its product name **NexusChat**.

| Topic | Purpose |
| --- | --- |
| `/nexuschat/1/keys/json` | Key bundle: broadcast your own X25519 public key and nickname |
| `/nexuschat/1/dm-<hash>/json` | One-to-one messages; `hash` is derived from both DIDs after sorting (both ends compute the same topic) |
| `/nexuschat/1/inbox-<hash>/json` | **Inbox**: `hash` is derived from the recipient's own DID only |
| `/nexuschat/1/presence/json` | Online / typing (ephemeral, not stored) |
| `/nexuschat/1/g-<hash>/json` | Group chat (reserved) |

> Every direct message is published to **both** `dm-*` and the recipient's `inbox-*`; the receiving end de-duplicates by `id`.
> Why an inbox is needed: `dm-*` is only polled once "the recipient has added the sender as a contact",
> so a message from someone they do not know would never be picked up. Every client always polls
> `keys` + its own `inbox-*`, so **the first message does not require adding a contact first** —
> on receipt, a card is created for the sender automatically and the enclosed `pub.enc` allows an immediate reply.

### Packet Format

```jsonc
{
  "v": 1,
  "id": "uuid-v4",
  "type": "chat | receipt | typing | keybundle",
  "from": "did:ethr:0x…",          // plaintext
  "to":   "did:ethr:0x…",          // plaintext
  "ts": 1700000000000,             // plaintext
  "body": { "ct": "…", "mac": "…", "nonce": "…", "eph": "…" },  // encrypted for the recipient
  "self": { "ct": "…", "mac": "…", "nonce": "…", "eph": "…" },  // encrypted copy for yourself
  "sig":  "r:s:v"                  // secp256k1 signature
}
```

- Signed payload (canonical string): `nexuschat|1|{id}|{type}|{from}|{to}|{ts}|{cipherText}`
- Encryption AAD: `{from}|{to}|{ts}`, preventing a packet from being replayed into another conversation
- The `self` copy lets multiple devices restore their own sent history from Waku store

### Key Derivation

```
mnemonic (BIP39)
  └─ seed (PBKDF2-HMAC-SHA512)
       ├─ m/44'/60'/0'/0/0   → secp256k1 → Ethereum address → did:ethr:0x…
       │                                              ↘ same key → TRON T address
       └─ m/10016'/0'        → X25519 message-encryption key (isolated from the EVM account path)
```

---

## 6. Project Structure

```
lib/
├── main.dart                  # Entry: initializes Core, installs hardware-keyboard / lifecycle listeners, injects ProviderScope
├── app/
│   └── core.dart              # Core container (storage / identity / vault / crypto / Waku / demo bot)
├── core/
│   ├── l10n/                  # Four-language strings and the Localizations delegate
│   ├── theme/                 # Material 3 theme, palette, radius and spacing scale
│   └── utils/                 # Hex/Base64, time and amount formatting
├── data/
│   ├── crypto/                # Identity derivation, DID, encryption/decryption and signing, TRON address encoding
│   ├── security/              # ★ Vault (PBKDF2 + AES-GCM) and password policy
│   ├── waku/                  # Content topics, packets, transport (REST / local loopback)
│   ├── ethereum/              # Balance, chain id, ENS, transfer signing and broadcast
│   ├── media/                 # Image compression, recording and playback (native / web implementations)
│   ├── models/                # Settings, security settings, chain, contacts, conversations, messages, identity hint
│   ├── repositories/          # Read/write for each table
│   └── storage/               # Hive wrapper (including the vault key)
├── state/
│   └── controllers.dart       # Riverpod: settings / identity / session lock / security / contacts / chat / wallet
├── ui/
│   ├── router.dart            # go_router (migration → locked → unlocked redirect chain, ?peer= deep links)
│   └── shell.dart             # Responsive shell (NavigationRail / NavigationBar)
└── features/
    ├── onboarding/            # Welcome / create identity (incl. password setup) / import
    ├── lock/                  # ★ Unlock page
    ├── security/              # ★ Legacy plaintext migration page, password input widgets
    ├── chats/                 # Conversation list and chat page (text / image / voice)
    ├── contacts/              # Contacts (syncing / encrypted state)
    ├── wallet/                # Receive QR, transfer page
    ├── discover/              # Discover page and scanner (camera scanning and result dispatch)
    └── settings/              # Settings page, identity page (export requires password verification)
test/
├── vault_test.dart            # Vault: restore correctness, ciphertext contains no secrets, tampering and error codes
├── private_key_import_test.dart
├── tron_address_test.dart     # TRON address derivation and Base58Check validation
├── tron_tx_test.dart
└── widget_test.dart           # End-to-end encryption/decryption, unforgeable signatures
```

---

## 7. Tests

```bash
flutter test                   # all 40 pass
dart run tool/smoke.dart       # core-logic smoke test that does not depend on flutter_test
dart run tool/e2e_waku.dart <nodeA> <nodeB>   # end-to-end against real nodes (14 checks)
```

---

## 8. Current Limitations and Next Steps

- **Push**: new messages are currently fetched by polling every 4 seconds; moving to Filter v2 over WebSocket would make it real-time.
- **Group chat**: topics and data models are reserved; the encryption scheme is expected to move to sender keys.
- **Forward secrecy**: ephemeral X25519 keys are already used, but a Signal-style ratchet (Double Ratchet) is not implemented yet.
- **Multi-device**: the `self` copy and store lay the groundwork, but cross-device key sync and revocation are not done.
- **ENS**: registry / resolver are called directly over JSON-RPC; reverse resolution requires the address to have a reverse record set.
- **Media size**: images are compressed before going over Waku, but not sharded; large files (video) are not supported.
- **Scanning**: available on Android / iOS / macOS / web only (a mobile_scanner platform limitation);
  Windows and Linux show "scanning not supported". Decoding a QR code from a gallery image is not supported yet.
- **Web security boundary**: see 3.1 — the browser cannot defend against same-origin script injection, so only open it from a source you trust.

---

## 9. Security Notes

- The mnemonic is the **only** way to restore an identity; keep it offline. Anyone who obtains it fully controls your identity.
- **The vault password cannot be recovered.** Forgetting it means the local identity can never be unlocked again —
  you can only rebuild it by re-importing the mnemonic.
  (This is not a flaw: a recoverable password would mean a second decryption path exists that does not require you.)
- After exporting your mnemonic, store it immediately. The page hides it automatically after 30 seconds,
  but **the clipboard is not cleared automatically** — overwrite it yourself.
- This project has not undergone a third-party security audit; do not use it as-is for high-sensitivity production scenarios.
