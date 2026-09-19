import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_locale.dart';

/// 全部文案的鍵值。集中管理，避免寫死字串。
abstract final class K {
  // ------------------------------------------------------------------ 通用
  static const appName = 'appName';
  static const appTagline = 'appTagline';
  static const ok = 'ok';
  static const cancel = 'cancel';
  static const confirm = 'confirm';
  static const save = 'save';
  static const copy = 'copy';
  static const copied = 'copied';
  static const close = 'close';
  static const delete = 'delete';
  static const edit = 'edit';
  static const search = 'search';
  static const retry = 'retry';
  static const loading = 'loading';
  static const back = 'back';
  static const next = 'next';
  static const done = 'done';
  static const reveal = 'reveal';
  static const hide = 'hide';
  static const more = 'more';
  static const share = 'share';
  static const importAction = 'import';
  static const exportAction = 'export';
  static const refresh = 'refresh';
  static const send = 'send';
  static const unknown = 'unknown';
  static const optional = 'optional';
  static const comingSoon = 'comingSoon';

  // ------------------------------------------------------------------ 狀態
  static const statusOnline = 'statusOnline';
  static const statusOffline = 'statusOffline';
  static const statusConnecting = 'statusConnecting';
  static const statusConnected = 'statusConnected';
  static const statusSyncing = 'statusSyncing';
  static const statusNoPeers = 'statusNoPeers';
  static const statusNoPeersHint = 'statusNoPeersHint';

  // ---------------------------------------------------------------- 導覽列
  static const navChats = 'navChats';
  static const navContacts = 'navContacts';
  static const navWallet = 'navWallet';
  static const navSettings = 'navSettings';

  // ---------------------------------------------------------------- 引導頁
  static const onboardingTitle = 'onboardingTitle';
  static const onboardingSubtitle = 'onboardingSubtitle';
  static const onboardingCreate = 'onboardingCreate';
  static const onboardingImport = 'onboardingImport';
  static const feat1Title = 'feat1Title';
  static const feat1Desc = 'feat1Desc';
  static const feat2Title = 'feat2Title';
  static const feat2Desc = 'feat2Desc';
  static const feat3Title = 'feat3Title';
  static const feat3Desc = 'feat3Desc';

  // ------------------------------------------------------- 建立 / 匯入身份
  static const mnemonicTitle = 'mnemonicTitle';
  static const mnemonicDesc = 'mnemonicDesc';
  static const mnemonicWarn = 'mnemonicWarn';
  static const mnemonicCopied = 'mnemonicCopied';
  static const mnemonicNext = 'mnemonicNext';
  static const verifyTitle = 'verifyTitle';
  static const verifyDesc = 'verifyDesc';
  static const verifyWrong = 'verifyWrong';
  static const verifyPlaceholder = 'verifyPlaceholder';
  static const profileTitle = 'profileTitle';
  static const profileDesc = 'profileDesc';
  static const displayName = 'displayName';
  static const displayNameHint = 'displayNameHint';
  static const enterApp = 'enterApp';
  static const restoreTitle = 'restoreTitle';
  static const restoreDesc = 'restoreDesc';
  static const restoreHint = 'restoreHint';
  static const restoreError = 'restoreError';
  static const restoreSuccess = 'restoreSuccess';
  // 匯入來源切換（助記詞 / 私鑰）
  static const importModeMnemonic = 'importModeMnemonic';
  static const importModePrivateKey = 'importModePrivateKey';
  static const importPrivateKeyDesc = 'importPrivateKeyDesc';
  static const importPrivateKeyLabel = 'importPrivateKeyLabel';
  static const importPrivateKeyHint = 'importPrivateKeyHint';
  static const importPrivateKeyInvalid = 'importPrivateKeyInvalid';
  static const importPrivateKeyAddress = 'importPrivateKeyAddress';
  static const importPrivateKeyWarn = 'importPrivateKeyWarn';
  static const importPrivateKeyTitle = 'importPrivateKeyTitle';
  static const importPrivateKeySubtitle = 'importPrivateKeySubtitle';

  // --------------------------------------------------- 保險庫 / 密碼
  static const passwordLabel = 'passwordLabel';
  static const passwordHint = 'passwordHint';
  static const passwordConfirmLabel = 'passwordConfirmLabel';
  static const passwordRule = 'passwordRule';
  static const passwordWeak = 'passwordWeak';
  static const passwordFair = 'passwordFair';
  static const passwordGood = 'passwordGood';
  static const passwordStrong = 'passwordStrong';
  static const passwordWeakError = 'passwordWeakError';
  static const passwordMismatch = 'passwordMismatch';
  static const passwordSetupTitle = 'passwordSetupTitle';
  static const passwordSetupDesc = 'passwordSetupDesc';
  static const passwordForgotWarn = 'passwordForgotWarn';
  static const passwordWrong = 'passwordWrong';
  static const passwordChanged = 'passwordChanged';
  static const changePasswordFailed = 'changePasswordFailed';
  static const currentPassword = 'currentPassword';
  static const autoHideIn = 'autoHideIn';
  static const createFailed = 'createFailed';
  static const restoreFailed = 'restoreFailed';
  static const importFailed = 'importFailed';

  // ------------------------------------------------------------------ 鎖屏
  static const unlockTitle = 'unlockTitle';
  static const unlockDesc = 'unlockDesc';
  static const unlockAction = 'unlockAction';
  static const unlockWrong = 'unlockWrong';
  static const unlockCooldown = 'unlockCooldown';
  static const unlockForgot = 'unlockForgot';
  static const unlockForgotTitle = 'unlockForgotTitle';
  static const unlockForgotDesc = 'unlockForgotDesc';

  // -------------------------------------------------------- 加密遷移 / 修復
  static const migrateTitle = 'migrateTitle';
  static const migrateDesc = 'migrateDesc';
  static const migrateAction = 'migrateAction';
  static const migrateFailed = 'migrateFailed';
  static const vaultUnavailableTitle = 'vaultUnavailableTitle';
  static const vaultUnavailableDesc = 'vaultUnavailableDesc';
  static const wipe = 'wipe';
  static const wiped = 'wiped';

  // ------------------------------------------------------------ 匯出驗證
  static const exportVerifyTitle = 'exportVerifyTitle';
  static const exportVerifyDesc = 'exportVerifyDesc';

  // -------------------------------------------------------- 設定頁安全區
  static const securitySection = 'securitySection';
  static const securityLockNow = 'securityLockNow';
  static const securityLockNowDesc = 'securityLockNowDesc';
  static const securityAutoLock = 'securityAutoLock';
  static const securityAutoLockNever = 'securityAutoLockNever';
  static const securityAutoLockMinutes = 'securityAutoLockMinutes';
  static const securityHideSecrets = 'securityHideSecrets';
  static const securityHideSecretsDesc = 'securityHideSecretsDesc';
  static const securityLockOnHide = 'securityLockOnHide';
  static const securityLockOnHideDesc = 'securityLockOnHideDesc';
  static const securityChangePassword = 'securityChangePassword';
  static const securityChangePasswordDesc = 'securityChangePasswordDesc';

  // ------------------------------------------------------------------ 聊天
  static const chatTitle = 'chatTitle';
  static const chatEmpty = 'chatEmpty';
  static const chatEmptyDesc = 'chatEmptyDesc';
  static const chatHint = 'chatHint';
  static const chatEnterTip = 'chatEnterTip';
  static const chatNewMessages = 'chatNewMessages';
  static const chatEncrypted = 'chatEncrypted';
  static const chatSending = 'chatSending';
  static const chatSent = 'chatSent';
  static const chatDelivered = 'chatDelivered';
  static const chatRead = 'chatRead';
  static const chatFailed = 'chatFailed';
  static const chatToday = 'chatToday';
  static const chatYesterday = 'chatYesterday';
  static const chatNew = 'chatNew';
  static const chatSearch = 'chatSearch';
  static const chatTyping = 'chatTyping';
  static const chatDeleteTitle = 'chatDeleteTitle';
  static const chatDeleteConfirm = 'chatDeleteConfirm';
  static const chatSecureTitle = 'chatSecureTitle';
  static const chatSecureDesc = 'chatSecureDesc';
  static const chatPickContact = 'chatPickContact';
  static const chatUnread = 'chatUnread';

  // ---------------------------------------------------------------- 聯絡人
  static const contactsTitle = 'contactsTitle';
  static const contactsEmpty = 'contactsEmpty';
  static const contactsEmptyDesc = 'contactsEmptyDesc';
  static const contactsAdd = 'contactsAdd';
  static const contactsMyQr = 'contactsMyQr';
  static const contactsScanQr = 'contactsScanQr';
  static const contactsDidLabel = 'contactsDidLabel';
  static const contactsPasteDid = 'contactsPasteDid';
  static const contactsInvalidDid = 'contactsInvalidDid';
  static const contactsAdded = 'contactsAdded';
  static const contactsKeysSynced = 'contactsKeysSynced';
  static const contactsRequest = 'contactsRequest';
  static const contactsRemove = 'contactsRemove';
  static const contactsRemoveConfirm = 'contactsRemoveConfirm';
  static const contactsNickname = 'contactsNickname';
  static const contactsScanHint = 'contactsScanHint';

  // ------------------------------------------------------------------ 錢包
  static const walletTitle = 'walletTitle';
  static const walletBalance = 'walletBalance';
  static const walletNetwork = 'walletNetwork';
  static const walletAddress = 'walletAddress';
  static const walletCopy = 'walletCopy';
  static const walletExplorer = 'walletExplorer';
  static const walletRpcUrl = 'walletRpcUrl';
  static const walletChainId = 'walletChainId';
  static const walletRefresh = 'walletRefresh';
  static const walletNoRpc = 'walletNoRpc';
  static const walletEns = 'walletEns';
  static const walletDid = 'walletDid';
  static const walletTokens = 'walletTokens';
  static const walletSend = 'walletSend';
  static const walletChain = 'walletChain';
  static const walletChainDesc = 'walletChainDesc';
  static const walletTronRpc = 'walletTronRpc';
  static const walletBesuRpc = 'walletBesuRpc';
  static const chainEthereum = 'chainEthereum';
  static const chainTron = 'chainTron';
  static const chainBesu = 'chainBesu';
  static const chainSelect = 'chainSelect';
  static const walletReceive = 'walletReceive';
  static const walletSendTitle = 'walletSendTitle';
  static const walletSendTo = 'walletSendTo';
  static const walletSendToHint = 'walletSendToHint';
  static const walletAmount = 'walletAmount';
  static const walletAmountHint = 'walletAmountHint';
  static const walletAvailable = 'walletAvailable';
  static const walletSendConfirm = 'walletSendConfirm';
  static const walletSendConfirmTitle = 'walletSendConfirmTitle';
  static const walletSending = 'walletSending';
  static const walletSendSuccess = 'walletSendSuccess';
  static const walletSendFailed = 'walletSendFailed';
  static const walletTxHash = 'walletTxHash';
  static const walletViewTx = 'walletViewTx';
  static const walletErrInvalidAddress = 'walletErrInvalidAddress';
  static const walletErrInvalidAmount = 'walletErrInvalidAmount';
  static const walletErrInsufficient = 'walletErrInsufficient';
  static const walletErrNoRpc = 'walletErrNoRpc';
  static const walletErrNetwork = 'walletErrNetwork';
  static const walletReceiveDesc = 'walletReceiveDesc';
  static const walletUseMax = 'walletUseMax';

  // ------------------------------------------------------------------ 多媒體
  static const chatImage = 'chatImage';
  static const chatVoice = 'chatVoice';
  static const chatSendImage = 'chatSendImage';
  static const chatRecord = 'chatRecord';
  static const chatRecording = 'chatRecording';
  static const chatStop = 'chatStop';
  static const chatCancel = 'chatCancel';
  static const chatMediaTooLarge = 'chatMediaTooLarge';
  static const chatPermissionMicrophone = 'chatPermissionMicrophone';
  static const chatPermissionPhotos = 'chatPermissionPhotos';

  // ------------------------------------------------------------------ 設定
  static const settingsTitle = 'settingsTitle';
  static const settingsAppearance = 'settingsAppearance';
  static const settingsTheme = 'settingsTheme';
  static const settingsThemeSystem = 'settingsThemeSystem';
  static const settingsThemeLight = 'settingsThemeLight';
  static const settingsThemeDark = 'settingsThemeDark';
  static const settingsLanguage = 'settingsLanguage';
  static const settingsNetwork = 'settingsNetwork';
  static const settingsWakuNode = 'settingsWakuNode';
  static const settingsWakuTest = 'settingsWakuTest';
  static const settingsWakuOk = 'settingsWakuOk';
  static const settingsWakuFail = 'settingsWakuFail';
  static const settingsNodesDesc = 'settingsNodesDesc';
  static const settingsNodeBuiltin = 'settingsNodeBuiltin';
  static const settingsNodeCustom = 'settingsNodeCustom';
  static const settingsNodeAdd = 'settingsNodeAdd';
  static const settingsNodeAddTitle = 'settingsNodeAddTitle';
  static const settingsNodeAddHint = 'settingsNodeAddHint';
  static const settingsNodeAdded = 'settingsNodeAdded';
  static const settingsNodeRemove = 'settingsNodeRemove';
  static const settingsNodeRemoveConfirm = 'settingsNodeRemoveConfirm';
  static const settingsNodeInvalid = 'settingsNodeInvalid';
  static const settingsNodeDuplicate = 'settingsNodeDuplicate';
  static const settingsNodeChecking = 'settingsNodeChecking';
  static const settingsResync = 'settingsResync';
  static const settingsResyncDesc = 'settingsResyncDesc';
  static const settingsResyncDone = 'settingsResyncDone';
  static const settingsBackup = 'settingsBackup';
  static const settingsDelete = 'settingsDelete';
  static const settingsDeleteConfirm = 'settingsDeleteConfirm';
  static const settingsAbout = 'settingsAbout';
  static const settingsVersion = 'settingsVersion';
  static const settingsAdvanced = 'settingsAdvanced';
  static const settingsClearCache = 'settingsClearCache';
  static const settingsCacheCleared = 'settingsCacheCleared';
  static const settingsPublishKeys = 'settingsPublishKeys';
  static const settingsKeysPublished = 'settingsKeysPublished';

  // ------------------------------------------------------------------ 身份
  static const identityTitle = 'identityTitle';
  static const identityDid = 'identityDid';
  static const identityMethod = 'identityMethod';
  static const identityEthAddress = 'identityEthAddress';
  static const identitySignKey = 'identitySignKey';
  static const identityEncKey = 'identityEncKey';
  static const identityBackup = 'identityBackup';
  static const identityBackupDesc = 'identityBackupDesc';
  static const identityShowMnemonic = 'identityShowMnemonic';
  static const identityHideMnemonic = 'identityHideMnemonic';
  static const identityConfirmBackup = 'identityConfirmBackup';
  static const identityRisk = 'identityRisk';

  // ------------------------------------------------------------------ 錯誤
  static const errorGeneric = 'errorGeneric';
  static const errorNetwork = 'errorNetwork';
  static const errorInvalidInput = 'errorInvalidInput';
  static const errorCrypto = 'errorCrypto';
  static const errorNotFound = 'errorNotFound';
  static const errorTimeout = 'errorTimeout';

  // ------------------------------------------------------------------ 時間
  static const timeJustNow = 'timeJustNow';
  static const timeMinutesAgo = 'timeMinutesAgo';
  static const timeHoursAgo = 'timeHoursAgo';
}

/// 四語文案包。以 Map 存放，避免程式碼產生（codegen）依賴。
const Map<String, Map<String, String>> _bundles = {
  // ============================================================== 繁體中文
  'zh_Hant': {
    K.appName: 'NexusChat',
    K.appTagline: '去中心化 · 端到端加密 · 由你掌控',
    K.ok: '確定',
    K.cancel: '取消',
    K.confirm: '確認',
    K.save: '儲存',
    K.copy: '複製',
    K.copied: '已複製',
    K.close: '關閉',
    K.delete: '刪除',
    K.edit: '編輯',
    K.search: '搜尋',
    K.retry: '重試',
    K.loading: '載入中',
    K.back: '返回',
    K.next: '下一步',
    K.done: '完成',
    K.reveal: '顯示',
    K.hide: '隱藏',
    K.more: '更多',
    K.share: '分享',
    K.importAction: '匯入',
    K.exportAction: '匯出',
    K.refresh: '重新整理',
    K.send: '傳送',
    K.unknown: '未知',
    K.optional: '選填',
    K.comingSoon: '敬請期待',
    K.statusOnline: '線上',
    K.statusOffline: '離線',
    K.statusConnecting: '連線中',
    K.statusConnected: '已連線',
    K.statusSyncing: '同步中',
    K.statusNoPeers: '節點無 peer',
    K.statusNoPeersHint: '節點 REST 可連，但尚未連上任何 peer，訊息無法轉發。',
    K.navChats: '聊天',
    K.navContacts: '聯絡人',
    K.navWallet: '錢包',
    K.navSettings: '設定',
    K.onboardingTitle: '重新定義私密的對話',
    K.onboardingSubtitle: '沒有伺服器、沒有電話號碼，只有你的 DID 與一組助記詞。',
    K.onboardingCreate: '建立新身份',
    K.onboardingImport: '匯入既有身份',
    K.feat1Title: 'Waku 去中心化網路',
    K.feat1Desc: '訊息經由 Waku relay / store 擴散，無中心伺服器可封鎖。',
    K.feat2Title: 'DID 自主身份',
    K.feat2Desc: 'did:ethr 身份由你的以太坊金鑰派生，完全由你持有。',
    K.feat3Title: '端到端加密',
    K.feat3Desc: 'X25519 + AES-GCM，且每則訊息都有 secp256k1 簽章。',
    K.mnemonicTitle: '你的助記詞',
    K.mnemonicDesc: '這 12 個單字就是你完整的身份。請離線抄寫並妥善保存。',
    K.mnemonicWarn: '任何人取得助記詞，就能完全控制你的身份與資產。',
    K.mnemonicCopied: '助記詞已複製到剪貼簿',
    K.mnemonicNext: '我已妥善保存',
    K.verifyTitle: '驗證備份',
    K.verifyDesc: '請輸入第 %1\$s 個助記詞以確認備份正確。',
    K.verifyWrong: '不正確，請再試一次。',
    K.verifyPlaceholder: '第 %1\$s 個單字',
    K.profileTitle: '設定你的名片',
    K.profileDesc: '這個暱稱會顯示給你的聯絡人，可隨時修改。',
    K.displayName: '暱稱',
    K.displayNameHint: '例如：Satoshi',
    K.enterApp: '進入 NexusChat',
    K.restoreTitle: '匯入身份',
    K.restoreDesc: '輸入 12 或 24 個助記詞（以空格分隔）來還原你的身份。',
    K.restoreHint: 'apple banana ... 以空格分隔',
    K.restoreError: '助記詞無效，請檢查拼字與順序。',
    K.restoreSuccess: '身份已還原',
    K.importModeMnemonic: '助記詞',
    K.importModePrivateKey: '私鑰',
    K.importPrivateKeyDesc: '貼上 32 位元組的十六進位私鑰（可帶 0x 前綴）來匯入同一個帳戶。',
    K.importPrivateKeyLabel: '私鑰',
    K.importPrivateKeyHint: '0x 或 64 個十六進位字元',
    K.importPrivateKeyInvalid: '私鑰格式不正確，請確認是 64 個十六進位字元。',
    K.importPrivateKeyAddress: '對應地址',
    K.importPrivateKeyWarn: '私鑰等同帳戶所有權，請勿在不可信的裝置上輸入，也不要貼給任何人。',
    K.importPrivateKeyTitle: '匯入私鑰',
    K.importPrivateKeySubtitle: '以私鑰取代目前的身份',
    // ---------------------------------------------------- 保險庫 / 密碼
    K.passwordLabel: '密碼',
    K.passwordHint: '至少 8 個字元',
    K.passwordConfirmLabel: '確認密碼',
    K.passwordRule: '建議混用大小寫、數字與符號，並避開常見密碼。',
    K.passwordWeak: '太弱',
    K.passwordFair: '一般',
    K.passwordGood: '良好',
    K.passwordStrong: '很強',
    K.passwordWeakError: '密碼太弱，請改用更長或更複雜的密碼',
    K.passwordMismatch: '兩次輸入的密碼不一致',
    K.passwordSetupTitle: '設定保險庫密碼',
    K.passwordSetupDesc: '助記詞與私鑰會先用這組密碼加密才寫入本機，沒有密碼就拿不到。',
    K.passwordForgotWarn: '請務必記住這組密碼：它不會上傳、無法重設，忘記就只能重新建立身份。',
    K.passwordWrong: '密碼不正確',
    K.passwordChanged: '密碼已更新',
    K.changePasswordFailed: '修改密碼失敗',
    K.currentPassword: '目前密碼',
    K.autoHideIn: '將於 %1\$s 秒後自動隱藏',
    K.createFailed: '建立身份失敗',
    K.restoreFailed: '還原身份失敗',
    K.importFailed: '匯入身份失敗',
    // ------------------------------------------------------------ 鎖屏
    K.unlockTitle: '已鎖定',
    K.unlockDesc: '輸入密碼以解鎖助記詞與私鑰。',
    K.unlockAction: '解鎖',
    K.unlockWrong: '密碼不正確',
    K.unlockCooldown: '嘗試過於頻繁，請等待 %1\$s 秒',
    K.unlockForgot: '忘記密碼？',
    K.unlockForgotTitle: '密碼無法重設',
    K.unlockForgotDesc: '密碼只用於本機解密，系統沒有留存任何可重設的憑證。若真的忘記，只能清除本機資料並用助記詞重新匯入。',
    // -------------------------------------------------- 加密遷移 / 修復
    K.migrateTitle: '加密你的身份',
    K.migrateDesc: '這個裝置上的助記詞與私鑰目前是明文存放，任何能讀取本機儲存的程式都能直接取得。請設定一組密碼，改為加密存放。',
    K.migrateAction: '加密並繼續',
    K.migrateFailed: '加密失敗，請再試一次',
    K.vaultUnavailableTitle: '無法讀取身份資料',
    K.vaultUnavailableDesc: '本機的身份資料結構異常，無法解密。若你有助記詞備份，可以清除後重新匯入。',
    K.wipe: '清除本機資料',
    K.wiped: '本機資料已清除',
    // ------------------------------------------------------ 匯出驗證
    K.exportVerifyTitle: '驗證身份',
    K.exportVerifyDesc: '顯示助記詞或私鑰前，請先輸入保險庫密碼。',
    // -------------------------------------------------- 設定頁安全區
    K.securitySection: '安全',
    K.securityLockNow: '立即鎖定',
    K.securityLockNowDesc: '清除記憶體中的助記詞與私鑰',
    K.securityAutoLock: '自動鎖定',
    K.securityAutoLockNever: '永不',
    K.securityAutoLockMinutes: '%1\$s 分鐘',
    K.securityHideSecrets: '敏感內容自動隱藏',
    K.securityHideSecretsDesc: '顯示助記詞後自動隱藏的時間',
    K.securityLockOnHide: '切換分頁時鎖定',
    K.securityLockOnHideDesc: '離開目前分頁立即鎖定',
    K.securityChangePassword: '修改密碼',
    K.securityChangePasswordDesc: '重新加密保險庫',
    K.chatTitle: '聊天',
    K.chatEmpty: '還沒有任何對話',
    K.chatEmptyDesc: '到「聯絡人」加入你的第一個去中心化好友。',
    K.chatHint: '輸入訊息…',
    K.chatEnterTip: 'Shift+Enter 傳送 · Enter 換行',
    K.chatNewMessages: '新訊息',
    K.chatEncrypted: '端到端加密',
    K.chatSending: '傳送中',
    K.chatSent: '已傳送',
    K.chatDelivered: '已送達',
    K.chatRead: '已讀',
    K.chatFailed: '傳送失敗',
    K.chatToday: '今天',
    K.chatYesterday: '昨天',
    K.chatNew: '新訊息',
    K.chatSearch: '搜尋對話或 DID',
    K.chatTyping: '正在輸入…',
    K.chatDeleteTitle: '刪除對話',
    K.chatDeleteConfirm: '確定要刪除與 %1\$s 的對話嗎？此動作無法復原。',
    K.chatSecureTitle: '這段對話是私密的',
    K.chatSecureDesc: '訊息在裝置上加密後才送入 Waku 網路，只有對方持有金鑰能解密。',
    K.chatPickContact: '選擇一位聯絡人開始對話',
    K.chatUnread: '未讀',
    K.contactsTitle: '聯絡人',
    K.contactsEmpty: '尚無聯絡人',
    K.contactsEmptyDesc: '用 DID、以太坊地址或 ENS 加入好友。',
    K.contactsAdd: '新增聯絡人',
    K.contactsMyQr: '我的 QR Code',
    K.contactsScanQr: '掃描 QR Code',
    K.contactsDidLabel: 'DID / 地址 / ENS',
    K.contactsPasteDid: '貼上 DID、0x 地址或 ENS 名稱',
    K.contactsInvalidDid: '格式無法辨識，請確認後再試。',
    K.contactsAdded: '已加入聯絡人',
    K.contactsKeysSynced: '已同步加密金鑰',
    K.contactsRequest: '好友邀請',
    K.contactsRemove: '移除聯絡人',
    K.contactsRemoveConfirm: '確定移除 %1\$s 嗎？',
    K.contactsNickname: '備註名稱',
    K.contactsScanHint: '掃描對方的 NexusChat QR Code（目前版本亦可直接貼上）',
    K.walletTitle: '錢包',
    K.walletBalance: '餘額',
    K.walletNetwork: '網路',
    K.walletAddress: '地址',
    K.walletCopy: '複製地址',
    K.walletExplorer: '在區塊瀏覽器檢視',
    K.walletRpcUrl: 'RPC 端點',
    K.walletChainId: 'Chain ID',
    K.walletRefresh: '重新整理餘額',
    K.walletNoRpc: '尚未設定 RPC 端點，餘額無法查詢。',
    K.walletEns: 'ENS 名稱',
    K.walletDid: 'DID',
    K.walletTokens: '資產',
    K.walletSend: '轉帳',
    K.walletChain: '區塊鏈',
    K.walletChainDesc: '僅切換錢包頁顯示的鏈；聊天身份仍為 did:ethr，不受影響。',
    K.walletTronRpc: 'TRON RPC 端點',
    K.walletBesuRpc: 'WEB6 RPC 端點',
    K.chainEthereum: '以太坊',
    K.chainTron: '波場',
    K.chainBesu: 'WEB6',
    K.walletReceive: '收款',
    K.walletSendTitle: '轉帳',
    K.walletSendTo: '收款地址',
    K.walletSendToHint: '貼上或輸入收款地址',
    K.walletAmount: '金額',
    K.walletAmountHint: '0.0',
    K.walletAvailable: '可用餘額',
    K.walletSendConfirm: '確認轉帳',
    K.walletSendConfirmTitle: '請確認轉帳資訊',
    K.walletSending: '正在送出交易…',
    K.walletSendSuccess: '轉帳已送出',
    K.walletSendFailed: '轉帳失敗',
    K.walletTxHash: '交易雜湊',
    K.walletViewTx: '在區塊鏈瀏覽器查看',
    K.walletErrInvalidAddress: '收款地址格式不正確',
    K.walletErrInvalidAmount: '請輸入大於 0 的金額',
    K.walletErrInsufficient: '餘額不足（含手續費）',
    K.walletErrNoRpc: '尚未設定 RPC 端點',
    K.walletErrNetwork: '網路錯誤，請稍後再試',
    K.walletReceiveDesc: '將此地址或 QR Code 分享給對方即可收款',
    K.walletUseMax: '全部',
    K.chatImage: '圖片',
    K.chatVoice: '語音訊息',
    K.chatSendImage: '傳送圖片',
    K.chatRecord: '錄音',
    K.chatRecording: '錄音中…',
    K.chatStop: '停止',
    K.chatCancel: '取消',
    K.chatMediaTooLarge: '媒體過大，請選擇較小的圖片或縮短錄音長度。',
    K.chatPermissionMicrophone: '需要麥克風權限才能錄音。',
    K.chatPermissionPhotos: '需要相簿權限才能選取圖片。',
    K.settingsTitle: '設定',
    K.settingsAppearance: '外觀',
    K.settingsTheme: '主題',
    K.settingsThemeSystem: '跟隨系統',
    K.settingsThemeLight: '日間',
    K.settingsThemeDark: '夜間',
    K.settingsLanguage: '語言',
    K.settingsNetwork: '網路',
    K.settingsWakuNode: 'Waku 節點',
    K.settingsWakuTest: '重新偵測',
    K.settingsWakuOk: '可連線',
    K.settingsWakuFail: '無法連線',
    K.settingsNodesDesc: '訊息只會透過選取的節點收發，點選節點即可切換；內建節點無法移除。',
    K.settingsNodeBuiltin: '內建',
    K.settingsNodeCustom: '自訂',
    K.settingsNodeAdd: '新增節點',
    K.settingsNodeAddTitle: '新增 Waku 節點',
    K.settingsNodeAddHint: '例如 https://waku03.example.com',
    K.settingsNodeAdded: '已新增節點',
    K.settingsNodeRemove: '移除節點',
    K.settingsNodeRemoveConfirm: '確定移除 %1\$s 嗎？',
    K.settingsNodeInvalid: '節點位址無效',
    K.settingsNodeDuplicate: '此節點已存在',
    K.settingsNodeChecking: '偵測中',
    K.settingsResync: '重新拉取歷史訊息',
    K.settingsResyncDesc: '從節點的 store 補拉最近 48 小時內錯過的訊息與金鑰包',
    K.settingsResyncDone: '已重新拉取',
    K.settingsBackup: '備份身份',
    K.settingsDelete: '刪除此裝置上的身份',
    K.settingsDeleteConfirm: '這會清除本機身份與所有對話，且無法復原。確定嗎？',
    K.settingsAbout: '關於',
    K.settingsVersion: '版本',
    K.settingsAdvanced: '進階',
    K.settingsClearCache: '清除快取',
    K.settingsCacheCleared: '快取已清除',
    K.settingsPublishKeys: '重新發布金鑰包',
    K.settingsKeysPublished: '金鑰包已發布到 Waku',
    K.identityTitle: '我的身份',
    K.identityDid: '去中心化識別碼',
    K.identityMethod: 'DID Method',
    K.identityEthAddress: '以太坊地址',
    K.identitySignKey: '簽章公鑰',
    K.identityEncKey: '加密公鑰',
    K.identityBackup: '備份助記詞',
    K.identityBackupDesc: '助記詞是唯一能還原身份的方式，請離線保存。',
    K.identityShowMnemonic: '顯示助記詞',
    K.identityHideMnemonic: '隱藏助記詞',
    K.identityConfirmBackup: '我已保存助記詞',
    K.identityRisk: '風險提示',
    K.errorGeneric: '發生錯誤，請稍後再試。',
    K.errorNetwork: '網路連線失敗',
    K.errorInvalidInput: '輸入內容有誤',
    K.errorCrypto: '加密或解密失敗',
    K.errorNotFound: '找不到資料',
    K.errorTimeout: '連線逾時',
    K.timeJustNow: '剛剛',
    K.timeMinutesAgo: '%1\$d 分鐘前',
    K.timeHoursAgo: '%1\$d 小時前',
  },

  // ============================================================== 简体中文
  'zh_Hans': {
    K.appName: 'NexusChat',
    K.appTagline: '去中心化 · 端到端加密 · 由你掌控',
    K.ok: '确定',
    K.cancel: '取消',
    K.confirm: '确认',
    K.save: '保存',
    K.copy: '复制',
    K.copied: '已复制',
    K.close: '关闭',
    K.delete: '删除',
    K.edit: '编辑',
    K.search: '搜索',
    K.retry: '重试',
    K.loading: '加载中',
    K.back: '返回',
    K.next: '下一步',
    K.done: '完成',
    K.reveal: '显示',
    K.hide: '隐藏',
    K.more: '更多',
    K.share: '分享',
    K.importAction: '导入',
    K.exportAction: '导出',
    K.refresh: '刷新',
    K.send: '发送',
    K.unknown: '未知',
    K.optional: '选填',
    K.comingSoon: '敬请期待',
    K.statusOnline: '在线',
    K.statusOffline: '离线',
    K.statusConnecting: '连接中',
    K.statusConnected: '已连接',
    K.statusSyncing: '同步中',
    K.statusNoPeers: '节点无 peer',
    K.statusNoPeersHint: '节点 REST 可连，但尚未连上任何 peer，消息无法转发。',
    K.navChats: '聊天',
    K.navContacts: '联系人',
    K.navWallet: '钱包',
    K.navSettings: '设置',
    K.onboardingTitle: '重新定义私密的对话',
    K.onboardingSubtitle: '没有服务器、没有手机号，只有你的 DID 与一组助记词。',
    K.onboardingCreate: '创建新身份',
    K.onboardingImport: '导入已有身份',
    K.feat1Title: 'Waku 去中心化网络',
    K.feat1Desc: '消息经由 Waku relay / store 扩散，无中心服务器可封锁。',
    K.feat2Title: 'DID 自主身份',
    K.feat2Desc: 'did:ethr 身份由你的以太坊密钥派生，完全由你持有。',
    K.feat3Title: '端到端加密',
    K.feat3Desc: 'X25519 + AES-GCM，且每条消息都有 secp256k1 签名。',
    K.mnemonicTitle: '你的助记词',
    K.mnemonicDesc: '这 12 个单词就是你完整的身份。请离线抄写并妥善保存。',
    K.mnemonicWarn: '任何人取得助记词，就能完全控制你的身份与资产。',
    K.mnemonicCopied: '助记词已复制到剪贴板',
    K.mnemonicNext: '我已妥善保存',
    K.verifyTitle: '验证备份',
    K.verifyDesc: '请输入第 %1\$s 个助记词以确认备份正确。',
    K.verifyWrong: '不正确，请再试一次。',
    K.verifyPlaceholder: '第 %1\$s 个单词',
    K.profileTitle: '设置你的名片',
    K.profileDesc: '这个昵称会显示给你的联系人，可随时修改。',
    K.displayName: '昵称',
    K.displayNameHint: '例如：Satoshi',
    K.enterApp: '进入 NexusChat',
    K.restoreTitle: '导入身份',
    K.restoreDesc: '输入 12 或 24 个助记词（以空格分隔）来还原你的身份。',
    K.restoreHint: 'apple banana ... 以空格分隔',
    K.restoreError: '助记词无效，请检查拼写与顺序。',
    K.restoreSuccess: '身份已还原',
    K.importModeMnemonic: '助记词',
    K.importModePrivateKey: '私钥',
    K.importPrivateKeyDesc: '粘贴 32 字节的十六进制私钥（可带 0x 前缀）来导入同一个账户。',
    K.importPrivateKeyLabel: '私钥',
    K.importPrivateKeyHint: '0x 或 64 个十六进制字符',
    K.importPrivateKeyInvalid: '私钥格式不正确，请确认是 64 个十六进制字符。',
    K.importPrivateKeyAddress: '对应地址',
    K.importPrivateKeyWarn: '私钥等同于账户所有权，请勿在不可信的设备上输入，也不要发给任何人。',
    K.importPrivateKeyTitle: '导入私钥',
    K.importPrivateKeySubtitle: '以私钥替换当前身份',
    // ---------------------------------------------------- 保险库 / 密码
    K.passwordLabel: '密码',
    K.passwordHint: '至少 8 个字符',
    K.passwordConfirmLabel: '确认密码',
    K.passwordRule: '建议混用大小写、数字与符号，并避开常见密码。',
    K.passwordWeak: '太弱',
    K.passwordFair: '一般',
    K.passwordGood: '良好',
    K.passwordStrong: '很强',
    K.passwordWeakError: '密码太弱，请改用更长或更复杂的密码',
    K.passwordMismatch: '两次输入的密码不一致',
    K.passwordSetupTitle: '设置保险库密码',
    K.passwordSetupDesc: '助记词与私钥会先用这组密码加密才写入本机，没有密码就拿不到。',
    K.passwordForgotWarn: '请务必记住这组密码：它不会上传、无法重置，忘记就只能重新创建身份。',
    K.passwordWrong: '密码不正确',
    K.passwordChanged: '密码已更新',
    K.changePasswordFailed: '修改密码失败',
    K.currentPassword: '当前密码',
    K.autoHideIn: '将于 %1\$s 秒后自动隐藏',
    K.createFailed: '创建身份失败',
    K.restoreFailed: '恢复身份失败',
    K.importFailed: '导入身份失败',
    // ------------------------------------------------------------ 锁屏
    K.unlockTitle: '已锁定',
    K.unlockDesc: '输入密码以解锁助记词与私钥。',
    K.unlockAction: '解锁',
    K.unlockWrong: '密码不正确',
    K.unlockCooldown: '尝试过于频繁，请等待 %1\$s 秒',
    K.unlockForgot: '忘记密码？',
    K.unlockForgotTitle: '密码无法重置',
    K.unlockForgotDesc: '密码只用于本机解密，系统没有留存任何可重置的凭证。若真的忘记，只能清除本机数据并用助记词重新导入。',
    // -------------------------------------------------- 加密迁移 / 修复
    K.migrateTitle: '加密你的身份',
    K.migrateDesc: '这个设备上的助记词与私钥目前是明文存放，任何能读取本机存储的程序都能直接取得。请设置一组密码，改为加密存放。',
    K.migrateAction: '加密并继续',
    K.migrateFailed: '加密失败，请再试一次',
    K.vaultUnavailableTitle: '无法读取身份数据',
    K.vaultUnavailableDesc: '本机的身份数据结构异常，无法解密。若你有助记词备份，可以清除后重新导入。',
    K.wipe: '清除本机数据',
    K.wiped: '本机数据已清除',
    // ------------------------------------------------------ 导出验证
    K.exportVerifyTitle: '验证身份',
    K.exportVerifyDesc: '显示助记词或私钥前，请先输入保险库密码。',
    // -------------------------------------------------- 设置页安全区
    K.securitySection: '安全',
    K.securityLockNow: '立即锁定',
    K.securityLockNowDesc: '清除内存中的助记词与私钥',
    K.securityAutoLock: '自动锁定',
    K.securityAutoLockNever: '永不',
    K.securityAutoLockMinutes: '%1\$s 分钟',
    K.securityHideSecrets: '敏感内容自动隐藏',
    K.securityHideSecretsDesc: '显示助记词后自动隐藏的时间',
    K.securityLockOnHide: '切换标签页时锁定',
    K.securityLockOnHideDesc: '离开当前标签页立即锁定',
    K.securityChangePassword: '修改密码',
    K.securityChangePasswordDesc: '重新加密保险库',
    K.chatTitle: '聊天',
    K.chatEmpty: '还没有任何对话',
    K.chatEmptyDesc: '到「联系人」加入你的第一个去中心化好友。',
    K.chatHint: '输入消息…',
    K.chatEnterTip: 'Shift+Enter 发送 · Enter 换行',
    K.chatNewMessages: '新消息',
    K.chatEncrypted: '端到端加密',
    K.chatSending: '发送中',
    K.chatSent: '已发送',
    K.chatDelivered: '已送达',
    K.chatRead: '已读',
    K.chatFailed: '发送失败',
    K.chatToday: '今天',
    K.chatYesterday: '昨天',
    K.chatNew: '新消息',
    K.chatSearch: '搜索对话或 DID',
    K.chatTyping: '正在输入…',
    K.chatDeleteTitle: '删除对话',
    K.chatDeleteConfirm: '确定要删除与 %1\$s 的对话吗？此操作无法复原。',
    K.chatSecureTitle: '这段对话是私密的',
    K.chatSecureDesc: '消息在设备上加密后才送入 Waku 网络，只有对方持有密钥能解密。',
    K.chatPickContact: '选择一位联系人开始对话',
    K.chatUnread: '未读',
    K.contactsTitle: '联系人',
    K.contactsEmpty: '暂无联系人',
    K.contactsEmptyDesc: '用 DID、以太坊地址或 ENS 加入好友。',
    K.contactsAdd: '新增联系人',
    K.contactsMyQr: '我的二维码',
    K.contactsScanQr: '扫描二维码',
    K.contactsDidLabel: 'DID / 地址 / ENS',
    K.contactsPasteDid: '粘贴 DID、0x 地址或 ENS 名称',
    K.contactsInvalidDid: '格式无法识别，请确认后再试。',
    K.contactsAdded: '已加入联系人',
    K.contactsKeysSynced: '已同步加密密钥',
    K.contactsRequest: '好友邀请',
    K.contactsRemove: '移除联系人',
    K.contactsRemoveConfirm: '确定移除 %1\$s 吗？',
    K.contactsNickname: '备注名称',
    K.contactsScanHint: '扫描对方的 NexusChat 二维码（当前版本亦可直接粘贴）',
    K.walletTitle: '钱包',
    K.walletBalance: '余额',
    K.walletNetwork: '网络',
    K.walletAddress: '地址',
    K.walletCopy: '复制地址',
    K.walletExplorer: '在区块浏览器查看',
    K.walletRpcUrl: 'RPC 端点',
    K.walletChainId: 'Chain ID',
    K.walletRefresh: '刷新余额',
    K.walletNoRpc: '尚未设置 RPC 端点，余额无法查询。',
    K.walletEns: 'ENS 名称',
    K.walletDid: 'DID',
    K.walletTokens: '资产',
    K.walletSend: '转账',
    K.walletChain: '区块链',
    K.walletChainDesc: '仅切换钱包页显示的链；聊天身份仍为 did:ethr，不受影响。',
    K.walletTronRpc: 'TRON RPC 端点',
    K.walletBesuRpc: 'WEB6 RPC 端点',
    K.chainEthereum: '以太坊',
    K.chainTron: '波场',
    K.chainBesu: 'WEB6',
    K.walletReceive: '收款',
    K.walletSendTitle: '转账',
    K.walletSendTo: '收款地址',
    K.walletSendToHint: '粘贴或输入收款地址',
    K.walletAmount: '金额',
    K.walletAmountHint: '0.0',
    K.walletAvailable: '可用余额',
    K.walletSendConfirm: '确认转账',
    K.walletSendConfirmTitle: '请确认转账信息',
    K.walletSending: '正在发送交易…',
    K.walletSendSuccess: '转账已发送',
    K.walletSendFailed: '转账失败',
    K.walletTxHash: '交易哈希',
    K.walletViewTx: '在区块链浏览器查看',
    K.walletErrInvalidAddress: '收款地址格式不正确',
    K.walletErrInvalidAmount: '请输入大于 0 的金额',
    K.walletErrInsufficient: '余额不足（含手续费）',
    K.walletErrNoRpc: '尚未设置 RPC 端点',
    K.walletErrNetwork: '网络错误，请稍后再试',
    K.walletReceiveDesc: '将此地址或二维码分享给对方即可收款',
    K.walletUseMax: '全部',
    K.chatImage: '图片',
    K.chatVoice: '语音消息',
    K.chatSendImage: '发送图片',
    K.chatRecord: '录音',
    K.chatRecording: '录音中…',
    K.chatStop: '停止',
    K.chatCancel: '取消',
    K.chatMediaTooLarge: '媒体过大，请选择较小的图片或缩短录音长度。',
    K.chatPermissionMicrophone: '需要麦克风权限才能录音。',
    K.chatPermissionPhotos: '需要相册权限才能选取图片。',
    K.settingsTitle: '设置',
    K.settingsAppearance: '外观',
    K.settingsTheme: '主题',
    K.settingsThemeSystem: '跟随系统',
    K.settingsThemeLight: '日间',
    K.settingsThemeDark: '夜间',
    K.settingsLanguage: '语言',
    K.settingsNetwork: '网络',
    K.settingsWakuNode: 'Waku 节点',
    K.settingsWakuTest: '重新检测',
    K.settingsWakuOk: '可连接',
    K.settingsWakuFail: '无法连接',
    K.settingsNodesDesc: '消息只会通过选中的节点收发，点选节点即可切换；内置节点无法移除。',
    K.settingsNodeBuiltin: '内置',
    K.settingsNodeCustom: '自定义',
    K.settingsNodeAdd: '添加节点',
    K.settingsNodeAddTitle: '添加 Waku 节点',
    K.settingsNodeAddHint: '例如 https://waku03.example.com',
    K.settingsNodeAdded: '已添加节点',
    K.settingsNodeRemove: '移除节点',
    K.settingsNodeRemoveConfirm: '确定移除 %1\$s 吗？',
    K.settingsNodeInvalid: '节点地址无效',
    K.settingsNodeDuplicate: '该节点已存在',
    K.settingsNodeChecking: '检测中',
    K.settingsResync: '重新拉取历史消息',
    K.settingsResyncDesc: '从节点的 store 补拉最近 48 小时内错过的消息与密钥包',
    K.settingsResyncDone: '已重新拉取',
    K.settingsBackup: '备份身份',
    K.settingsDelete: '删除此设备上的身份',
    K.settingsDeleteConfirm: '这会清除本机身份与所有对话，且无法复原。确定吗？',
    K.settingsAbout: '关于',
    K.settingsVersion: '版本',
    K.settingsAdvanced: '进阶',
    K.settingsClearCache: '清除缓存',
    K.settingsCacheCleared: '缓存已清除',
    K.settingsPublishKeys: '重新发布密钥包',
    K.settingsKeysPublished: '密钥包已发布到 Waku',
    K.identityTitle: '我的身份',
    K.identityDid: '去中心化识别码',
    K.identityMethod: 'DID Method',
    K.identityEthAddress: '以太坊地址',
    K.identitySignKey: '签名公钥',
    K.identityEncKey: '加密公钥',
    K.identityBackup: '备份助记词',
    K.identityBackupDesc: '助记词是唯一能还原身份的方式，请离线保存。',
    K.identityShowMnemonic: '显示助记词',
    K.identityHideMnemonic: '隐藏助记词',
    K.identityConfirmBackup: '我已保存助记词',
    K.identityRisk: '风险提示',
    K.errorGeneric: '发生错误，请稍后再试。',
    K.errorNetwork: '网络连接失败',
    K.errorInvalidInput: '输入内容有误',
    K.errorCrypto: '加密或解密失败',
    K.errorNotFound: '找不到数据',
    K.errorTimeout: '连接超时',
    K.timeJustNow: '刚刚',
    K.timeMinutesAgo: '%1\$d 分钟前',
    K.timeHoursAgo: '%1\$d 小时前',
  },

  // ================================================================= English
  'en': {
    K.appName: 'NexusChat',
    K.appTagline: 'Decentralized · End-to-end encrypted · Yours alone',
    K.ok: 'OK',
    K.cancel: 'Cancel',
    K.confirm: 'Confirm',
    K.save: 'Save',
    K.copy: 'Copy',
    K.copied: 'Copied',
    K.close: 'Close',
    K.delete: 'Delete',
    K.edit: 'Edit',
    K.search: 'Search',
    K.retry: 'Retry',
    K.loading: 'Loading',
    K.back: 'Back',
    K.next: 'Next',
    K.done: 'Done',
    K.reveal: 'Show',
    K.hide: 'Hide',
    K.more: 'More',
    K.share: 'Share',
    K.importAction: 'Import',
    K.exportAction: 'Export',
    K.refresh: 'Refresh',
    K.send: 'Send',
    K.unknown: 'Unknown',
    K.optional: 'Optional',
    K.comingSoon: 'Coming soon',
    K.statusOnline: 'Online',
    K.statusOffline: 'Offline',
    K.statusConnecting: 'Connecting',
    K.statusConnected: 'Connected',
    K.statusSyncing: 'Syncing',
    K.statusNoPeers: 'No peers',
    K.statusNoPeersHint:
        'The node REST is reachable but it has no peers, so messages cannot be relayed.',
    K.navChats: 'Chats',
    K.navContacts: 'Contacts',
    K.navWallet: 'Wallet',
    K.navSettings: 'Settings',
    K.onboardingTitle: 'Private conversations, reimagined',
    K.onboardingSubtitle:
        'No server, no phone number. Just your DID and one recovery phrase.',
    K.onboardingCreate: 'Create a new identity',
    K.onboardingImport: 'Import an existing identity',
    K.feat1Title: 'Waku decentralized network',
    K.feat1Desc:
        'Messages spread through Waku relay / store — nothing central to shut down.',
    K.feat2Title: 'Self-sovereign DID',
    K.feat2Desc:
        'A did:ethr identity derived from your Ethereum key, held only by you.',
    K.feat3Title: 'End-to-end encryption',
    K.feat3Desc:
        'X25519 + AES-GCM, and every message carries a secp256k1 signature.',
    K.mnemonicTitle: 'Your recovery phrase',
    K.mnemonicDesc:
        'These 12 words are your entire identity. Write them down offline.',
    K.mnemonicWarn:
        'Anyone with this phrase takes full control of your identity.',
    K.mnemonicCopied: 'Recovery phrase copied',
    K.mnemonicNext: 'I have saved it',
    K.verifyTitle: 'Verify your backup',
    K.verifyDesc: 'Enter word #%1\$s to confirm your backup is correct.',
    K.verifyWrong: 'That is not right, please try again.',
    K.verifyPlaceholder: 'Word #%1\$s',
    K.profileTitle: 'Set up your card',
    K.profileDesc: 'This nickname is shown to your contacts. Change it anytime.',
    K.displayName: 'Nickname',
    K.displayNameHint: 'e.g. Satoshi',
    K.enterApp: 'Enter NexusChat',
    K.restoreTitle: 'Import identity',
    K.restoreDesc:
        'Enter your 12 or 24 word recovery phrase, separated by spaces.',
    K.restoreHint: 'apple banana ... space separated',
    K.restoreError: 'Invalid recovery phrase. Check spelling and order.',
    K.restoreSuccess: 'Identity restored',
    K.importModeMnemonic: 'Recovery phrase',
    K.importModePrivateKey: 'Private key',
    K.importPrivateKeyDesc:
        'Paste a 32-byte hexadecimal private key (0x prefix optional) to import the same account.',
    K.importPrivateKeyLabel: 'Private key',
    K.importPrivateKeyHint: '0x or 64 hex characters',
    K.importPrivateKeyInvalid:
        'Invalid private key. Make sure it is 64 hexadecimal characters.',
    K.importPrivateKeyAddress: 'Derived address',
    K.importPrivateKeyWarn:
        'A private key grants full control of the account. Never enter it on an untrusted device or share it with anyone.',
    K.importPrivateKeyTitle: 'Import private key',
    K.importPrivateKeySubtitle: 'Replace the current identity with a private key',
    // -------------------------------------------------------- Vault / password
    K.passwordLabel: 'Password',
    K.passwordHint: 'At least 8 characters',
    K.passwordConfirmLabel: 'Confirm password',
    K.passwordRule: 'Mix upper and lower case, digits and symbols; avoid common passwords.',
    K.passwordWeak: 'Too weak',
    K.passwordFair: 'Fair',
    K.passwordGood: 'Good',
    K.passwordStrong: 'Strong',
    K.passwordWeakError: 'Password is too weak — use a longer or more complex one',
    K.passwordMismatch: 'The two passwords do not match',
    K.passwordSetupTitle: 'Set a vault password',
    K.passwordSetupDesc:
        'Your mnemonic and private key are encrypted with this password before they are stored locally.',
    K.passwordForgotWarn:
        'Remember this password. It is never uploaded and cannot be reset — if you lose it, you must create a new identity.',
    K.passwordWrong: 'Incorrect password',
    K.passwordChanged: 'Password updated',
    K.changePasswordFailed: 'Could not change the password',
    K.currentPassword: 'Current password',
    K.autoHideIn: 'Hiding automatically in %1\$ss',
    K.createFailed: 'Could not create the identity',
    K.restoreFailed: 'Could not restore the identity',
    K.importFailed: 'Could not import the identity',
    // ---------------------------------------------------------------- Lock screen
    K.unlockTitle: 'Locked',
    K.unlockDesc: 'Enter your password to unlock the mnemonic and private key.',
    K.unlockAction: 'Unlock',
    K.unlockWrong: 'Incorrect password',
    K.unlockCooldown: 'Too many attempts — wait %1\$ss',
    K.unlockForgot: 'Forgot password?',
    K.unlockForgotTitle: 'The password cannot be reset',
    K.unlockForgotDesc:
        'The password is only used for local decryption and no reset credential is kept. If you truly lost it, you must erase this device and re-import with your mnemonic.',
    // --------------------------------------------------- Migration / recovery
    K.migrateTitle: 'Encrypt your identity',
    K.migrateDesc:
        'The mnemonic and private key on this device are currently stored in plain text, readable by any program that can access local storage. Set a password to switch them to encrypted storage.',
    K.migrateAction: 'Encrypt and continue',
    K.migrateFailed: 'Encryption failed — please try again',
    K.vaultUnavailableTitle: 'Cannot read identity data',
    K.vaultUnavailableDesc:
        'The local identity data is malformed and cannot be decrypted. If you have your mnemonic backup, you can erase and re-import.',
    K.wipe: 'Erase local data',
    K.wiped: 'Local data erased',
    // ------------------------------------------------------------ Export guard
    K.exportVerifyTitle: 'Verify your identity',
    K.exportVerifyDesc:
        'Enter your vault password before the mnemonic or private key is shown.',
    // ------------------------------------------------------ Settings security
    K.securitySection: 'Security',
    K.securityLockNow: 'Lock now',
    K.securityLockNowDesc: 'Clear the mnemonic and private key from memory',
    K.securityAutoLock: 'Auto-lock',
    K.securityAutoLockNever: 'Never',
    K.securityAutoLockMinutes: '%1\$s min',
    K.securityHideSecrets: 'Auto-hide secrets',
    K.securityHideSecretsDesc: 'How long the mnemonic stays visible',
    K.securityLockOnHide: 'Lock when leaving the tab',
    K.securityLockOnHideDesc: 'Lock immediately when the tab loses focus',
    K.securityChangePassword: 'Change password',
    K.securityChangePasswordDesc: 'Re-encrypt the vault',
    K.chatTitle: 'Chats',
    K.chatEmpty: 'No conversations yet',
    K.chatEmptyDesc:
        'Head to Contacts to add your first decentralized friend.',
    K.chatHint: 'Type a message…',
    K.chatEnterTip: 'Shift+Enter to send · Enter for a new line',
    K.chatNewMessages: 'New messages',
    K.chatEncrypted: 'End-to-end encrypted',
    K.chatSending: 'Sending',
    K.chatSent: 'Sent',
    K.chatDelivered: 'Delivered',
    K.chatRead: 'Read',
    K.chatFailed: 'Failed',
    K.chatToday: 'Today',
    K.chatYesterday: 'Yesterday',
    K.chatNew: 'New',
    K.chatSearch: 'Search chats or DID',
    K.chatTyping: 'typing…',
    K.chatDeleteTitle: 'Delete conversation',
    K.chatDeleteConfirm:
        'Delete the conversation with %1\$s? This cannot be undone.',
    K.chatSecureTitle: 'This conversation is private',
    K.chatSecureDesc:
        'Messages are encrypted on device before entering the Waku network.',
    K.chatPickContact: 'Pick a contact to start chatting',
    K.chatUnread: 'Unread',
    K.contactsTitle: 'Contacts',
    K.contactsEmpty: 'No contacts yet',
    K.contactsEmptyDesc: 'Add a friend by DID, Ethereum address or ENS name.',
    K.contactsAdd: 'Add contact',
    K.contactsMyQr: 'My QR code',
    K.contactsScanQr: 'Scan QR code',
    K.contactsDidLabel: 'DID / address / ENS',
    K.contactsPasteDid: 'Paste a DID, 0x address or ENS name',
    K.contactsInvalidDid: 'Unrecognized format, please check and retry.',
    K.contactsAdded: 'Contact added',
    K.contactsKeysSynced: 'Encryption keys synced',
    K.contactsRequest: 'Friend request',
    K.contactsRemove: 'Remove contact',
    K.contactsRemoveConfirm: 'Remove %1\$s?',
    K.contactsNickname: 'Nickname',
    K.contactsScanHint:
        'Scan a NexusChat QR code (pasting the value works too in this build)',
    K.walletTitle: 'Wallet',
    K.walletBalance: 'Balance',
    K.walletNetwork: 'Network',
    K.walletAddress: 'Address',
    K.walletCopy: 'Copy address',
    K.walletExplorer: 'View on explorer',
    K.walletRpcUrl: 'RPC endpoint',
    K.walletChainId: 'Chain ID',
    K.walletRefresh: 'Refresh balance',
    K.walletNoRpc: 'No RPC endpoint configured, balance unavailable.',
    K.walletEns: 'ENS name',
    K.walletDid: 'DID',
    K.walletTokens: 'Assets',
    K.walletSend: 'Transfer',
    K.walletChain: 'Blockchain',
    K.walletChainDesc:
        'Only switches which chain the wallet shows; the chat identity stays did:ethr.',
    K.walletTronRpc: 'TRON RPC endpoint',
    K.walletBesuRpc: 'WEB6 RPC endpoint',
    K.chainEthereum: 'Ethereum',
    K.chainTron: 'TRON',
    K.chainBesu: 'WEB6',
    K.walletReceive: 'Receive',
    K.walletSendTitle: 'Send',
    K.walletSendTo: 'Recipient address',
    K.walletSendToHint: 'Paste or type a recipient address',
    K.walletAmount: 'Amount',
    K.walletAmountHint: '0.0',
    K.walletAvailable: 'Available',
    K.walletSendConfirm: 'Confirm transfer',
    K.walletSendConfirmTitle: 'Review transfer details',
    K.walletSending: 'Broadcasting transaction…',
    K.walletSendSuccess: 'Transfer sent',
    K.walletSendFailed: 'Transfer failed',
    K.walletTxHash: 'Transaction hash',
    K.walletViewTx: 'View in block explorer',
    K.walletErrInvalidAddress: 'Invalid recipient address',
    K.walletErrInvalidAmount: 'Enter an amount greater than 0',
    K.walletErrInsufficient: 'Insufficient balance (including fees)',
    K.walletErrNoRpc: 'No RPC endpoint configured',
    K.walletErrNetwork: 'Network error, please try again later',
    K.walletReceiveDesc: 'Share this address or QR code to receive funds',
    K.walletUseMax: 'Max',
    K.chatImage: 'Photo',
    K.chatVoice: 'Voice message',
    K.chatSendImage: 'Send photo',
    K.chatRecord: 'Record',
    K.chatRecording: 'Recording…',
    K.chatStop: 'Stop',
    K.chatCancel: 'Cancel',
    K.chatMediaTooLarge: 'Media is too large. Pick a smaller image or shorten the recording.',
    K.chatPermissionMicrophone: 'Microphone permission is required to record audio.',
    K.chatPermissionPhotos: 'Photo library permission is required to pick an image.',
    K.settingsTitle: 'Settings',
    K.settingsAppearance: 'Appearance',
    K.settingsTheme: 'Theme',
    K.settingsThemeSystem: 'System',
    K.settingsThemeLight: 'Light',
    K.settingsThemeDark: 'Dark',
    K.settingsLanguage: 'Language',
    K.settingsNetwork: 'Network',
    K.settingsWakuNode: 'Waku nodes',
    K.settingsWakuTest: 'Re-check',
    K.settingsWakuOk: 'Reachable',
    K.settingsWakuFail: 'Unreachable',
    K.settingsNodesDesc:
        'Messages go through the selected node only; tap a node to switch. Built-in nodes cannot be removed.',
    K.settingsNodeBuiltin: 'Built-in',
    K.settingsNodeCustom: 'Custom',
    K.settingsNodeAdd: 'Add node',
    K.settingsNodeAddTitle: 'Add a Waku node',
    K.settingsNodeAddHint: 'e.g. https://waku03.example.com',
    K.settingsNodeAdded: 'Node added',
    K.settingsNodeRemove: 'Remove node',
    K.settingsNodeRemoveConfirm: 'Remove %1\$s?',
    K.settingsNodeInvalid: 'Invalid node address',
    K.settingsNodeDuplicate: 'This node already exists',
    K.settingsNodeChecking: 'Checking',
    K.settingsResync: 'Re-fetch message history',
    K.settingsResyncDesc: 'Pull missed messages and key bundles from the node store (last 48h)',
    K.settingsResyncDone: 'History re-fetched',
    K.settingsBackup: 'Back up identity',
    K.settingsDelete: 'Delete identity on this device',
    K.settingsDeleteConfirm:
        'This wipes the local identity and every conversation. Continue?',
    K.settingsAbout: 'About',
    K.settingsVersion: 'Version',
    K.settingsAdvanced: 'Advanced',
    K.settingsClearCache: 'Clear cache',
    K.settingsCacheCleared: 'Cache cleared',
    K.settingsPublishKeys: 'Re-publish key bundle',
    K.settingsKeysPublished: 'Key bundle published to Waku',
    K.identityTitle: 'My identity',
    K.identityDid: 'Decentralized identifier',
    K.identityMethod: 'DID method',
    K.identityEthAddress: 'Ethereum address',
    K.identitySignKey: 'Signing public key',
    K.identityEncKey: 'Encryption public key',
    K.identityBackup: 'Back up recovery phrase',
    K.identityBackupDesc:
        'The recovery phrase is the only way back into your identity.',
    K.identityShowMnemonic: 'Show recovery phrase',
    K.identityHideMnemonic: 'Hide recovery phrase',
    K.identityConfirmBackup: 'I have saved my phrase',
    K.identityRisk: 'Risk notice',
    K.errorGeneric: 'Something went wrong, please try again.',
    K.errorNetwork: 'Network connection failed',
    K.errorInvalidInput: 'Invalid input',
    K.errorCrypto: 'Encryption or decryption failed',
    K.errorNotFound: 'Not found',
    K.errorTimeout: 'Connection timed out',
    K.timeJustNow: 'just now',
    K.timeMinutesAgo: '%1\$d min ago',
    K.timeHoursAgo: '%1\$d h ago',
  },

  // ================================================================= Español
  'es': {
    K.appName: 'NexusChat',
    K.appTagline: 'Descentralizado · Cifrado de extremo a extremo · Tuyo',
    K.ok: 'Aceptar',
    K.cancel: 'Cancelar',
    K.confirm: 'Confirmar',
    K.save: 'Guardar',
    K.copy: 'Copiar',
    K.copied: 'Copiado',
    K.close: 'Cerrar',
    K.delete: 'Eliminar',
    K.edit: 'Editar',
    K.search: 'Buscar',
    K.retry: 'Reintentar',
    K.loading: 'Cargando',
    K.back: 'Atrás',
    K.next: 'Siguiente',
    K.done: 'Hecho',
    K.reveal: 'Mostrar',
    K.hide: 'Ocultar',
    K.more: 'Más',
    K.share: 'Compartir',
    K.importAction: 'Importar',
    K.exportAction: 'Exportar',
    K.refresh: 'Actualizar',
    K.send: 'Enviar',
    K.unknown: 'Desconocido',
    K.optional: 'Opcional',
    K.comingSoon: 'Próximamente',
    K.statusOnline: 'En línea',
    K.statusOffline: 'Desconectado',
    K.statusConnecting: 'Conectando',
    K.statusConnected: 'Conectado',
    K.statusSyncing: 'Sincronizando',
    K.statusNoPeers: 'Sin pares',
    K.statusNoPeersHint:
        'El REST del nodo responde, pero no tiene pares, así que los mensajes no se pueden retransmitir.',
    K.navChats: 'Chats',
    K.navContacts: 'Contactos',
    K.navWallet: 'Cartera',
    K.navSettings: 'Ajustes',
    K.onboardingTitle: 'Conversaciones privadas, reinventadas',
    K.onboardingSubtitle:
        'Sin servidor, sin número de teléfono. Solo tu DID y una frase de recuperación.',
    K.onboardingCreate: 'Crear una identidad nueva',
    K.onboardingImport: 'Importar una identidad existente',
    K.feat1Title: 'Red descentralizada Waku',
    K.feat1Desc:
        'Los mensajes se propagan por relay / store de Waku: nada central que cerrar.',
    K.feat2Title: 'Identidad DID soberana',
    K.feat2Desc:
        'Una identidad did:ethr derivada de tu clave de Ethereum, solo tuya.',
    K.feat3Title: 'Cifrado de extremo a extremo',
    K.feat3Desc:
        'X25519 + AES-GCM, y cada mensaje lleva una firma secp256k1.',
    K.mnemonicTitle: 'Tu frase de recuperación',
    K.mnemonicDesc:
        'Estas 12 palabras son toda tu identidad. Anótalas sin conexión.',
    K.mnemonicWarn:
        'Quien tenga esta frase controlará por completo tu identidad.',
    K.mnemonicCopied: 'Frase de recuperación copiada',
    K.mnemonicNext: 'Ya la guardé',
    K.verifyTitle: 'Verifica tu copia',
    K.verifyDesc: 'Introduce la palabra n.º %1\$s para confirmar la copia.',
    K.verifyWrong: 'No es correcto, inténtalo de nuevo.',
    K.verifyPlaceholder: 'Palabra n.º %1\$s',
    K.profileTitle: 'Configura tu tarjeta',
    K.profileDesc: 'Este apodo se muestra a tus contactos. Cámbialo cuando quieras.',
    K.displayName: 'Apodo',
    K.displayNameHint: 'p. ej. Satoshi',
    K.enterApp: 'Entrar en NexusChat',
    K.restoreTitle: 'Importar identidad',
    K.restoreDesc:
        'Introduce tu frase de 12 o 24 palabras separadas por espacios.',
    K.restoreHint: 'apple banana ... separadas por espacios',
    K.restoreError: 'Frase inválida. Revisa la ortografía y el orden.',
    K.restoreSuccess: 'Identidad restaurada',
    K.importModeMnemonic: 'Frase semilla',
    K.importModePrivateKey: 'Clave privada',
    K.importPrivateKeyDesc:
        'Pega una clave privada hexadecimal de 32 bytes (prefijo 0x opcional) para importar la misma cuenta.',
    K.importPrivateKeyLabel: 'Clave privada',
    K.importPrivateKeyHint: '0x o 64 caracteres hexadecimales',
    K.importPrivateKeyInvalid:
        'Clave privada no válida. Debe tener 64 caracteres hexadecimales.',
    K.importPrivateKeyAddress: 'Dirección derivada',
    K.importPrivateKeyWarn:
        'La clave privada da control total de la cuenta. No la introduzcas en un dispositivo no fiable ni la compartas con nadie.',
    K.importPrivateKeyTitle: 'Importar clave privada',
    K.importPrivateKeySubtitle: 'Reemplazar la identidad actual con una clave privada',
    // ------------------------------------------------------ Caja fuerte / clave
    K.passwordLabel: 'Contraseña',
    K.passwordHint: 'Al menos 8 caracteres',
    K.passwordConfirmLabel: 'Confirmar contraseña',
    K.passwordRule:
        'Combina mayúsculas, minúsculas, números y símbolos; evita contraseñas comunes.',
    K.passwordWeak: 'Muy débil',
    K.passwordFair: 'Aceptable',
    K.passwordGood: 'Buena',
    K.passwordStrong: 'Fuerte',
    K.passwordWeakError:
        'La contraseña es demasiado débil: usa una más larga o más compleja',
    K.passwordMismatch: 'Las dos contraseñas no coinciden',
    K.passwordSetupTitle: 'Define una contraseña de la caja fuerte',
    K.passwordSetupDesc:
        'La frase de recuperación y la clave privada se cifran con esta contraseña antes de guardarse en el dispositivo.',
    K.passwordForgotWarn:
        'Recuerda esta contraseña. Nunca se sube y no se puede restablecer: si la pierdes, tendrás que crear una identidad nueva.',
    K.passwordWrong: 'Contraseña incorrecta',
    K.passwordChanged: 'Contraseña actualizada',
    K.changePasswordFailed: 'No se pudo cambiar la contraseña',
    K.currentPassword: 'Contraseña actual',
    K.autoHideIn: 'Se ocultará en %1\$s s',
    K.createFailed: 'No se pudo crear la identidad',
    K.restoreFailed: 'No se pudo restaurar la identidad',
    K.importFailed: 'No se pudo importar la identidad',
    // ------------------------------------------------------------- Bloqueo
    K.unlockTitle: 'Bloqueado',
    K.unlockDesc:
        'Introduce tu contraseña para desbloquear la frase y la clave privada.',
    K.unlockAction: 'Desbloquear',
    K.unlockWrong: 'Contraseña incorrecta',
    K.unlockCooldown: 'Demasiados intentos: espera %1\$s s',
    K.unlockForgot: '¿Olvidaste la contraseña?',
    K.unlockForgotTitle: 'La contraseña no se puede restablecer',
    K.unlockForgotDesc:
        'La contraseña solo sirve para descifrar en el dispositivo y no se guarda ninguna credencial de restablecimiento. Si la pierdes, tendrás que borrar los datos locales y volver a importar con la frase de recuperación.',
    // --------------------------------------------------- Migración / recuperación
    K.migrateTitle: 'Cifra tu identidad',
    K.migrateDesc:
        'La frase de recuperación y la clave privada de este dispositivo están en texto plano, legibles por cualquier programa con acceso al almacenamiento local. Define una contraseña para pasar a almacenamiento cifrado.',
    K.migrateAction: 'Cifrar y continuar',
    K.migrateFailed: 'El cifrado falló, inténtalo de nuevo',
    K.vaultUnavailableTitle: 'No se pueden leer los datos de identidad',
    K.vaultUnavailableDesc:
        'Los datos locales de identidad están dañados y no se pueden descifrar. Si tienes tu frase de recuperación, puedes borrar y volver a importar.',
    K.wipe: 'Borrar datos locales',
    K.wiped: 'Datos locales borrados',
    // ------------------------------------------------------ Verificación previa
    K.exportVerifyTitle: 'Verifica tu identidad',
    K.exportVerifyDesc:
        'Introduce la contraseña de la caja fuerte antes de mostrar la frase o la clave privada.',
    // ------------------------------------------------------- Seguridad
    K.securitySection: 'Seguridad',
    K.securityLockNow: 'Bloquear ahora',
    K.securityLockNowDesc:
        'Borrar la frase de recuperación y la clave privada de la memoria',
    K.securityAutoLock: 'Bloqueo automático',
    K.securityAutoLockNever: 'Nunca',
    K.securityAutoLockMinutes: '%1\$s min',
    K.securityHideSecrets: 'Ocultar secretos automáticamente',
    K.securityHideSecretsDesc: 'Cuánto tiempo permanece visible la frase',
    K.securityLockOnHide: 'Bloquear al salir de la pestaña',
    K.securityLockOnHideDesc: 'Bloquear en cuanto la pestaña pierde el foco',
    K.securityChangePassword: 'Cambiar contraseña',
    K.securityChangePasswordDesc: 'Volver a cifrar la caja fuerte',
    K.chatTitle: 'Chats',
    K.chatEmpty: 'Aún no hay conversaciones',
    K.chatEmptyDesc:
        'Ve a Contactos para añadir tu primer amigo descentralizado.',
    K.chatHint: 'Escribe un mensaje…',
    K.chatEnterTip: 'Shift+Enter para enviar · Enter para nueva línea',
    K.chatNewMessages: 'Mensajes nuevos',
    K.chatEncrypted: 'Cifrado de extremo a extremo',
    K.chatSending: 'Enviando',
    K.chatSent: 'Enviado',
    K.chatDelivered: 'Entregado',
    K.chatRead: 'Leído',
    K.chatFailed: 'Error al enviar',
    K.chatToday: 'Hoy',
    K.chatYesterday: 'Ayer',
    K.chatNew: 'Nuevo',
    K.chatSearch: 'Buscar chats o DID',
    K.chatTyping: 'escribiendo…',
    K.chatDeleteTitle: 'Eliminar conversación',
    K.chatDeleteConfirm:
        '¿Eliminar la conversación con %1\$s? No se puede deshacer.',
    K.chatSecureTitle: 'Esta conversación es privada',
    K.chatSecureDesc:
        'Los mensajes se cifran en el dispositivo antes de entrar en Waku.',
    K.chatPickContact: 'Elige un contacto para empezar a chatear',
    K.chatUnread: 'No leído',
    K.contactsTitle: 'Contactos',
    K.contactsEmpty: 'Sin contactos',
    K.contactsEmptyDesc: 'Añade un amigo por DID, dirección Ethereum o ENS.',
    K.contactsAdd: 'Añadir contacto',
    K.contactsMyQr: 'Mi código QR',
    K.contactsScanQr: 'Escanear código QR',
    K.contactsDidLabel: 'DID / dirección / ENS',
    K.contactsPasteDid: 'Pega un DID, dirección 0x o nombre ENS',
    K.contactsInvalidDid: 'Formato no reconocido, revisa e inténtalo de nuevo.',
    K.contactsAdded: 'Contacto añadido',
    K.contactsKeysSynced: 'Claves de cifrado sincronizadas',
    K.contactsRequest: 'Solicitud de amistad',
    K.contactsRemove: 'Eliminar contacto',
    K.contactsRemoveConfirm: '¿Eliminar a %1\$s?',
    K.contactsNickname: 'Apodo',
    K.contactsScanHint:
        'Escanea un código QR de NexusChat (pegar el valor también funciona)',
    K.walletTitle: 'Cartera',
    K.walletBalance: 'Saldo',
    K.walletNetwork: 'Red',
    K.walletAddress: 'Dirección',
    K.walletCopy: 'Copiar dirección',
    K.walletExplorer: 'Ver en el explorador',
    K.walletRpcUrl: 'Endpoint RPC',
    K.walletChainId: 'Chain ID',
    K.walletRefresh: 'Actualizar saldo',
    K.walletNoRpc: 'No hay endpoint RPC, saldo no disponible.',
    K.walletEns: 'Nombre ENS',
    K.walletDid: 'DID',
    K.walletTokens: 'Activos',
    K.walletSend: 'Transferir',
    K.walletChain: 'Cadena',
    K.walletChainDesc:
        'Solo cambia la cadena que muestra la cartera; la identidad de chat sigue siendo did:ethr.',
    K.walletTronRpc: 'Endpoint RPC TRON',
    K.walletBesuRpc: 'Endpoint RPC WEB6',
    K.chainEthereum: 'Ethereum',
    K.chainTron: 'TRON',
    K.chainBesu: 'WEB6',
    K.walletReceive: 'Recibir',
    K.walletSendTitle: 'Enviar',
    K.walletSendTo: 'Dirección del destinatario',
    K.walletSendToHint: 'Pega o escribe una dirección',
    K.walletAmount: 'Importe',
    K.walletAmountHint: '0.0',
    K.walletAvailable: 'Disponible',
    K.walletSendConfirm: 'Confirmar transferencia',
    K.walletSendConfirmTitle: 'Revisa los datos de la transferencia',
    K.walletSending: 'Difundiendo transacción…',
    K.walletSendSuccess: 'Transferencia enviada',
    K.walletSendFailed: 'Transferencia fallida',
    K.walletTxHash: 'Hash de transacción',
    K.walletViewTx: 'Ver en el explorador',
    K.walletErrInvalidAddress: 'Dirección del destinatario no válida',
    K.walletErrInvalidAmount: 'Introduce un importe mayor que 0',
    K.walletErrInsufficient: 'Saldo insuficiente (incluidas comisiones)',
    K.walletErrNoRpc: 'No hay endpoint RPC configurado',
    K.walletErrNetwork: 'Error de red, inténtalo más tarde',
    K.walletReceiveDesc: 'Comparte esta dirección o el código QR para recibir fondos',
    K.walletUseMax: 'Máx',
    K.chatImage: 'Foto',
    K.chatVoice: 'Mensaje de voz',
    K.chatSendImage: 'Enviar foto',
    K.chatRecord: 'Grabar',
    K.chatRecording: 'Grabando…',
    K.chatStop: 'Detener',
    K.chatCancel: 'Cancelar',
    K.chatMediaTooLarge: 'El archivo es demasiado grande. Elige una imagen más pequeña o acorta la grabación.',
    K.chatPermissionMicrophone: 'Se necesita permiso de micrófono para grabar audio.',
    K.chatPermissionPhotos: 'Se necesita permiso de la galería para elegir una imagen.',
    K.chainSelect: 'Seleccionar cadena',
    K.settingsTitle: 'Ajustes',
    K.settingsAppearance: 'Apariencia',
    K.settingsTheme: 'Tema',
    K.settingsThemeSystem: 'Sistema',
    K.settingsThemeLight: 'Claro',
    K.settingsThemeDark: 'Oscuro',
    K.settingsLanguage: 'Idioma',
    K.settingsNetwork: 'Red',
    K.settingsWakuNode: 'Nodos Waku',
    K.settingsWakuTest: 'Volver a comprobar',
    K.settingsWakuOk: 'Accesible',
    K.settingsWakuFail: 'No accesible',
    K.settingsNodesDesc:
        'Los mensajes solo se envían por el nodo seleccionado; toca un nodo para cambiarlo. Los nodos integrados no se pueden eliminar.',
    K.settingsNodeBuiltin: 'Integrado',
    K.settingsNodeCustom: 'Personalizado',
    K.settingsNodeAdd: 'Añadir nodo',
    K.settingsNodeAddTitle: 'Añadir un nodo Waku',
    K.settingsNodeAddHint: 'p. ej. https://waku03.example.com',
    K.settingsNodeAdded: 'Nodo añadido',
    K.settingsNodeRemove: 'Eliminar nodo',
    K.settingsNodeRemoveConfirm: '¿Eliminar %1\$s?',
    K.settingsNodeInvalid: 'Dirección de nodo no válida',
    K.settingsNodeDuplicate: 'Este nodo ya existe',
    K.settingsNodeChecking: 'Comprobando',
    K.settingsResync: 'Volver a descargar el historial',
    K.settingsResyncDesc: 'Recupera del store del nodo los mensajes y paquetes de claves de las últimas 48 h',
    K.settingsResyncDone: 'Historial actualizado',
    K.settingsBackup: 'Copia de seguridad',
    K.settingsDelete: 'Eliminar identidad en este dispositivo',
    K.settingsDeleteConfirm:
        'Esto borra la identidad local y todas las conversaciones. ¿Continuar?',
    K.settingsAbout: 'Acerca de',
    K.settingsVersion: 'Versión',
    K.settingsAdvanced: 'Avanzado',
    K.settingsClearCache: 'Borrar caché',
    K.settingsCacheCleared: 'Caché borrada',
    K.settingsPublishKeys: 'Republicar paquete de claves',
    K.settingsKeysPublished: 'Paquete de claves publicado en Waku',
    K.identityTitle: 'Mi identidad',
    K.identityDid: 'Identificador descentralizado',
    K.identityMethod: 'Método DID',
    K.identityEthAddress: 'Dirección Ethereum',
    K.identitySignKey: 'Clave pública de firma',
    K.identityEncKey: 'Clave pública de cifrado',
    K.identityBackup: 'Copiar frase de recuperación',
    K.identityBackupDesc:
        'La frase de recuperación es la única forma de volver a tu identidad.',
    K.identityShowMnemonic: 'Mostrar frase',
    K.identityHideMnemonic: 'Ocultar frase',
    K.identityConfirmBackup: 'Ya guardé mi frase',
    K.identityRisk: 'Aviso de riesgo',
    K.errorGeneric: 'Algo salió mal, inténtalo de nuevo.',
    K.errorNetwork: 'Falló la conexión de red',
    K.errorInvalidInput: 'Entrada inválida',
    K.errorCrypto: 'Falló el cifrado o descifrado',
    K.errorNotFound: 'No encontrado',
    K.errorTimeout: 'Tiempo de espera agotado',
    K.timeJustNow: 'ahora mismo',
    K.timeMinutesAgo: 'hace %1\$d min',
    K.timeHoursAgo: 'hace %1\$d h',
  },
};

/// 單一語系的文案存取物件。
class Strings {
  Strings._(this.locale, this._data);

  final AppLocale locale;

  final Map<String, String> _data;

  static final Map<String, String> _fallback = _bundles['zh_Hant']!;

  factory Strings.of(AppLocale locale) =>
      Strings._(locale, _bundles[locale.code] ?? _fallback);

  /// 依鍵取值，缺少時退回繁體中文，再缺少則回傳鍵名本身。
  String get(String key) => _data[key] ?? _fallback[key] ?? key;

  /// 帶參數的字串：`%1$s` / `%1$d`。
  String format(String key, List<Object> args) {
    var value = get(key);
    for (var i = 0; i < args.length; i++) {
      value = value.replaceAll('%${i + 1}\$s', '${args[i]}')
          .replaceAll('%${i + 1}\$d', '${args[i]}');
    }
    return value;
  }

  // -------------------------------------------------------------- 快速取用
  String get appName => get(K.appName);
  String get appTagline => get(K.appTagline);
  String get ok => get(K.ok);
  String get cancel => get(K.cancel);
  String get confirm => get(K.confirm);
  String get save => get(K.save);
  String get copy => get(K.copy);
  String get copied => get(K.copied);
  String get close => get(K.close);
  String get delete => get(K.delete);
  String get edit => get(K.edit);
  String get search => get(K.search);
  String get retry => get(K.retry);
  String get loading => get(K.loading);
  String get back => get(K.back);
  String get next => get(K.next);
  String get done => get(K.done);
  String get reveal => get(K.reveal);
  String get hide => get(K.hide);
  String get more => get(K.more);
  String get share => get(K.share);
  String get importAction => get(K.importAction);
  String get exportAction => get(K.exportAction);
  String get refresh => get(K.refresh);
  String get send => get(K.send);
  String get unknown => get(K.unknown);
  String get optional => get(K.optional);
  String get comingSoon => get(K.comingSoon);

  String get statusOnline => get(K.statusOnline);
  String get statusOffline => get(K.statusOffline);
  String get statusConnecting => get(K.statusConnecting);
  String get statusConnected => get(K.statusConnected);
  String get statusSyncing => get(K.statusSyncing);
  String get statusNoPeers => get(K.statusNoPeers);
  String get statusNoPeersHint => get(K.statusNoPeersHint);

  String get navChats => get(K.navChats);
  String get navContacts => get(K.navContacts);
  String get navWallet => get(K.navWallet);
  String get navSettings => get(K.navSettings);

  String get onboardingTitle => get(K.onboardingTitle);
  String get onboardingSubtitle => get(K.onboardingSubtitle);
  String get onboardingCreate => get(K.onboardingCreate);
  String get onboardingImport => get(K.onboardingImport);
  String get feat1Title => get(K.feat1Title);
  String get feat1Desc => get(K.feat1Desc);
  String get feat2Title => get(K.feat2Title);
  String get feat2Desc => get(K.feat2Desc);
  String get feat3Title => get(K.feat3Title);
  String get feat3Desc => get(K.feat3Desc);

  String get mnemonicTitle => get(K.mnemonicTitle);
  String get mnemonicDesc => get(K.mnemonicDesc);
  String get mnemonicWarn => get(K.mnemonicWarn);
  String get mnemonicCopied => get(K.mnemonicCopied);
  String get mnemonicNext => get(K.mnemonicNext);
  String get verifyTitle => get(K.verifyTitle);
  String verifyDesc(String index) => format(K.verifyDesc, [index]);
  String get verifyWrong => get(K.verifyWrong);
  String verifyPlaceholder(String index) =>
      format(K.verifyPlaceholder, [index]);
  String get profileTitle => get(K.profileTitle);
  String get profileDesc => get(K.profileDesc);
  String get displayName => get(K.displayName);
  String get displayNameHint => get(K.displayNameHint);
  String get enterApp => get(K.enterApp);
  String get restoreTitle => get(K.restoreTitle);
  String get restoreDesc => get(K.restoreDesc);
  String get restoreHint => get(K.restoreHint);
  String get restoreError => get(K.restoreError);
  String get restoreSuccess => get(K.restoreSuccess);

  String get importModeMnemonic => get(K.importModeMnemonic);
  String get importModePrivateKey => get(K.importModePrivateKey);
  String get importPrivateKeyDesc => get(K.importPrivateKeyDesc);
  String get importPrivateKeyLabel => get(K.importPrivateKeyLabel);
  String get importPrivateKeyHint => get(K.importPrivateKeyHint);
  String get importPrivateKeyInvalid => get(K.importPrivateKeyInvalid);
  String get importPrivateKeyAddress => get(K.importPrivateKeyAddress);
  String get importPrivateKeyWarn => get(K.importPrivateKeyWarn);
  String get importPrivateKeyTitle => get(K.importPrivateKeyTitle);
  String get importPrivateKeySubtitle => get(K.importPrivateKeySubtitle);

  // ---------------------------------------------------------- 保險庫 / 密碼
  String get passwordLabel => get(K.passwordLabel);
  String get passwordHint => get(K.passwordHint);
  String get passwordConfirmLabel => get(K.passwordConfirmLabel);
  String get passwordRule => get(K.passwordRule);
  String get passwordWeak => get(K.passwordWeak);
  String get passwordFair => get(K.passwordFair);
  String get passwordGood => get(K.passwordGood);
  String get passwordStrong => get(K.passwordStrong);
  String get passwordWeakError => get(K.passwordWeakError);
  String get passwordMismatch => get(K.passwordMismatch);
  String get passwordSetupTitle => get(K.passwordSetupTitle);
  String get passwordSetupDesc => get(K.passwordSetupDesc);
  String get passwordForgotWarn => get(K.passwordForgotWarn);
  String get passwordWrong => get(K.passwordWrong);
  String get passwordChanged => get(K.passwordChanged);
  String get changePasswordFailed => get(K.changePasswordFailed);
  String get currentPassword => get(K.currentPassword);
  String get createFailed => get(K.createFailed);
  String get restoreFailed => get(K.restoreFailed);
  String get importFailed => get(K.importFailed);

  /// 敏感內容自動隱藏倒數（帶入剩餘秒數）。
  String autoHideIn(String seconds) =>
      format(K.autoHideIn, <String>[seconds]);

  // ------------------------------------------------------------------ 鎖屏
  String get unlockTitle => get(K.unlockTitle);
  String get unlockDesc => get(K.unlockDesc);
  String get unlockAction => get(K.unlockAction);
  String get unlockWrong => get(K.unlockWrong);
  String get unlockForgot => get(K.unlockForgot);
  String get unlockForgotTitle => get(K.unlockForgotTitle);
  String get unlockForgotDesc => get(K.unlockForgotDesc);

  /// 解鎖冷卻提示（帶入剩餘秒數）。
  String unlockCooldown(String seconds) =>
      format(K.unlockCooldown, <String>[seconds]);

  // -------------------------------------------------------- 加密遷移 / 修復
  String get migrateTitle => get(K.migrateTitle);
  String get migrateDesc => get(K.migrateDesc);
  String get migrateAction => get(K.migrateAction);
  String get migrateFailed => get(K.migrateFailed);
  String get vaultUnavailableTitle => get(K.vaultUnavailableTitle);
  String get vaultUnavailableDesc => get(K.vaultUnavailableDesc);
  String get wipe => get(K.wipe);
  String get wiped => get(K.wiped);

  // ------------------------------------------------------------ 匯出驗證
  String get exportVerifyTitle => get(K.exportVerifyTitle);
  String get exportVerifyDesc => get(K.exportVerifyDesc);

  // -------------------------------------------------------- 設定頁安全區
  String get securitySection => get(K.securitySection);
  String get securityLockNow => get(K.securityLockNow);
  String get securityLockNowDesc => get(K.securityLockNowDesc);
  String get securityAutoLock => get(K.securityAutoLock);
  String get securityAutoLockNever => get(K.securityAutoLockNever);
  String get securityHideSecrets => get(K.securityHideSecrets);
  String get securityHideSecretsDesc => get(K.securityHideSecretsDesc);
  String get securityLockOnHide => get(K.securityLockOnHide);
  String get securityLockOnHideDesc => get(K.securityLockOnHideDesc);
  String get securityChangePassword => get(K.securityChangePassword);
  String get securityChangePasswordDesc =>
      get(K.securityChangePasswordDesc);

  /// 自動鎖定分鐘數（帶入分鐘數）。
  String securityAutoLockMinutes(String minutes) =>
      format(K.securityAutoLockMinutes, <String>[minutes]);

  String get chatTitle => get(K.chatTitle);
  String get chatEmpty => get(K.chatEmpty);
  String get chatEmptyDesc => get(K.chatEmptyDesc);
  String get chatHint => get(K.chatHint);
  String get chatEnterTip => get(K.chatEnterTip);
  String get chatNewMessages => get(K.chatNewMessages);
  String get chatEncrypted => get(K.chatEncrypted);
  String get chatSending => get(K.chatSending);
  String get chatSent => get(K.chatSent);
  String get chatDelivered => get(K.chatDelivered);
  String get chatRead => get(K.chatRead);
  String get chatFailed => get(K.chatFailed);
  String get chatToday => get(K.chatToday);
  String get chatYesterday => get(K.chatYesterday);
  String get chatNew => get(K.chatNew);
  String get chatSearch => get(K.chatSearch);
  String get chatTyping => get(K.chatTyping);
  String get chatDeleteTitle => get(K.chatDeleteTitle);
  String chatDeleteConfirm(String name) =>
      format(K.chatDeleteConfirm, [name]);
  String get chatSecureTitle => get(K.chatSecureTitle);
  String get chatSecureDesc => get(K.chatSecureDesc);
  String get chatPickContact => get(K.chatPickContact);
  String get chatUnread => get(K.chatUnread);

  String get contactsTitle => get(K.contactsTitle);
  String get contactsEmpty => get(K.contactsEmpty);
  String get contactsEmptyDesc => get(K.contactsEmptyDesc);
  String get contactsAdd => get(K.contactsAdd);
  String get contactsMyQr => get(K.contactsMyQr);
  String get contactsScanQr => get(K.contactsScanQr);
  String get contactsDidLabel => get(K.contactsDidLabel);
  String get contactsPasteDid => get(K.contactsPasteDid);
  String get contactsInvalidDid => get(K.contactsInvalidDid);
  String get contactsAdded => get(K.contactsAdded);
  String get contactsKeysSynced => get(K.contactsKeysSynced);
  String get contactsRequest => get(K.contactsRequest);
  String get contactsRemove => get(K.contactsRemove);
  String contactsRemoveConfirm(String name) =>
      format(K.contactsRemoveConfirm, [name]);
  String get contactsNickname => get(K.contactsNickname);
  String get contactsScanHint => get(K.contactsScanHint);

  String get walletTitle => get(K.walletTitle);
  String get walletBalance => get(K.walletBalance);
  String get walletNetwork => get(K.walletNetwork);
  String get walletAddress => get(K.walletAddress);
  String get walletCopy => get(K.walletCopy);
  String get walletExplorer => get(K.walletExplorer);
  String get walletRpcUrl => get(K.walletRpcUrl);
  String get walletChainId => get(K.walletChainId);
  String get walletRefresh => get(K.walletRefresh);
  String get walletNoRpc => get(K.walletNoRpc);
  String get walletEns => get(K.walletEns);
  String get walletDid => get(K.walletDid);
  String get walletTokens => get(K.walletTokens);
  String get walletSend => get(K.walletSend);
  String get walletChain => get(K.walletChain);
  String get walletChainDesc => get(K.walletChainDesc);
  String get walletTronRpc => get(K.walletTronRpc);
  String get walletBesuRpc => get(K.walletBesuRpc);
  String get chainEthereum => get(K.chainEthereum);
  String get chainTron => get(K.chainTron);
  String get chainBesu => get(K.chainBesu);
  String get walletReceive => get(K.walletReceive);
  String get walletSendTitle => get(K.walletSendTitle);
  String get walletSendTo => get(K.walletSendTo);
  String get walletSendToHint => get(K.walletSendToHint);
  String get walletAmount => get(K.walletAmount);
  String get walletAmountHint => get(K.walletAmountHint);
  String get walletAvailable => get(K.walletAvailable);
  String get walletSendConfirm => get(K.walletSendConfirm);
  String get walletSendConfirmTitle => get(K.walletSendConfirmTitle);
  String get walletSending => get(K.walletSending);
  String get walletSendSuccess => get(K.walletSendSuccess);
  String get walletSendFailed => get(K.walletSendFailed);
  String get walletTxHash => get(K.walletTxHash);
  String get walletViewTx => get(K.walletViewTx);
  String get walletErrInvalidAddress => get(K.walletErrInvalidAddress);
  String get walletErrInvalidAmount => get(K.walletErrInvalidAmount);
  String get walletErrInsufficient => get(K.walletErrInsufficient);
  String get walletErrNoRpc => get(K.walletErrNoRpc);
  String get walletErrNetwork => get(K.walletErrNetwork);
  String get walletReceiveDesc => get(K.walletReceiveDesc);
  String get walletUseMax => get(K.walletUseMax);
  String get chainSelect => get(K.chainSelect);

  String get chatImage => get(K.chatImage);
  String get chatVoice => get(K.chatVoice);
  String get chatSendImage => get(K.chatSendImage);
  String get chatRecord => get(K.chatRecord);
  String get chatRecording => get(K.chatRecording);
  String get chatStop => get(K.chatStop);
  String get chatCancel => get(K.chatCancel);
  String get chatMediaTooLarge => get(K.chatMediaTooLarge);
  String get chatPermissionMicrophone => get(K.chatPermissionMicrophone);
  String get chatPermissionPhotos => get(K.chatPermissionPhotos);

  String get settingsTitle => get(K.settingsTitle);
  String get settingsAppearance => get(K.settingsAppearance);
  String get settingsTheme => get(K.settingsTheme);
  String get settingsThemeSystem => get(K.settingsThemeSystem);
  String get settingsThemeLight => get(K.settingsThemeLight);
  String get settingsThemeDark => get(K.settingsThemeDark);
  String get settingsLanguage => get(K.settingsLanguage);
  String get settingsNetwork => get(K.settingsNetwork);
  String get settingsWakuNode => get(K.settingsWakuNode);
  String get settingsWakuTest => get(K.settingsWakuTest);
  String get settingsWakuOk => get(K.settingsWakuOk);
  String get settingsWakuFail => get(K.settingsWakuFail);
  String get settingsNodesDesc => get(K.settingsNodesDesc);
  String get settingsNodeBuiltin => get(K.settingsNodeBuiltin);
  String get settingsNodeCustom => get(K.settingsNodeCustom);
  String get settingsNodeAdd => get(K.settingsNodeAdd);
  String get settingsNodeAddTitle => get(K.settingsNodeAddTitle);
  String get settingsNodeAddHint => get(K.settingsNodeAddHint);
  String get settingsNodeAdded => get(K.settingsNodeAdded);
  String get settingsNodeRemove => get(K.settingsNodeRemove);
  String settingsNodeRemoveConfirm(String url) =>
      format(K.settingsNodeRemoveConfirm, <Object>[url]);
  String get settingsNodeInvalid => get(K.settingsNodeInvalid);
  String get settingsNodeDuplicate => get(K.settingsNodeDuplicate);
  String get settingsNodeChecking => get(K.settingsNodeChecking);
  String get settingsResync => get(K.settingsResync);
  String get settingsResyncDesc => get(K.settingsResyncDesc);
  String get settingsResyncDone => get(K.settingsResyncDone);
  String get settingsBackup => get(K.settingsBackup);
  String get settingsDelete => get(K.settingsDelete);
  String get settingsDeleteConfirm => get(K.settingsDeleteConfirm);
  String get settingsAbout => get(K.settingsAbout);
  String get settingsVersion => get(K.settingsVersion);
  String get settingsAdvanced => get(K.settingsAdvanced);
  String get settingsClearCache => get(K.settingsClearCache);
  String get settingsCacheCleared => get(K.settingsCacheCleared);
  String get settingsPublishKeys => get(K.settingsPublishKeys);
  String get settingsKeysPublished => get(K.settingsKeysPublished);

  String get identityTitle => get(K.identityTitle);
  String get identityDid => get(K.identityDid);
  String get identityMethod => get(K.identityMethod);
  String get identityEthAddress => get(K.identityEthAddress);
  String get identitySignKey => get(K.identitySignKey);
  String get identityEncKey => get(K.identityEncKey);
  String get identityBackup => get(K.identityBackup);
  String get identityBackupDesc => get(K.identityBackupDesc);
  String get identityShowMnemonic => get(K.identityShowMnemonic);
  String get identityHideMnemonic => get(K.identityHideMnemonic);
  String get identityConfirmBackup => get(K.identityConfirmBackup);
  String get identityRisk => get(K.identityRisk);

  String get errorGeneric => get(K.errorGeneric);
  String get errorNetwork => get(K.errorNetwork);
  String get errorInvalidInput => get(K.errorInvalidInput);
  String get errorCrypto => get(K.errorCrypto);
  String get errorNotFound => get(K.errorNotFound);
  String get errorTimeout => get(K.errorTimeout);

  String get timeJustNow => get(K.timeJustNow);
  String minutesAgo(int m) => format(K.timeMinutesAgo, [m]);
  String hoursAgo(int h) => format(K.timeHoursAgo, [h]);
}

/// 讓 [Strings] 掛上 Flutter 的 [Localizations] 機制。
class StringsDelegate extends LocalizationsDelegate<Strings> {
  const StringsDelegate();

  /// 交給 [MaterialApp.supportedLocales] 的清單。
  static List<Locale> get supportedLocales =>
      AppLocale.values.map((e) => e.locale).toList();

  @override
  bool isSupported(Locale locale) {
    for (final l in AppLocale.values) {
      if (l.locale.languageCode == locale.languageCode) return true;
    }
    return false;
  }

  @override
  Future<Strings> load(Locale locale) async =>
      Strings.of(AppLocale.fromLocale(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<Strings> old) => false;
}

/// 從任意 [BuildContext] 取得文案：`context.s.appName`。
extension StringsContextX on BuildContext {
  Strings get s => Localizations.of<Strings>(this, Strings)!;
}

/// Flutter 內建委派（Material / Cupertino / Widgets 在地化）。
const globalLocalizationsDelegates = <LocalizationsDelegate<Object>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
