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
  static const navDiscover = 'navDiscover';
  static const navSettings = 'navSettings';
  static const navMe = 'navMe';

  // ---------------------------------------------------------------- 發現
  static const discoverTitle = 'discoverTitle';
  static const discoverSubtitle = 'discoverSubtitle';
  static const discoverTools = 'discoverTools';
  static const discoverScan = 'discoverScan';
  static const discoverScanDesc = 'discoverScanDesc';
  static const scanTitle = 'scanTitle';
  static const scanHint = 'scanHint';
  static const scanTorch = 'scanTorch';
  static const scanSwitchCamera = 'scanSwitchCamera';
  static const scanUnsupportedTitle = 'scanUnsupportedTitle';
  static const scanUnsupportedDesc = 'scanUnsupportedDesc';
  static const scanPermissionTitle = 'scanPermissionTitle';
  static const scanPermissionDesc = 'scanPermissionDesc';
  static const scanCameraError = 'scanCameraError';
  static const scanResultTitle = 'scanResultTitle';
  static const scanResultDid = 'scanResultDid';
  static const scanResultAddress = 'scanResultAddress';
  static const scanResultEns = 'scanResultEns';
  static const scanResultText = 'scanResultText';
  static const scanAddContact = 'scanAddContact';
  static const scanOpenFailed = 'scanOpenFailed';
  static const scanPayAction = 'scanPayAction';
  static const scanResultPayment = 'scanResultPayment';
  static const scanPickHint = 'scanPickHint';
  static const scanPickInvalid = 'scanPickInvalid';

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
  // BIP39 密碼短語（第 13 / 25 個詞）
  static const passphraseAdvanced = 'passphraseAdvanced';
  static const passphraseLabel = 'passphraseLabel';
  static const passphraseHint = 'passphraseHint';
  static const passphraseConfirmLabel = 'passphraseConfirmLabel';
  static const passphraseDesc = 'passphraseDesc';
  static const passphraseMismatch = 'passphraseMismatch';
  static const identityPassphrase = 'identityPassphrase';
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
  static const chatRecall = 'chatRecall';
  static const chatRecallConfirm = 'chatRecallConfirm';
  static const chatRecalled = 'chatRecalled';
  static const chatDeleteMessageConfirm = 'chatDeleteMessageConfirm';
  static const chatMessageDeleted = 'chatMessageDeleted';
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
  static const chainBase = 'chainBase';
  static const chainArbitrum = 'chainArbitrum';
  static const chainBsc = 'chainBsc';
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
  static const walletSendNetwork = 'walletSendNetwork';
  static const walletSendNetworkNotice = 'walletSendNetworkNotice';
  static const walletSwitchNetwork = 'walletSwitchNetwork';
  static const walletErrChainMismatch = 'walletErrChainMismatch';
  static const walletScanAddress = 'walletScanAddress';
  static const walletRpcMismatch = 'walletRpcMismatch';
  static const walletRpcUrlHint = 'walletRpcUrlHint';
  static const walletNativeToken = 'walletNativeToken';

  // ---------------------------------------------------- 錢包 · 常用通證面板
  static const tokenAdd = 'tokenAdd';
  static const tokenAddTitle = 'tokenAddTitle';
  static const tokenAdded = 'tokenAdded';
  static const tokenTabErc20 = 'tokenTabErc20';
  static const tokenTabErc721 = 'tokenTabErc721';
  static const tokenTabErc1155 = 'tokenTabErc1155';
  static const tokenEmpty = 'tokenEmpty';
  static const tokenCustom = 'tokenCustom';
  static const tokenCopyContract = 'tokenCopyContract';
  static const tokenViewExplorer = 'tokenViewExplorer';
  static const tokenRemove = 'tokenRemove';
  static const tokenRemoveConfirm = 'tokenRemoveConfirm';
  static const tokenName = 'tokenName';
  static const tokenSymbol = 'tokenSymbol';
  static const tokenStandard = 'tokenStandard';
  static const tokenDecimals = 'tokenDecimals';
  static const tokenContract = 'tokenContract';
  static const tokenIcon = 'tokenIcon';
  static const tokenColor = 'tokenColor';
  static const tokenTypeErc20 = 'tokenTypeErc20';
  static const tokenTypeErc721 = 'tokenTypeErc721';
  static const tokenTypeErc1155 = 'tokenTypeErc1155';
  static const tokenTypeNative = 'tokenTypeNative';
  static const tokenErrNameSymbol = 'tokenErrNameSymbol';
  static const tokenInvalidAddress = 'tokenInvalidAddress';
  static const tokenInvalidDecimals = 'tokenInvalidDecimals';
  static const tokenErrTronToken = 'tokenErrTronToken';
  static const tokenHistoryTitle = 'tokenHistoryTitle';
  static const tokenHistoryEmpty = 'tokenHistoryEmpty';
  static const tokenNotTransferable = 'tokenNotTransferable';

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
  static const chatImagePickFailed = 'chatImagePickFailed';
  static const chatImageUnavailable = 'chatImageUnavailable';
  static const chatImageUnsupported = 'chatImageUnsupported';
  static const chatImageDownload = 'chatImageDownload';
  static const chatImageSaved = 'chatImageSaved';
  static const chatImageSavedToAlbum = 'chatImageSavedToAlbum';
  static const chatImageSaveFailed = 'chatImageSaveFailed';
  static const chatImageZoomIn = 'chatImageZoomIn';
  static const chatImageZoomOut = 'chatImageZoomOut';
  static const chatImageReset = 'chatImageReset';

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
  static const settingsLicense = 'settingsLicense';
  static const settingsThirdPartyLicenses = 'settingsThirdPartyLicenses';
  static const settingsVersion = 'settingsVersion';
  static const settingsAdvanced = 'settingsAdvanced';

  // 設定分組標題與目錄副標
  static const settingsGroupGeneral = 'settingsGroupGeneral';
  static const settingsGroupAccount = 'settingsGroupAccount';
  static const settingsGroupConnection = 'settingsGroupConnection';
  static const settingsGroupDanger = 'settingsGroupDanger';
  static const settingsSubAppearance = 'settingsSubAppearance';
  static const settingsSubSecurity = 'settingsSubSecurity';
  static const settingsSubNetwork = 'settingsSubNetwork';
  static const settingsSubBlockchain = 'settingsSubBlockchain';
  static const settingsSubIdentity = 'settingsSubIdentity';
  static const settingsSubImportKey = 'settingsSubImportKey';
  static const settingsSubAbout = 'settingsSubAbout';
  static const settingsSubDanger = 'settingsSubDanger';

  // ------------------------------------------------------------ 版本更新
  static const updateCheck = 'updateCheck';
  static const updateChecking = 'updateChecking';
  static const updateLatest = 'updateLatest';
  static const updateAvailableTitle = 'updateAvailableTitle';
  static const updateVersionLine = 'updateVersionLine';
  static const updatePublished = 'updatePublished';
  static const updateNow = 'updateNow';
  static const updateLater = 'updateLater';
  static const updateFailed = 'updateFailed';
  static const updateLaunchFailed = 'updateLaunchFailed';
  static const updateRefresh = 'updateRefresh';
  static const updateWebHint = 'updateWebHint';
  static const scanToDownload = 'scanToDownload';
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
    K.navDiscover: '发现',
    K.navSettings: '设置',
    K.navMe: '我',
    K.discoverTitle: '发现',
    K.discoverSubtitle: '探索 NexusChat 的更多可能',
    K.discoverTools: '工具',
    K.discoverScan: '扫一扫',
    K.discoverScanDesc: '扫描二维码，网址可直接打开',
    K.scanTitle: '扫一扫',
    K.scanHint: '将二维码放入框内，即可自动识别',
    K.scanTorch: '手电筒',
    K.scanSwitchCamera: '切换镜头',
    K.scanUnsupportedTitle: '此设备不支持扫码',
    K.scanUnsupportedDesc: '目前仅支持 Android、iOS、macOS 与浏览器，请改用移动设备或网页版。',
    K.scanPermissionTitle: '需要相机权限',
    K.scanPermissionDesc: '请在系统设置中允许 NexusChat 使用相机，才能使用扫一扫。',
    K.scanCameraError: '相机无法启动，请稍后再试。',
    K.scanResultTitle: '扫描结果',
    K.scanResultDid: 'NexusChat 身份（DID）',
    K.scanResultAddress: '以太坊地址',
    K.scanResultEns: 'ENS 名称',
    K.scanResultText: '文字内容',
    K.scanAddContact: '添加联系人',
    K.scanOpenFailed: '无法打开此网址',
    K.scanPayAction: '向它转账',
    K.scanResultPayment: '付款请求',
    K.scanPickHint: '将镜头对准收款方的二维码',
    K.scanPickInvalid: '这不是有效的收款地址',
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
    K.passphraseAdvanced: '高级：BIP39 密码短语',
    K.passphraseLabel: '密码短语（选填）',
    K.passphraseHint: '留空表示不使用',
    K.passphraseConfirmLabel: '确认密码短语',
    K.passphraseDesc: '助记词加上密码短语才会得到这个身份：短语区分大小写与空格，'
        '打错不会报错，只会还原成另一个钱包。必须与助记词分开保管。',
    K.passphraseMismatch: '两次输入的密码短语不一致',
    K.identityPassphrase: 'BIP39 密码短语',
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
    K.chatRecall: '撤回',
    K.chatRecallConfirm: '撤回后双方都会显示「消息已撤回」。确定吗？',
    K.chatRecalled: '消息已撤回',
    K.chatDeleteMessageConfirm: '删除后本机不再显示这条消息，对方仍看得到。确定吗？',
    K.chatMessageDeleted: '消息已删除',
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
    K.chainBase: 'Base',
    K.chainArbitrum: 'Arbitrum',
    K.chainBsc: 'BNB 链',
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
    K.walletSendNetwork: '转账网络',
    K.walletSendNetworkNotice: r'正在 %1$s 转账，请确认收款地址属于同一条链。',
    K.walletSwitchNetwork: '切换网络',
    K.walletErrChainMismatch: '收款地址不属于当前的网络',
    K.walletScanAddress: '扫描收款地址',
    K.walletRpcMismatch: 'RPC 返回的网络与当前选择不符，请检查端点设置',
    K.walletRpcUrlHint: '留空则使用默认端点',
    K.walletNativeToken: '原生代币',
    K.tokenAdd: '添加通证',
    K.tokenAddTitle: '添加自定义通证',
    K.tokenAdded: '已添加通证',
    K.tokenTabErc20: '代币',
    K.tokenTabErc721: 'NFT',
    K.tokenTabErc1155: '资产集',
    K.tokenEmpty: '此网络暂无此类通证',
    K.tokenCustom: '自定义',
    K.tokenCopyContract: '复制合约地址',
    K.tokenViewExplorer: '在浏览器查看',
    K.tokenRemove: '移除',
    K.tokenRemoveConfirm: '确定要移除这个自定义通证吗？',
    K.tokenName: '名称',
    K.tokenSymbol: '符号',
    K.tokenStandard: '类型',
    K.tokenDecimals: '精度',
    K.tokenContract: '合约地址',
    K.tokenIcon: '图标 (emoji)',
    K.tokenColor: '颜色 (#RRGGBB)',
    K.tokenTypeErc20: 'ERC-20 代币',
    K.tokenTypeErc721: 'ERC-721 NFT',
    K.tokenTypeErc1155: 'ERC-1155 资产集',
    K.tokenTypeNative: '原生代币',
    K.tokenErrNameSymbol: '请填写名称与符号',
    K.tokenInvalidAddress: '请输入有效的合约地址',
    K.tokenInvalidDecimals: '精度需为 0–36 的整数',
    K.tokenErrTronToken: 'TRC-20 转账暂不支持，请使用原生 TRX 或其他工具',
    K.tokenHistoryTitle: '发送记录',
    K.tokenHistoryEmpty: '暂无发送记录',
    K.tokenNotTransferable: '该通证为 NFT，不可转账',
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
    K.chatImagePickFailed: '无法读取所选图片，请改用 JPG / PNG。',
    K.chatImageUnavailable: '图片无法显示',
    K.chatImageUnsupported: '无法处理这张图片，请改用 JPG 或 PNG。',
    K.chatImageDownload: '下载图片',
    K.chatImageSaved: '图片已保存',
    K.chatImageSavedToAlbum: '图片已存入相册',
    K.chatImageSaveFailed: '保存失败',
    K.chatImageZoomIn: '放大',
    K.chatImageZoomOut: '缩小',
    K.chatImageReset: '还原',
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
    K.settingsLicense: '开源许可',
    K.settingsThirdPartyLicenses: '第三方许可',
    K.settingsVersion: '版本',
    K.updateCheck: '检查更新',
    K.updateChecking: '正在检查更新…',
    K.updateLatest: '已是最新版本',
    K.updateAvailableTitle: '发现新版本',
    K.updateVersionLine: 'v%1\$s（构建 %2\$s）',
    K.updatePublished: '发布于 %1\$s',
    K.updateNow: '立即更新',
    K.updateLater: '稍后',
    K.updateFailed: '无法检查更新，请稍后再试',
    K.updateRefresh: '刷新页面',
    K.updateWebHint: '网页版由 GitHub Pages 托管，刷新页面即更新到最新版本。',
    K.updateLaunchFailed: '无法打开下载链接，请稍后再试或扫码下载',
    K.scanToDownload: '扫码下载',
    K.settingsAdvanced: '进阶',
    K.settingsGroupGeneral: '通用',
    K.settingsGroupAccount: '账户',
    K.settingsGroupConnection: '连接',
    K.settingsGroupDanger: '危险区',
    K.settingsSubAppearance: '主题样式与界面语言',
    K.settingsSubSecurity: '锁定、自动锁定、修改密码',
    K.settingsSubNetwork: 'Waku 节点与连接',
    K.settingsSubBlockchain: '区块链与 RPC 端点',
    K.settingsSubIdentity: 'DID 与备份',
    K.settingsSubImportKey: '用私钥恢复身份',
    K.settingsSubAbout: '版本与更新',
    K.settingsSubDanger: '删除此设备上的身份',
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
    K.navDiscover: 'Discover',
    K.navSettings: 'Settings',
    K.navMe: 'Me',
    K.discoverTitle: 'Discover',
    K.discoverSubtitle: 'Explore more of NexusChat',
    K.discoverTools: 'Tools',
    K.discoverScan: 'Scan',
    K.discoverScanDesc: 'Scan a QR code — links open right away',
    K.scanTitle: 'Scan',
    K.scanHint: 'Place the QR code inside the frame to detect it automatically',
    K.scanTorch: 'Flashlight',
    K.scanSwitchCamera: 'Switch camera',
    K.scanUnsupportedTitle: 'Scanning is not supported here',
    K.scanUnsupportedDesc:
        'Only Android, iOS, macOS and the browser are supported. Please use a mobile device or the web build.',
    K.scanPermissionTitle: 'Camera permission required',
    K.scanPermissionDesc:
        'Allow NexusChat to use the camera in system settings to scan QR codes.',
    K.scanCameraError: 'The camera could not start, please try again.',
    K.scanResultTitle: 'Scan result',
    K.scanResultDid: 'NexusChat identity (DID)',
    K.scanResultAddress: 'Ethereum address',
    K.scanResultEns: 'ENS name',
    K.scanResultText: 'Text',
    K.scanAddContact: 'Add contact',
    K.scanOpenFailed: 'Could not open this link',
    K.scanPayAction: 'Send to it',
    K.scanResultPayment: 'Payment request',
    K.scanPickHint: 'Point the camera at the recipient QR code',
    K.scanPickInvalid: 'This is not a valid recipient address',
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
    K.passphraseAdvanced: 'Advanced: BIP39 passphrase',
    K.passphraseLabel: 'Passphrase (optional)',
    K.passphraseHint: 'Leave empty to not use one',
    K.passphraseConfirmLabel: 'Confirm passphrase',
    K.passphraseDesc:
        'The mnemonic and the passphrase together produce this identity. The '
        'passphrase is case-sensitive and a typo will not raise an error — it '
        'simply restores a different wallet. Store it separately from the mnemonic.',
    K.passphraseMismatch: 'The two passphrases do not match',
    K.identityPassphrase: 'BIP39 passphrase',
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
    K.chatRecall: 'Recall',
    K.chatRecallConfirm: 'After recalling, both sides will see "Message recalled". Continue?',
    K.chatRecalled: 'Message recalled',
    K.chatDeleteMessageConfirm:
        'This removes the message on this device only; the other side keeps it. Continue?',
    K.chatMessageDeleted: 'Message deleted',
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
    K.chainBase: 'Base',
    K.chainArbitrum: 'Arbitrum',
    K.chainBsc: 'BNB Chain',
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
    K.walletSendNetwork: 'Transfer network',
    K.walletSendNetworkNotice:
        r'Sending on %1$s. Make sure the recipient address belongs to this network.',
    K.walletSwitchNetwork: 'Switch network',
    K.walletErrChainMismatch: 'This address does not belong to the current network',
    K.walletScanAddress: 'Scan a recipient address',
    K.walletRpcMismatch:
        'The RPC endpoint reports a different network than the one selected',
    K.walletRpcUrlHint: 'Leave empty to use the default endpoint',
    K.walletNativeToken: 'Native token',
    K.tokenAdd: 'Add token',
    K.tokenAddTitle: 'Add custom token',
    K.tokenAdded: 'Token added',
    K.tokenTabErc20: 'Tokens',
    K.tokenTabErc721: 'NFT',
    K.tokenTabErc1155: 'Asset sets',
    K.tokenEmpty: 'No tokens of this type',
    K.tokenCustom: 'Custom',
    K.tokenCopyContract: 'Copy contract',
    K.tokenViewExplorer: 'View in explorer',
    K.tokenRemove: 'Remove',
    K.tokenRemoveConfirm: 'Remove this custom token?',
    K.tokenName: 'Name',
    K.tokenSymbol: 'Symbol',
    K.tokenStandard: 'Type',
    K.tokenDecimals: 'Decimals',
    K.tokenContract: 'Contract',
    K.tokenIcon: 'Icon (emoji)',
    K.tokenColor: 'Color (#RRGGBB)',
    K.tokenTypeErc20: 'ERC-20 token',
    K.tokenTypeErc721: 'ERC-721 NFT',
    K.tokenTypeErc1155: 'ERC-1155 asset set',
    K.tokenTypeNative: 'Native token',
    K.tokenErrNameSymbol: 'Enter a name and symbol',
    K.tokenInvalidAddress: 'Enter a valid contract address',
    K.tokenInvalidDecimals: 'Decimals must be an integer from 0 to 36',
    K.tokenErrTronToken:
        'TRC-20 transfers are not supported yet; use native TRX or another tool',
    K.tokenHistoryTitle: 'Send history',
    K.tokenHistoryEmpty: 'No send history yet',
    K.tokenNotTransferable: 'This token is an NFT and cannot be transferred',
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
    K.chatImagePickFailed: 'Could not read the selected image. Please use JPG / PNG.',
    K.chatImageUnavailable: 'Image unavailable',
    K.chatImageUnsupported: 'Unsupported image. Please use JPG or PNG.',
    K.chatImageDownload: 'Download image',
    K.chatImageSaved: 'Image saved',
    K.chatImageSavedToAlbum: 'Image saved to album',
    K.chatImageSaveFailed: 'Could not save the image',
    K.chatImageZoomIn: 'Zoom in',
    K.chatImageZoomOut: 'Zoom out',
    K.chatImageReset: 'Reset',
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
    K.settingsLicense: 'Open source license',
    K.settingsThirdPartyLicenses: 'Third-party licenses',
    K.settingsVersion: 'Version',
    K.updateCheck: 'Check for updates',
    K.updateChecking: 'Checking for updates…',
    K.updateLatest: 'Up to date',
    K.updateAvailableTitle: 'Update available',
    K.updateVersionLine: 'v%1\$s (build %2\$s)',
    K.updatePublished: 'Published %1\$s',
    K.updateNow: 'Update now',
    K.updateLater: 'Later',
    K.updateFailed: 'Could not check for updates. Try again later.',
    K.updateRefresh: 'Refresh page',
    K.updateWebHint:
        'The web app is hosted on GitHub Pages; just refresh the page to get the latest version.',
    K.updateLaunchFailed:
        'Could not open the download link. Try again later or scan the QR code.',
    K.scanToDownload: 'Scan to download',
    K.settingsAdvanced: 'Advanced',
    K.settingsGroupGeneral: 'General',
    K.settingsGroupAccount: 'Account',
    K.settingsGroupConnection: 'Connection',
    K.settingsGroupDanger: 'Danger zone',
    K.settingsSubAppearance: 'Theme style and interface language',
    K.settingsSubSecurity: 'Lock, auto-lock and password',
    K.settingsSubNetwork: 'Waku nodes and connectivity',
    K.settingsSubBlockchain: 'Chain and RPC endpoints',
    K.settingsSubIdentity: 'DID and backup',
    K.settingsSubImportKey: 'Restore identity from a private key',
    K.settingsSubAbout: 'Version and updates',
    K.settingsSubDanger: 'Delete identity on this device',
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
    K.navDiscover: 'Descubrir',
    K.navSettings: 'Ajustes',
    K.navMe: 'Perfil',
    K.discoverTitle: 'Descubrir',
    K.discoverSubtitle: 'Explora más de NexusChat',
    K.discoverTools: 'Herramientas',
    K.discoverScan: 'Escanear',
    K.discoverScanDesc: 'Escanea un código QR; los enlaces se abren al instante',
    K.scanTitle: 'Escanear',
    K.scanHint:
        'Coloca el código QR dentro del marco para detectarlo automáticamente',
    K.scanTorch: 'Linterna',
    K.scanSwitchCamera: 'Cambiar cámara',
    K.scanUnsupportedTitle: 'Escaneo no disponible aquí',
    K.scanUnsupportedDesc:
        'Solo se admiten Android, iOS, macOS y el navegador. Usa un dispositivo móvil o la versión web.',
    K.scanPermissionTitle: 'Permiso de cámara necesario',
    K.scanPermissionDesc:
        'Permite que NexusChat use la cámara en los ajustes del sistema para escanear códigos QR.',
    K.scanCameraError: 'No se pudo iniciar la cámara, inténtalo de nuevo.',
    K.scanResultTitle: 'Resultado del escaneo',
    K.scanResultDid: 'Identidad de NexusChat (DID)',
    K.scanResultAddress: 'Dirección Ethereum',
    K.scanResultEns: 'Nombre ENS',
    K.scanResultText: 'Texto',
    K.scanAddContact: 'Añadir contacto',
    K.scanOpenFailed: 'No se pudo abrir este enlace',
    K.scanPayAction: 'Enviar a esta dirección',
    K.scanResultPayment: 'Solicitud de pago',
    K.scanPickHint: 'Apunta la cámara al código QR del destinatario',
    K.scanPickInvalid: 'Esta no es una dirección de destino válida',
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
    K.passphraseAdvanced: 'Avanzado: frase de contraseña BIP39',
    K.passphraseLabel: 'Frase de contraseña (opcional)',
    K.passphraseHint: 'Déjalo vacío para no usar una',
    K.passphraseConfirmLabel: 'Confirmar frase de contraseña',
    K.passphraseDesc:
        'El mnemotécnico y la frase de contraseña producen juntos esta identidad. '
        'La frase distingue mayúsculas y un error no mostrará ningún aviso: '
        'simplemente restaurará otra cartera. Guárdala por separado del mnemotécnico.',
    K.passphraseMismatch: 'Las dos frases de contraseña no coinciden',
    K.identityPassphrase: 'Frase de contraseña BIP39',
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
    K.chatRecall: 'Retirar',
    K.chatRecallConfirm: 'Al retirarlo, ambos verán «Mensaje retirado». ¿Continuar?',
    K.chatRecalled: 'Mensaje retirado',
    K.chatDeleteMessageConfirm:
        'Esto elimina el mensaje solo en este dispositivo; la otra persona lo conserva. ¿Continuar?',
    K.chatMessageDeleted: 'Mensaje eliminado',
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
    K.chainBase: 'Base',
    K.chainArbitrum: 'Arbitrum',
    K.chainBsc: 'BNB Chain',
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
    K.walletSendNetwork: 'Red de transferencia',
    K.walletSendNetworkNotice:
        r'Enviando en %1$s. Comprueba que la dirección pertenezca a esta red.',
    K.walletSwitchNetwork: 'Cambiar de red',
    K.walletErrChainMismatch: 'Esta dirección no pertenece a la red actual',
    K.walletScanAddress: 'Escanear dirección de destino',
    K.walletRpcMismatch:
        'El endpoint RPC informa de una red distinta a la seleccionada',
    K.walletRpcUrlHint: 'Déjalo vacío para usar el endpoint predeterminado',
    K.walletNativeToken: 'Token nativo',
    K.tokenAdd: 'Añadir token',
    K.tokenAddTitle: 'Añadir token personalizado',
    K.tokenAdded: 'Token añadido',
    K.tokenTabErc20: 'Tokens',
    K.tokenTabErc721: 'NFT',
    K.tokenTabErc1155: 'Conjuntos de activos',
    K.tokenEmpty: 'No hay tokens de este tipo',
    K.tokenCustom: 'Personalizado',
    K.tokenCopyContract: 'Copiar contrato',
    K.tokenViewExplorer: 'Ver en explorador',
    K.tokenRemove: 'Eliminar',
    K.tokenRemoveConfirm: '¿Eliminar este token personalizado?',
    K.tokenName: 'Nombre',
    K.tokenSymbol: 'Símbolo',
    K.tokenStandard: 'Tipo',
    K.tokenDecimals: 'Decimales',
    K.tokenContract: 'Contrato',
    K.tokenIcon: 'Icono (emoji)',
    K.tokenColor: 'Color (#RRGGBB)',
    K.tokenTypeErc20: 'Token ERC-20',
    K.tokenTypeErc721: 'NFT ERC-721',
    K.tokenTypeErc1155: 'Conjunto ERC-1155',
    K.tokenTypeNative: 'Token nativo',
    K.tokenErrNameSymbol: 'Introduce un nombre y símbolo',
    K.tokenInvalidAddress: 'Introduce una dirección de contrato válida',
    K.tokenInvalidDecimals: 'Los decimales deben ser un entero del 0 al 36',
    K.tokenErrTronToken:
        'Las transferencias TRC-20 aún no son compatibles; usa TRX nativo u otra herramienta',
    K.tokenHistoryTitle: 'Historial de envío',
    K.tokenHistoryEmpty: 'Aún no hay envíos',
    K.tokenNotTransferable:
        'Este token es un NFT y no se puede transferir',
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
    K.chatImagePickFailed:
        'No se pudo leer la imagen seleccionada. Usa JPG / PNG.',
    K.chatImageUnavailable: 'Imagen no disponible',
    K.chatImageUnsupported: 'Imagen no compatible. Usa JPG o PNG.',
    K.chatImageDownload: 'Descargar imagen',
    K.chatImageSaved: 'Imagen guardada',
    K.chatImageSavedToAlbum: 'Imagen guardada en el álbum',
    K.chatImageSaveFailed: 'No se pudo guardar la imagen',
    K.chatImageZoomIn: 'Acercar',
    K.chatImageZoomOut: 'Alejar',
    K.chatImageReset: 'Restablecer',
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
    K.settingsLicense: 'Licencia de código abierto',
    K.settingsThirdPartyLicenses: 'Licencias de terceros',
    K.settingsVersion: 'Versión',
    K.updateCheck: 'Buscar actualizaciones',
    K.updateChecking: 'Buscando actualizaciones…',
    K.updateLatest: 'Está actualizado',
    K.updateAvailableTitle: 'Actualización disponible',
    K.updateVersionLine: 'v%1\$s (compilación %2\$s)',
    K.updatePublished: 'Publicado el %1\$s',
    K.updateNow: 'Actualizar ahora',
    K.updateLater: 'Más tarde',
    K.updateFailed: 'No se pudieron buscar actualizaciones. Inténtalo más tarde.',
    K.updateRefresh: 'Actualizar página',
    K.updateWebHint:
        'La versión web se aloja en GitHub Pages; simplemente actualiza la página para obtener la última versión.',
    K.updateLaunchFailed:
        'No se pudo abrir el enlace de descarga. Inténtalo más tarde o escanea el código QR.',
    K.scanToDownload: 'Escanea para descargar',
    K.settingsAdvanced: 'Avanzado',
    K.settingsGroupGeneral: 'General',
    K.settingsGroupAccount: 'Cuenta',
    K.settingsGroupConnection: 'Conexión',
    K.settingsGroupDanger: 'Zona de peligro',
    K.settingsSubAppearance: 'Estilo visual e idioma',
    K.settingsSubSecurity: 'Bloqueo, auto-bloqueo y contraseña',
    K.settingsSubNetwork: 'Nodos Waku y conectividad',
    K.settingsSubBlockchain: 'Cadena y puntos RPC',
    K.settingsSubIdentity: 'DID y copia de seguridad',
    K.settingsSubImportKey: 'Restaurar identidad con clave privada',
    K.settingsSubAbout: 'Versión y actualizaciones',
    K.settingsSubDanger: 'Eliminar identidad en este dispositivo',
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

  // ================================================================ हिन्दी
  'hi': {
    K.appName: 'NexusChat',
    K.appTagline: 'विकेंद्रीकृत · एंड-टू-एंड एन्क्रिप्टेड · केवल आपका',
    K.ok: 'ठीक है',
    K.cancel: 'रद्द करें',
    K.confirm: 'पुष्टि करें',
    K.save: 'सहेजें',
    K.copy: 'कॉपी',
    K.copied: 'कॉपी हो गया',
    K.close: 'बंद करें',
    K.delete: 'हटाएँ',
    K.edit: 'संपादित करें',
    K.search: 'खोजें',
    K.retry: 'पुनः प्रयास',
    K.loading: 'लोड हो रहा है',
    K.back: 'पीछे',
    K.next: 'आगे',
    K.done: 'पूर्ण',
    K.reveal: 'दिखाएँ',
    K.hide: 'छिपाएँ',
    K.more: 'और',
    K.share: 'साझा करें',
    K.importAction: 'आयात',
    K.exportAction: 'निर्यात',
    K.refresh: 'ताज़ा करें',
    K.send: 'भेजें',
    K.unknown: 'अज्ञात',
    K.optional: 'वैकल्पिक',
    K.comingSoon: 'जल्द आ रहा है',
    K.statusOnline: 'ऑनलाइन',
    K.statusOffline: 'ऑफ़लाइन',
    K.statusConnecting: 'कनेक्ट हो रहा है',
    K.statusConnected: 'कनेक्टेड',
    K.statusSyncing: 'सिंक हो रहा है',
    K.statusNoPeers: 'कोई पीयर नहीं',
    K.statusNoPeersHint:
        'नोड REST पहुँच योग्य है लेकिन इसके कोई पीयर नहीं हैं, इसलिए संदेश रिले नहीं किए जा सकते।',
    K.navChats: 'चैट',
    K.navContacts: 'संपर्क',
    K.navWallet: 'वॉलेट',
    K.navDiscover: 'खोजें',
    K.navSettings: 'सेटिंग्स',
    K.navMe: 'मैं',
    K.discoverTitle: 'खोजें',
    K.discoverSubtitle: 'NexusChat के और फ़ीचर देखें',
    K.discoverTools: 'टूल',
    K.discoverScan: 'स्कैन',
    K.discoverScanDesc: 'QR कोड स्कैन करें — लिंक तुरंत खुलते हैं',
    K.scanTitle: 'स्कैन',
    K.scanHint: 'QR कोड को फ्रेम के भीतर रखें, यह स्वतः पहचाना जाएगा',
    K.scanTorch: 'टॉर्च',
    K.scanSwitchCamera: 'कैमरा बदलें',
    K.scanUnsupportedTitle: 'यहाँ स्कैन समर्थित नहीं है',
    K.scanUnsupportedDesc:
        'केवल Android, iOS, macOS और ब्राउज़र समर्थित हैं। कृपया मोबाइल डिवाइस या वेब बिल्ड का उपयोग करें।',
    K.scanPermissionTitle: 'कैमरा अनुमति आवश्यक',
    K.scanPermissionDesc:
        'QR कोड स्कैन करने के लिए सिस्टम सेटिंग्स में NexusChat को कैमरा उपयोग की अनुमति दें।',
    K.scanCameraError: 'कैमरा शुरू नहीं हो सका, कृपया पुनः प्रयास करें।',
    K.scanResultTitle: 'स्कैन परिणाम',
    K.scanResultDid: 'NexusChat पहचान (DID)',
    K.scanResultAddress: 'Ethereum पता',
    K.scanResultEns: 'ENS नाम',
    K.scanResultText: 'टेक्स्ट',
    K.scanAddContact: 'संपर्क जोड़ें',
    K.scanOpenFailed: 'यह लिंक नहीं खोला जा सका',
    K.scanPayAction: 'इसे भेजें',
    K.scanResultPayment: 'भुगतान अनुरोध',
    K.scanPickHint: 'प्राप्तकर्ता के QR कोड पर कैमरा घुमाएँ',
    K.scanPickInvalid: 'यह वैध प्राप्तकर्ता पता नहीं है',
    K.onboardingTitle: 'निजी बातचीत, नए रूप में',
    K.onboardingSubtitle:
        'कोई सर्वर नहीं, कोई फ़ोन नंबर नहीं। केवल आपका DID और एक रिकवरी वाक्यांश।',
    K.onboardingCreate: 'नई पहचान बनाएँ',
    K.onboardingImport: 'मौजूदा पहचान आयात करें',
    K.feat1Title: 'Waku विकेंद्रीकृत नेटवर्क',
    K.feat1Desc:
        'संदेश Waku relay / store से फैलते हैं — बंद करने के लिए कोई केंद्र नहीं।',
    K.feat2Title: 'स्व-संप्रभु DID',
    K.feat2Desc:
        'आपकी Ethereum कुंजी से व्युत्पन्न did:ethr पहचान, केवल आपके पास।',
    K.feat3Title: 'एंड-टू-एंड एन्क्रिप्शन',
    K.feat3Desc:
        'X25519 + AES-GCM, और हर संदेश में secp256k1 हस्ताक्षर।',
    K.mnemonicTitle: 'आपका रिकवरी वाक्यांश',
    K.mnemonicDesc:
        'ये 12 शब्द ही आपकी पूरी पहचान हैं। इन्हें ऑफ़लाइन लिख लें।',
    K.mnemonicWarn:
        'इस वाक्यांश वाला कोई भी व्यक्ति आपकी पहचान पर पूरा नियंत्रण पा लेगा।',
    K.mnemonicCopied: 'रिकवरी वाक्यांश कॉपी हो गया',
    K.mnemonicNext: 'मैंने सहेज लिया है',
    K.verifyTitle: 'अपना बैकअप सत्यापित करें',
    K.verifyDesc: 'बैकअप सही है यह पुष्टि करने के लिए शब्द #%1\$s दर्ज करें।',
    K.verifyWrong: 'यह सही नहीं है, कृपया पुनः प्रयास करें।',
    K.verifyPlaceholder: 'शब्द #%1\$s',
    K.profileTitle: 'अपना कार्ड सेट करें',
    K.profileDesc: 'यह उपनाम आपके संपर्कों को दिखाया जाता है। कभी भी बदलें।',
    K.displayName: 'उपनाम',
    K.displayNameHint: 'जैसे Satoshi',
    K.enterApp: 'NexusChat में प्रवेश करें',
    K.restoreTitle: 'पहचान आयात करें',
    K.restoreDesc:
        'अपना 12 या 24 शब्दों का रिकवरी वाक्यांश दर्ज करें, जिसे स्थान से अलग किया गया हो।',
    K.restoreHint: 'apple banana ... स्थान से अलग',
    K.restoreError: 'अमान्य रिकवरी वाक्यांश। वर्तनी और क्रम जाँचें।',
    K.restoreSuccess: 'पहचान पुनर्स्थापित',
    K.importModeMnemonic: 'रिकवरी वाक्यांश',
    K.importModePrivateKey: 'निजी कुंजी',
    K.importPrivateKeyDesc:
        'उसी खाते को आयात करने के लिए 32-बाइट हेक्साडेसिमल निजी कुंजी पेस्ट करें (0x उपसर्ग वैकल्पिक)।',
    K.importPrivateKeyLabel: 'निजी कुंजी',
    K.importPrivateKeyHint: '0x या 64 हेक्स अक्षर',
    K.importPrivateKeyInvalid:
        'अमान्य निजी कुंजी। सुनिश्चित करें कि यह 64 हेक्साडेसिमल अक्षरों की हो।',
    K.importPrivateKeyAddress: 'व्युत्पन्न पता',
    K.importPrivateKeyWarn:
        'निजी कुंजी खाते पर पूरा नियंत्रण देती है। इसे किसी अविश्वसनीय डिवाइस पर कभी दर्ज न करें या किसी के साथ साझा न करें।',
    K.importPrivateKeyTitle: 'निजी कुंजी आयात करें',
    K.importPrivateKeySubtitle: 'वर्तमान पहचान को निजी कुंजी से बदलें',
    K.passwordLabel: 'पासवर्ड',
    K.passwordHint: 'कम से कम 8 अक्षर',
    K.passwordConfirmLabel: 'पासवर्ड की पुष्टि करें',
    K.passwordRule: 'बड़े और छोटे अक्षर, अंक और प्रतीक मिलाएँ; सामान्य पासवर्ड से बचें।',
    K.passwordWeak: 'बहुत कमज़ोर',
    K.passwordFair: 'ठीक-ठाक',
    K.passwordGood: 'अच्छा',
    K.passwordStrong: 'मज़बूत',
    K.passwordWeakError: 'पासवर्ड बहुत कमज़ोर है — लंबा या अधिक जटिल उपयोग करें',
    K.passwordMismatch: 'दोनों पासवर्ड मेल नहीं खाते',
    K.passwordSetupTitle: 'वॉल्ट पासवर्ड सेट करें',
    K.passwordSetupDesc:
        'आपका रिकवरी वाक्यांश और निजी कुंजी स्थानीय रूप से संग्रहीत होने से पहले इस पासवर्ड से एन्क्रिप्ट किए जाते हैं।',
    K.passwordForgotWarn:
        'यह पासवर्ड याद रखें। यह कभी अपलोड नहीं होता और रीसेट नहीं किया जा सकता — यदि आप इसे खो देते हैं, तो आपको नई पहचान बनानी होगी।',
    K.passwordWrong: 'ग़लत पासवर्ड',
    K.passwordChanged: 'पासवर्ड अपडेट हो गया',
    K.changePasswordFailed: 'पासवर्ड नहीं बदला जा सका',
    K.currentPassword: 'वर्तमान पासवर्ड',
    K.autoHideIn: '%1\$s सेकंड में स्वतः छिपेगा',
    K.passphraseAdvanced: 'उन्नत: BIP39 पासफ़्रेज़',
    K.passphraseLabel: 'पासफ़्रेज़ (वैकल्पिक)',
    K.passphraseHint: 'उपयोग न करने के लिए खाली छोड़ें',
    K.passphraseConfirmLabel: 'पासफ़्रेज़ की पुष्टि करें',
    K.passphraseDesc:
        'रिकवरी वाक्यांश और पासफ़्रेज़ मिलकर यह पहचान बनाते हैं। पासफ़्रेज़ केस-सेंसिटिव है और टाइपो पर कोई त्रुटि नहीं आएगी — यह बस एक अलग वॉलेट पुनर्स्थापित कर देगा। इसे वाक्यांश से अलग संग्रहीत करें।',
    K.passphraseMismatch: 'दोनों पासफ़्रेज़ मेल नहीं खाते',
    K.identityPassphrase: 'BIP39 पासफ़्रेज़',
    K.createFailed: 'पहचान नहीं बनाई जा सकी',
    K.restoreFailed: 'पहचान पुनर्स्थापित नहीं की जा सकी',
    K.importFailed: 'पहचान आयात नहीं की जा सकी',
    K.unlockTitle: 'लॉक है',
    K.unlockDesc: 'रिकवरी वाक्यांश और निजी कुंजी अनलॉक करने के लिए अपना पासवर्ड दर्ज करें।',
    K.unlockAction: 'अनलॉक',
    K.unlockWrong: 'ग़लत पासवर्ड',
    K.unlockCooldown: 'बहुत अधिक प्रयास — %1\$s सेकंड प्रतीक्षा करें',
    K.unlockForgot: 'पासवर्ड भूल गए?',
    K.unlockForgotTitle: 'पासवर्ड रीसेट नहीं किया जा सकता',
    K.unlockForgotDesc:
        'पासवर्ड केवल स्थानीय डिक्रिप्शन के लिए उपयोग होता है और कोई रीसेट क्रेडेंशियल संग्रहीत नहीं होता। यदि आपने इसे वाकई खो दिया है, तो आपको इस डिवाइस को मिटाकर अपने रिकवरी वाक्यांश से पुनः आयात करना होगा।',
    K.migrateTitle: 'अपनी पहचान एन्क्रिप्ट करें',
    K.migrateDesc:
        'इस डिवाइस पर रिकवरी वाक्यांश और निजी कुंजी वर्तमान में सादे पाठ में संग्रहीत हैं, जो स्थानीय स्टोरेज तक पहुँच वाले किसी भी प्रोग्राम द्वारा पढ़े जा सकते हैं। एन्क्रिप्टेड स्टोरेज पर स्विच करने के लिए पासवर्ड सेट करें।',
    K.migrateAction: 'एन्क्रिप्ट करें और जारी रखें',
    K.migrateFailed: 'एन्क्रिप्शन विफल — कृपया पुनः प्रयास करें',
    K.vaultUnavailableTitle: 'पहचान डेटा नहीं पढ़ा जा सका',
    K.vaultUnavailableDesc:
        'स्थानीय पहचान डेटा दोषपूर्ण है और डिक्रिप्ट नहीं किया जा सकता। यदि आपके पास अपना रिकवरी वाक्यांश बैकअप है, तो आप मिटाकर पुनः आयात कर सकते हैं।',
    K.wipe: 'स्थानीय डेटा मिटाएँ',
    K.wiped: 'स्थानीय डेटा मिटा दिया गया',
    K.exportVerifyTitle: 'अपनी पहचान सत्यापित करें',
    K.exportVerifyDesc:
        'रिकवरी वाक्यांश या निजी कुंजी दिखाने से पहले अपना वॉल्ट पासवर्ड दर्ज करें।',
    K.securitySection: 'सुरक्षा',
    K.securityLockNow: 'अभी लॉक करें',
    K.securityLockNowDesc: 'मेमोरी से रिकवरी वाक्यांश और निजी कुंजी हटाएँ',
    K.securityAutoLock: 'स्वतः लॉक',
    K.securityAutoLockNever: 'कभी नहीं',
    K.securityAutoLockMinutes: '%1\$s मिनट',
    K.securityHideSecrets: 'रहस्य स्वतः छिपाएँ',
    K.securityHideSecretsDesc: 'रिकवरी वाक्यांश कितने समय तक दिखे',
    K.securityLockOnHide: 'टैब छोड़ते समय लॉक करें',
    K.securityLockOnHideDesc: 'टैब फ़ोकस खोते ही तुरंत लॉक करें',
    K.securityChangePassword: 'पासवर्ड बदलें',
    K.securityChangePasswordDesc: 'वॉल्ट को पुनः एन्क्रिप्ट करें',
    K.chatTitle: 'चैट',
    K.chatEmpty: 'अभी कोई बातचीत नहीं',
    K.chatEmptyDesc: 'अपना पहला विकेंद्रीकृत मित्र जोड़ने के लिए संपर्क में जाएँ।',
    K.chatHint: 'संदेश लिखें…',
    K.chatEnterTip: 'भेजने के लिए Shift+Enter · नई पंक्ति के लिए Enter',
    K.chatNewMessages: 'नए संदेश',
    K.chatEncrypted: 'एंड-टू-एंड एन्क्रिप्टेड',
    K.chatSending: 'भेजा जा रहा है',
    K.chatSent: 'भेजा गया',
    K.chatDelivered: 'पहुँच गया',
    K.chatRead: 'पढ़ा गया',
    K.chatFailed: 'विफल',
    K.chatToday: 'आज',
    K.chatYesterday: 'कल',
    K.chatNew: 'नया',
    K.chatSearch: 'चैट या DID खोजें',
    K.chatTyping: 'लिख रहा है…',
    K.chatDeleteTitle: 'बातचीत हटाएँ',
    K.chatRecall: 'वापस लें',
    K.chatRecallConfirm: 'वापस लेने के बाद दोनों पक्षों को «संदेश वापस लिया गया» दिखेगा। जारी रखें?',
    K.chatRecalled: 'संदेश वापस लिया गया',
    K.chatDeleteMessageConfirm:
        'यह संदेश केवल इस डिवाइस से हटाता है; दूसरा पक्ष इसे रखता है। जारी रखें?',
    K.chatMessageDeleted: 'संदेश हटाया गया',
    K.chatDeleteConfirm: '%1\$s के साथ बातचीत हटाएँ? यह पूर्ववत नहीं किया जा सकता।',
    K.chatSecureTitle: 'यह बातचीत निजी है',
    K.chatSecureDesc:
        'संदेश Waku नेटवर्क में प्रवेश करने से पहले डिवाइस पर एन्क्रिप्ट किए जाते हैं।',
    K.chatPickContact: 'चैट शुरू करने के लिए एक संपर्क चुनें',
    K.chatUnread: 'अपठित',
    K.contactsTitle: 'संपर्क',
    K.contactsEmpty: 'अभी कोई संपर्क नहीं',
    K.contactsEmptyDesc: 'DID, Ethereum पते या ENS नाम से मित्र जोड़ें।',
    K.contactsAdd: 'संपर्क जोड़ें',
    K.contactsMyQr: 'मेरा QR कोड',
    K.contactsScanQr: 'QR कोड स्कैन करें',
    K.contactsDidLabel: 'DID / पता / ENS',
    K.contactsPasteDid: 'DID, 0x पता या ENS नाम पेस्ट करें',
    K.contactsInvalidDid: 'अज्ञात प्रारूप, कृपया जाँचें और पुनः प्रयास करें।',
    K.contactsAdded: 'संपर्क जोड़ा गया',
    K.contactsRequest: 'मित्र अनुरोध',
    K.contactsRemove: 'संपर्क हटाएँ',
    K.contactsRemoveConfirm: '%1\$s को हटाएँ?',
    K.contactsNickname: 'उपनाम',
    K.contactsScanHint:
        'NexusChat QR कोड स्कैन करें (इस बिल्ड में मान पेस्ट करना भी काम करता है)',
    K.walletTitle: 'वॉलेट',
    K.walletBalance: 'शेष',
    K.walletNetwork: 'नेटवर्क',
    K.walletAddress: 'पता',
    K.walletCopy: 'पता कॉपी करें',
    K.walletExplorer: 'एक्सप्लोरर पर देखें',
    K.walletRpcUrl: 'RPC एंडपॉइंट',
    K.walletChainId: 'चेन ID',
    K.walletRefresh: 'शेष ताज़ा करें',
    K.walletNoRpc: 'कोई RPC एंडपॉइंट कॉन्फ़िगर नहीं, शेष उपलब्ध नहीं।',
    K.walletEns: 'ENS नाम',
    K.walletDid: 'DID',
    K.walletTokens: 'संपत्ति',
    K.walletSend: 'ट्रांसफ़र',
    K.walletChain: 'ब्लॉकचेन',
    K.walletChainDesc:
        'केवल यह बदलता है कि वॉलेट कौन सी चेन दिखाता है; चैट पहचान did:ethr ही रहती है।',
    K.walletTronRpc: 'TRON RPC एंडपॉइंट',
    K.walletBesuRpc: 'WEB6 RPC एंडपॉइंट',
    K.chainEthereum: 'Ethereum',
    K.chainBase: 'Base',
    K.chainArbitrum: 'Arbitrum',
    K.chainBsc: 'BNB Chain',
    K.chainTron: 'TRON',
    K.chainBesu: 'WEB6',
    K.walletReceive: 'प्राप्त करें',
    K.walletSendTitle: 'भेजें',
    K.walletSendTo: 'प्राप्तकर्ता का पता',
    K.walletSendToHint: 'प्राप्तकर्ता का पता पेस्ट या टाइप करें',
    K.walletAmount: 'राशि',
    K.walletAmountHint: '0.0',
    K.walletAvailable: 'उपलब्ध',
    K.walletSendConfirm: 'ट्रांसफ़र की पुष्टि करें',
    K.walletSendConfirmTitle: 'ट्रांसफ़र विवरण की समीक्षा करें',
    K.walletSending: 'लेन-देन प्रसारित हो रहा है…',
    K.walletSendSuccess: 'ट्रांसफ़र भेजा गया',
    K.walletSendFailed: 'ट्रांसफ़र विफल',
    K.walletTxHash: 'लेन-देन हैश',
    K.walletViewTx: 'ब्लॉक एक्सप्लोरर में देखें',
    K.walletErrInvalidAddress: 'अमान्य प्राप्तकर्ता पता',
    K.walletErrInvalidAmount: '0 से बड़ी राशि दर्ज करें',
    K.walletErrInsufficient: 'अपर्याप्त शेष (शुल्क सहित)',
    K.walletErrNoRpc: 'कोई RPC एंडपॉइंट कॉन्फ़िगर नहीं',
    K.walletErrNetwork: 'नेटवर्क त्रुटि, कृपया बाद में पुनः प्रयास करें',
    K.walletReceiveDesc: 'धन प्राप्त करने के लिए इस पते या QR कोड को साझा करें',
    K.walletUseMax: 'अधिकतम',
    K.walletSendNetwork: 'ट्रांसफ़र नेटवर्क',
    K.walletSendNetworkNotice:
        r'%1$s पर भेजा जा रहा है। सुनिश्चित करें कि प्राप्तकर्ता का पता इसी नेटवर्क का हो।',
    K.walletSwitchNetwork: 'नेटवर्क बदलें',
    K.walletErrChainMismatch: 'यह पता वर्तमान नेटवर्क का नहीं है',
    K.walletScanAddress: 'प्राप्तकर्ता का पता स्कैन करें',
    K.walletRpcMismatch: 'RPC एंडपॉइंट चयनित नेटवर्क से भिन्न नेटवर्क बताता है',
    K.walletRpcUrlHint: 'डिफ़ॉल्ट एंडपॉइंट उपयोग करने के लिए खाली छोड़ें',
    K.walletNativeToken: 'नेटिव टोकन',
    K.tokenAdd: 'टोकन जोड़ें',
    K.tokenAddTitle: 'कस्टम टोकन जोड़ें',
    K.tokenAdded: 'टोकन जोड़ा गया',
    K.tokenTabErc20: 'टोकन',
    K.tokenTabErc721: 'NFT',
    K.tokenTabErc1155: 'एसेट सेट',
    K.tokenEmpty: 'इस प्रकार का कोई टोकन नहीं',
    K.tokenCustom: 'कस्टम',
    K.tokenCopyContract: 'कॉन्ट्रैक्ट कॉपी करें',
    K.tokenViewExplorer: 'एक्सप्लोरर में देखें',
    K.tokenRemove: 'हटाएँ',
    K.tokenRemoveConfirm: 'यह कस्टम टोकन हटाएँ?',
    K.tokenName: 'नाम',
    K.tokenSymbol: 'प्रतीक',
    K.tokenStandard: 'प्रकार',
    K.tokenDecimals: 'दशमलव',
    K.tokenContract: 'कॉन्ट्रैक्ट',
    K.tokenIcon: 'आइकन (इमोजी)',
    K.tokenColor: 'रंग (#RRGGBB)',
    K.tokenTypeErc20: 'ERC-20 टोकन',
    K.tokenTypeErc721: 'ERC-721 NFT',
    K.tokenTypeErc1155: 'ERC-1155 एसेट सेट',
    K.tokenTypeNative: 'नेटिव टोकन',
    K.tokenErrNameSymbol: 'नाम और प्रतीक दर्ज करें',
    K.tokenInvalidAddress: 'वैध कॉन्ट्रैक्ट पता दर्ज करें',
    K.tokenInvalidDecimals: 'दशमलव 0 से 36 के बीच पूर्णांक होना चाहिए',
    K.tokenErrTronToken:
        'TRC-20 ट्रांसफ़र अभी समर्थित नहीं; नेटिव TRX या अन्य टूल उपयोग करें',
    K.tokenHistoryTitle: 'भेजने का इतिहास',
    K.tokenHistoryEmpty: 'अभी कोई भेजने का इतिहास नहीं',
    K.tokenNotTransferable: 'यह टोकन एक NFT है और ट्रांसफ़र नहीं किया जा सकता',
    K.chatImage: 'फ़ोटो',
    K.chatVoice: 'वॉइस संदेश',
    K.chatSendImage: 'फ़ोटो भेजें',
    K.chatRecord: 'रिकॉर्ड',
    K.chatRecording: 'रिकॉर्ड हो रहा है…',
    K.chatStop: 'रोकें',
    K.chatCancel: 'रद्द करें',
    K.chatMediaTooLarge: 'मीडिया बहुत बड़ा है। छोटी छवि चुनें या रिकॉर्डिंग छोटी करें।',
    K.chatPermissionMicrophone: 'ऑडियो रिकॉर्ड करने के लिए माइक्रोफ़ोन अनुमति आवश्यक है।',
    K.chatPermissionPhotos: 'छवि चुनने के लिए फ़ोटो लाइब्रेरी अनुमति आवश्यक है।',
    K.chatImagePickFailed: 'चयनित छवि नहीं पढ़ी जा सकी। कृपया JPG / PNG उपयोग करें।',
    K.chatImageUnavailable: 'छवि उपलब्ध नहीं',
    K.chatImageUnsupported: 'असमर्थित छवि। कृपया JPG या PNG उपयोग करें।',
    K.chatImageDownload: 'छवि डाउनलोड करें',
    K.chatImageSaved: 'छवि सहेजी गई',
    K.chatImageSavedToAlbum: 'छवि एल्बम में सहेजी गई',
    K.chatImageSaveFailed: 'छवि सहेजी नहीं जा सकी',
    K.chatImageZoomIn: 'ज़ूम इन',
    K.chatImageZoomOut: 'ज़ूम आउट',
    K.chatImageReset: 'रीसेट',
    K.settingsTitle: 'सेटिंग्स',
    K.settingsAppearance: 'रूप-रंग',
    K.settingsTheme: 'थीम',
    K.settingsThemeSystem: 'सिस्टम',
    K.settingsThemeLight: 'लाइट',
    K.settingsThemeDark: 'डार्क',
    K.settingsLanguage: 'भाषा',
    K.settingsNetwork: 'नेटवर्क',
    K.settingsWakuNode: 'Waku नोड',
    K.settingsWakuTest: 'पुनः जाँच',
    K.settingsWakuOk: 'पहुँच योग्य',
    K.settingsWakuFail: 'पहुँच योग्य नहीं',
    K.settingsNodesDesc:
        'संदेश केवल चयनित नोड से होकर जाते हैं; नोड बदलने के लिए टैप करें। बिल्ट-इन नोड हटाए नहीं जा सकते।',
    K.settingsNodeBuiltin: 'बिल्ट-इन',
    K.settingsNodeCustom: 'कस्टम',
    K.settingsNodeAdd: 'नोड जोड़ें',
    K.settingsNodeAddTitle: 'Waku नोड जोड़ें',
    K.settingsNodeAddHint: 'जैसे https://waku03.example.com',
    K.settingsNodeAdded: 'नोड जोड़ा गया',
    K.settingsNodeRemove: 'नोड हटाएँ',
    K.settingsNodeRemoveConfirm: '%1\$s को हटाएँ?',
    K.settingsNodeInvalid: 'अमान्य नोड पता',
    K.settingsNodeDuplicate: 'यह नोड पहले से मौजूद है',
    K.settingsNodeChecking: 'जाँच हो रही है',
    K.settingsResync: 'संदेश इतिहास पुनः लाएँ',
    K.settingsResyncDesc: 'नोड स्टोर से छूटे संदेश और कुंजी बंडल लाएँ (अंतिम 48 घंटे)',
    K.settingsResyncDone: 'इतिहास पुनः लाया गया',
    K.settingsBackup: 'पहचान का बैकअप',
    K.settingsDelete: 'इस डिवाइस से पहचान हटाएँ',
    K.settingsDeleteConfirm: 'यह स्थानीय पहचान और सभी बातचीत मिटा देगा। जारी रखें?',
    K.settingsAbout: 'परिचय',
    K.settingsLicense: 'ओपन सोर्स लाइसेंस',
    K.settingsThirdPartyLicenses: 'तृतीय-पक्ष लाइसेंस',
    K.settingsVersion: 'संस्करण',
    K.updateCheck: 'अपडेट जाँचें',
    K.updateChecking: 'अपडेट जाँचा जा रहा है…',
    K.updateLatest: 'नवीनतम है',
    K.updateAvailableTitle: 'अपडेट उपलब्ध',
    K.updateVersionLine: 'v%1\$s (बिल्ड %2\$s)',
    K.updatePublished: '%1\$s को प्रकाशित',
    K.updateNow: 'अभी अपडेट करें',
    K.updateLater: 'बाद में',
    K.updateFailed: 'अपडेट जाँचा नहीं जा सका। बाद में पुनः प्रयास करें।',
    K.updateRefresh: 'पृष्ठ ताज़ा करें',
    K.updateWebHint:
        'वेब ऐप GitHub Pages पर होस्ट है; नवीनतम संस्करण पाने के लिए बस पृष्ठ ताज़ा करें।',
    K.updateLaunchFailed:
        'डाउनलोड लिंक नहीं खोला जा सका। बाद में पुनः प्रयास करें या QR कोड स्कैन करें।',
    K.scanToDownload: 'डाउनलोड करने के लिए स्कैन करें',
    K.settingsAdvanced: 'उन्नत',
    K.settingsGroupGeneral: 'सामान्य',
    K.settingsGroupAccount: 'खाता',
    K.settingsGroupConnection: 'कनेक्शन',
    K.settingsGroupDanger: 'खतरा क्षेत्र',
    K.settingsSubAppearance: 'थीम शैली और इंटरफ़ेस भाषा',
    K.settingsSubSecurity: 'लॉक, स्वतः लॉक और पासवर्ड',
    K.settingsSubNetwork: 'Waku नोड और कनेक्टिविटी',
    K.settingsSubBlockchain: 'चेन और RPC एंडपॉइंट',
    K.settingsSubIdentity: 'DID और बैकअप',
    K.settingsSubImportKey: 'निजी कुंजी से पहचान पुनर्स्थापित करें',
    K.settingsSubAbout: 'संस्करण और अपडेट',
    K.settingsSubDanger: 'इस डिवाइस से पहचान हटाएँ',
    K.settingsClearCache: 'कैश साफ़ करें',
    K.settingsCacheCleared: 'कैश साफ़ हो गया',
    K.settingsPublishKeys: 'कुंजी बंडल पुनः प्रकाशित करें',
    K.settingsKeysPublished: 'कुंजी बंडल Waku पर प्रकाशित',
    K.identityTitle: 'मेरी पहचान',
    K.identityDid: 'विकेंद्रीकृत पहचानकर्ता',
    K.identityMethod: 'DID विधि',
    K.identityEthAddress: 'Ethereum पता',
    K.identitySignKey: 'हस्ताक्षर सार्वजनिक कुंजी',
    K.identityEncKey: 'एन्क्रिप्शन सार्वजनिक कुंजी',
    K.identityBackup: 'रिकवरी वाक्यांश का बैकअप',
    K.identityBackupDesc: 'रिकवरी वाक्यांश आपकी पहचान में वापस आने का एकमात्र तरीका है।',
    K.identityShowMnemonic: 'रिकवरी वाक्यांश दिखाएँ',
    K.identityHideMnemonic: 'रिकवरी वाक्यांश छिपाएँ',
    K.identityConfirmBackup: 'मैंने अपना वाक्यांश सहेज लिया है',
    K.identityRisk: 'जोखिम सूचना',
    K.errorGeneric: 'कुछ गड़बड़ हो गई, कृपया पुनः प्रयास करें।',
    K.errorNetwork: 'नेटवर्क कनेक्शन विफल',
    K.errorInvalidInput: 'अमान्य इनपुट',
    K.errorCrypto: 'एन्क्रिप्शन या डिक्रिप्शन विफल',
    K.errorNotFound: 'नहीं मिला',
    K.errorTimeout: 'कनेक्शन समय समाप्त',
    K.timeJustNow: 'अभी',
    K.timeMinutesAgo: '%1\$d मिनट पहले',
    K.timeHoursAgo: '%1\$d घंटे पहले',
  },

  // =============================================================== Français
  // 注意：法文大量使用撇號，這裡一律用排版撇號 ’（U+2019），
  // 避免與 Dart 的單引號字串衝突而需要一堆跳脫。
  'fr': {
    K.appName: 'NexusChat',
    K.appTagline: 'Décentralisé · Chiffré de bout en bout · Rien qu’à vous',
    K.ok: 'OK',
    K.cancel: 'Annuler',
    K.confirm: 'Confirmer',
    K.save: 'Enregistrer',
    K.copy: 'Copier',
    K.copied: 'Copié',
    K.close: 'Fermer',
    K.delete: 'Supprimer',
    K.edit: 'Modifier',
    K.search: 'Rechercher',
    K.retry: 'Réessayer',
    K.loading: 'Chargement',
    K.back: 'Retour',
    K.next: 'Suivant',
    K.done: 'Terminé',
    K.reveal: 'Afficher',
    K.hide: 'Masquer',
    K.more: 'Plus',
    K.share: 'Partager',
    K.importAction: 'Importer',
    K.exportAction: 'Exporter',
    K.refresh: 'Actualiser',
    K.send: 'Envoyer',
    K.unknown: 'Inconnu',
    K.optional: 'Facultatif',
    K.comingSoon: 'Bientôt disponible',
    K.statusOnline: 'En ligne',
    K.statusOffline: 'Hors ligne',
    K.statusConnecting: 'Connexion',
    K.statusConnected: 'Connecté',
    K.statusSyncing: 'Synchronisation',
    K.statusNoPeers: 'Aucun pair',
    K.statusNoPeersHint:
        'Le REST du nœud est joignable mais il n’a aucun pair : les messages ne peuvent donc pas être relayés.',
    K.navChats: 'Discussions',
    K.navContacts: 'Contacts',
    K.navWallet: 'Portefeuille',
    K.navDiscover: 'Découvrir',
    K.navSettings: 'Paramètres',
    K.navMe: 'Moi',
    K.discoverTitle: 'Découvrir',
    K.discoverSubtitle: 'Explorez davantage NexusChat',
    K.discoverTools: 'Outils',
    K.discoverScan: 'Scanner',
    K.discoverScanDesc: 'Scannez un QR code — les liens s’ouvrent immédiatement',
    K.scanTitle: 'Scanner',
    K.scanHint: 'Placez le QR code dans le cadre pour qu’il soit détecté automatiquement',
    K.scanTorch: 'Lampe torche',
    K.scanSwitchCamera: 'Changer de caméra',
    K.scanUnsupportedTitle: 'Le scan n’est pas pris en charge ici',
    K.scanUnsupportedDesc:
        'Seuls Android, iOS, macOS et le navigateur sont pris en charge. Utilisez un appareil mobile ou la version web.',
    K.scanPermissionTitle: 'Autorisation caméra requise',
    K.scanPermissionDesc:
        'Autorisez NexusChat à utiliser la caméra dans les paramètres système pour scanner des QR codes.',
    K.scanCameraError: 'La caméra n’a pas pu démarrer, veuillez réessayer.',
    K.scanResultTitle: 'Résultat du scan',
    K.scanResultDid: 'Identité NexusChat (DID)',
    K.scanResultAddress: 'Adresse Ethereum',
    K.scanResultEns: 'Nom ENS',
    K.scanResultText: 'Texte',
    K.scanAddContact: 'Ajouter le contact',
    K.scanOpenFailed: 'Impossible d’ouvrir ce lien',
    K.scanPayAction: 'Y envoyer',
    K.scanResultPayment: 'Demande de paiement',
    K.scanPickHint: 'Pointez la caméra vers le QR code du destinataire',
    K.scanPickInvalid: 'Ceci n’est pas une adresse de destinataire valide',
    K.onboardingTitle: 'Des conversations privées, réinventées',
    K.onboardingSubtitle:
        'Pas de serveur, pas de numéro de téléphone. Juste votre DID et une phrase de récupération.',
    K.onboardingCreate: 'Créer une nouvelle identité',
    K.onboardingImport: 'Importer une identité existante',
    K.feat1Title: 'Réseau décentralisé Waku',
    K.feat1Desc:
        'Les messages circulent via le relay / store Waku — rien de central à arrêter.',
    K.feat2Title: 'DID auto-souverain',
    K.feat2Desc:
        'Une identité did:ethr dérivée de votre clé Ethereum, détenue par vous seul.',
    K.feat3Title: 'Chiffrement de bout en bout',
    K.feat3Desc:
        'X25519 + AES-GCM, et chaque message porte une signature secp256k1.',
    K.mnemonicTitle: 'Votre phrase de récupération',
    K.mnemonicDesc:
        'Ces 12 mots constituent toute votre identité. Notez-les hors ligne.',
    K.mnemonicWarn:
        'Toute personne disposant de cette phrase prend le contrôle total de votre identité.',
    K.mnemonicCopied: 'Phrase de récupération copiée',
    K.mnemonicNext: 'Je l’ai enregistrée',
    K.verifyTitle: 'Vérifiez votre sauvegarde',
    K.verifyDesc: 'Saisissez le mot n° %1\$s pour confirmer que votre sauvegarde est correcte.',
    K.verifyWrong: 'Ce n’est pas correct, veuillez réessayer.',
    K.verifyPlaceholder: 'Mot n° %1\$s',
    K.profileTitle: 'Configurez votre carte',
    K.profileDesc: 'Ce pseudonyme est visible par vos contacts. Modifiable à tout moment.',
    K.displayName: 'Pseudonyme',
    K.displayNameHint: 'ex. Satoshi',
    K.enterApp: 'Entrer dans NexusChat',
    K.restoreTitle: 'Importer une identité',
    K.restoreDesc:
        'Saisissez votre phrase de récupération de 12 ou 24 mots, séparés par des espaces.',
    K.restoreHint: 'apple banana ... séparés par des espaces',
    K.restoreError: 'Phrase de récupération invalide. Vérifiez l’orthographe et l’ordre.',
    K.restoreSuccess: 'Identité restaurée',
    K.importModeMnemonic: 'Phrase de récupération',
    K.importModePrivateKey: 'Clé privée',
    K.importPrivateKeyDesc:
        'Collez une clé privée hexadécimale de 32 octets (préfixe 0x facultatif) pour importer le même compte.',
    K.importPrivateKeyLabel: 'Clé privée',
    K.importPrivateKeyHint: '0x ou 64 caractères hexadécimaux',
    K.importPrivateKeyInvalid:
        'Clé privée invalide. Assurez-vous qu’elle contient 64 caractères hexadécimaux.',
    K.importPrivateKeyAddress: 'Adresse dérivée',
    K.importPrivateKeyWarn:
        'Une clé privée donne le contrôle total du compte. Ne la saisissez jamais sur un appareil non fiable et ne la partagez avec personne.',
    K.importPrivateKeyTitle: 'Importer une clé privée',
    K.importPrivateKeySubtitle: 'Remplacer l’identité actuelle par une clé privée',
    K.passwordLabel: 'Mot de passe',
    K.passwordHint: 'Au moins 8 caractères',
    K.passwordConfirmLabel: 'Confirmer le mot de passe',
    K.passwordRule:
        'Mélangez majuscules, minuscules, chiffres et symboles ; évitez les mots de passe courants.',
    K.passwordWeak: 'Trop faible',
    K.passwordFair: 'Moyen',
    K.passwordGood: 'Bon',
    K.passwordStrong: 'Fort',
    K.passwordWeakError: 'Mot de passe trop faible — choisissez-en un plus long ou plus complexe',
    K.passwordMismatch: 'Les deux mots de passe ne correspondent pas',
    K.passwordSetupTitle: 'Définir un mot de passe de coffre',
    K.passwordSetupDesc:
        'Votre phrase et votre clé privée sont chiffrées avec ce mot de passe avant d’être stockées localement.',
    K.passwordForgotWarn:
        'Retenez ce mot de passe. Il n’est jamais envoyé et ne peut pas être réinitialisé — si vous le perdez, vous devrez créer une nouvelle identité.',
    K.passwordWrong: 'Mot de passe incorrect',
    K.passwordChanged: 'Mot de passe mis à jour',
    K.changePasswordFailed: 'Impossible de modifier le mot de passe',
    K.currentPassword: 'Mot de passe actuel',
    K.autoHideIn: 'Masquage automatique dans %1\$s s',
    K.passphraseAdvanced: 'Avancé : phrase secrète BIP39',
    K.passphraseLabel: 'Phrase secrète (facultatif)',
    K.passphraseHint: 'Laissez vide pour ne pas en utiliser',
    K.passphraseConfirmLabel: 'Confirmer la phrase secrète',
    K.passphraseDesc:
        'La phrase de récupération et la phrase secrète produisent ensemble cette identité. La phrase secrète est sensible à la casse et une faute de frappe ne provoquera aucune erreur — elle restaurera simplement un autre portefeuille. Conservez-la séparément de la phrase de récupération.',
    K.passphraseMismatch: 'Les deux phrases secrètes ne correspondent pas',
    K.identityPassphrase: 'Phrase secrète BIP39',
    K.createFailed: 'Impossible de créer l’identité',
    K.restoreFailed: 'Impossible de restaurer l’identité',
    K.importFailed: 'Impossible d’importer l’identité',
    K.unlockTitle: 'Verrouillé',
    K.unlockDesc:
        'Saisissez votre mot de passe pour déverrouiller la phrase de récupération et la clé privée.',
    K.unlockAction: 'Déverrouiller',
    K.unlockWrong: 'Mot de passe incorrect',
    K.unlockCooldown: 'Trop de tentatives — attendez %1\$s s',
    K.unlockForgot: 'Mot de passe oublié ?',
    K.unlockForgotTitle: 'Le mot de passe ne peut pas être réinitialisé',
    K.unlockForgotDesc:
        'Le mot de passe sert uniquement au déchiffrement local et aucun identifiant de réinitialisation n’est conservé. Si vous l’avez vraiment perdu, vous devez effacer cet appareil et réimporter avec votre phrase de récupération.',
    K.migrateTitle: 'Chiffrez votre identité',
    K.migrateDesc:
        'La phrase de récupération et la clé privée sur cet appareil sont actuellement stockées en clair, lisibles par tout programme ayant accès au stockage local. Définissez un mot de passe pour passer à un stockage chiffré.',
    K.migrateAction: 'Chiffrer et continuer',
    K.migrateFailed: 'Échec du chiffrement — veuillez réessayer',
    K.vaultUnavailableTitle: 'Impossible de lire les données d’identité',
    K.vaultUnavailableDesc:
        'Les données d’identité locales sont endommagées et ne peuvent pas être déchiffrées. Si vous disposez de votre sauvegarde de phrase, vous pouvez effacer et réimporter.',
    K.wipe: 'Effacer les données locales',
    K.wiped: 'Données locales effacées',
    K.exportVerifyTitle: 'Vérifiez votre identité',
    K.exportVerifyDesc:
        'Saisissez votre mot de passe de coffre avant d’afficher la phrase de récupération ou la clé privée.',
    K.securitySection: 'Sécurité',
    K.securityLockNow: 'Verrouiller maintenant',
    K.securityLockNowDesc: 'Effacer de la mémoire la phrase et la clé privée',
    K.securityAutoLock: 'Verrouillage automatique',
    K.securityAutoLockNever: 'Jamais',
    K.securityAutoLockMinutes: '%1\$s min',
    K.securityHideSecrets: 'Masquage auto des secrets',
    K.securityHideSecretsDesc: 'Durée d’affichage de la phrase de récupération',
    K.securityLockOnHide: 'Verrouiller en quittant l’onglet',
    K.securityLockOnHideDesc: 'Verrouiller dès que l’onglet perd le focus',
    K.securityChangePassword: 'Changer le mot de passe',
    K.securityChangePasswordDesc: 'Rechiffrer le coffre',
    K.chatTitle: 'Discussions',
    K.chatEmpty: 'Aucune conversation pour l’instant',
    K.chatEmptyDesc: 'Allez dans Contacts pour ajouter votre premier ami décentralisé.',
    K.chatHint: 'Écrivez un message…',
    K.chatEnterTip: 'Shift+Entrée pour envoyer · Entrée pour une nouvelle ligne',
    K.chatNewMessages: 'Nouveaux messages',
    K.chatEncrypted: 'Chiffré de bout en bout',
    K.chatSending: 'Envoi',
    K.chatSent: 'Envoyé',
    K.chatDelivered: 'Reçu',
    K.chatRead: 'Lu',
    K.chatFailed: 'Échec',
    K.chatToday: 'Aujourd’hui',
    K.chatYesterday: 'Hier',
    K.chatNew: 'Nouveau',
    K.chatSearch: 'Rechercher des discussions ou un DID',
    K.chatTyping: 'écrit…',
    K.chatDeleteTitle: 'Supprimer la conversation',
    K.chatRecall: 'Rappeler',
    K.chatRecallConfirm: 'Après le rappel, les deux côtés verront « Message rappelé ». Continuer ?',
    K.chatRecalled: 'Message rappelé',
    K.chatDeleteMessageConfirm:
        'Ceci supprime le message uniquement sur cet appareil ; l’autre côté le conserve. Continuer ?',
    K.chatMessageDeleted: 'Message supprimé',
    K.chatDeleteConfirm: 'Supprimer la conversation avec %1\$s ? Cette action est irréversible.',
    K.chatSecureTitle: 'Cette conversation est privée',
    K.chatSecureDesc:
        'Les messages sont chiffrés sur l’appareil avant d’entrer dans le réseau Waku.',
    K.chatPickContact: 'Choisissez un contact pour commencer à discuter',
    K.chatUnread: 'Non lu',
    K.contactsTitle: 'Contacts',
    K.contactsEmpty: 'Aucun contact pour l’instant',
    K.contactsEmptyDesc: 'Ajoutez un ami par DID, adresse Ethereum ou nom ENS.',
    K.contactsAdd: 'Ajouter un contact',
    K.contactsMyQr: 'Mon QR code',
    K.contactsScanQr: 'Scanner un QR code',
    K.contactsDidLabel: 'DID / adresse / ENS',
    K.contactsPasteDid: 'Collez un DID, une adresse 0x ou un nom ENS',
    K.contactsInvalidDid: 'Format non reconnu, vérifiez et réessayez.',
    K.contactsAdded: 'Contact ajouté',
    K.contactsRequest: 'Demande d’ami',
    K.contactsRemove: 'Supprimer le contact',
    K.contactsRemoveConfirm: 'Supprimer %1\$s ?',
    K.contactsNickname: 'Pseudonyme',
    K.contactsScanHint:
        'Scannez un QR code NexusChat (coller la valeur fonctionne aussi dans cette version)',
    K.walletTitle: 'Portefeuille',
    K.walletBalance: 'Solde',
    K.walletNetwork: 'Réseau',
    K.walletAddress: 'Adresse',
    K.walletCopy: 'Copier l’adresse',
    K.walletExplorer: 'Voir sur l’explorateur',
    K.walletRpcUrl: 'Point de terminaison RPC',
    K.walletChainId: 'ID de chaîne',
    K.walletRefresh: 'Actualiser le solde',
    K.walletNoRpc: 'Aucun point de terminaison RPC configuré, solde indisponible.',
    K.walletEns: 'Nom ENS',
    K.walletDid: 'DID',
    K.walletTokens: 'Actifs',
    K.walletSend: 'Transférer',
    K.walletChain: 'Blockchain',
    K.walletChainDesc:
        'Change uniquement la chaîne affichée par le portefeuille ; l’identité de chat reste did:ethr.',
    K.walletTronRpc: 'Point de terminaison RPC TRON',
    K.walletBesuRpc: 'Point de terminaison RPC WEB6',
    K.chainEthereum: 'Ethereum',
    K.chainBase: 'Base',
    K.chainArbitrum: 'Arbitrum',
    K.chainBsc: 'BNB Chain',
    K.chainTron: 'TRON',
    K.chainBesu: 'WEB6',
    K.walletReceive: 'Recevoir',
    K.walletSendTitle: 'Envoyer',
    K.walletSendTo: 'Adresse du destinataire',
    K.walletSendToHint: 'Collez ou saisissez une adresse de destinataire',
    K.walletAmount: 'Montant',
    K.walletAmountHint: '0.0',
    K.walletAvailable: 'Disponible',
    K.walletSendConfirm: 'Confirmer le transfert',
    K.walletSendConfirmTitle: 'Vérifier les détails du transfert',
    K.walletSending: 'Diffusion de la transaction…',
    K.walletSendSuccess: 'Transfert envoyé',
    K.walletSendFailed: 'Échec du transfert',
    K.walletTxHash: 'Hash de la transaction',
    K.walletViewTx: 'Voir dans l’explorateur de blocs',
    K.walletErrInvalidAddress: 'Adresse de destinataire invalide',
    K.walletErrInvalidAmount: 'Saisissez un montant supérieur à 0',
    K.walletErrInsufficient: 'Solde insuffisant (frais inclus)',
    K.walletErrNoRpc: 'Aucun point de terminaison RPC configuré',
    K.walletErrNetwork: 'Erreur réseau, veuillez réessayer plus tard',
    K.walletReceiveDesc: 'Partagez cette adresse ou ce QR code pour recevoir des fonds',
    K.walletUseMax: 'Max',
    K.walletSendNetwork: 'Réseau de transfert',
    K.walletSendNetworkNotice:
        r'Envoi sur %1$s. Assurez-vous que l’adresse du destinataire appartient à ce réseau.',
    K.walletSwitchNetwork: 'Changer de réseau',
    K.walletErrChainMismatch: 'Cette adresse n’appartient pas au réseau actuel',
    K.walletScanAddress: 'Scanner une adresse de destinataire',
    K.walletRpcMismatch:
        'Le point de terminaison RPC indique un réseau différent de celui sélectionné',
    K.walletRpcUrlHint: 'Laissez vide pour utiliser le point de terminaison par défaut',
    K.walletNativeToken: 'Jeton natif',
    K.tokenAdd: 'Ajouter un jeton',
    K.tokenAddTitle: 'Ajouter un jeton personnalisé',
    K.tokenAdded: 'Jeton ajouté',
    K.tokenTabErc20: 'Jetons',
    K.tokenTabErc721: 'NFT',
    K.tokenTabErc1155: 'Ensembles d’actifs',
    K.tokenEmpty: 'Aucun jeton de ce type',
    K.tokenCustom: 'Personnalisé',
    K.tokenCopyContract: 'Copier le contrat',
    K.tokenViewExplorer: 'Voir dans l’explorateur',
    K.tokenRemove: 'Supprimer',
    K.tokenRemoveConfirm: 'Supprimer ce jeton personnalisé ?',
    K.tokenName: 'Nom',
    K.tokenSymbol: 'Symbole',
    K.tokenStandard: 'Type',
    K.tokenDecimals: 'Décimales',
    K.tokenContract: 'Contrat',
    K.tokenIcon: 'Icône (emoji)',
    K.tokenColor: 'Couleur (#RRGGBB)',
    K.tokenTypeErc20: 'Jeton ERC-20',
    K.tokenTypeErc721: 'NFT ERC-721',
    K.tokenTypeErc1155: 'Ensemble d’actifs ERC-1155',
    K.tokenTypeNative: 'Jeton natif',
    K.tokenErrNameSymbol: 'Saisissez un nom et un symbole',
    K.tokenInvalidAddress: 'Saisissez une adresse de contrat valide',
    K.tokenInvalidDecimals: 'Les décimales doivent être un entier de 0 à 36',
    K.tokenErrTronToken:
        'Les transferts TRC-20 ne sont pas encore pris en charge ; utilisez le TRX natif ou un autre outil',
    K.tokenHistoryTitle: 'Historique des envois',
    K.tokenHistoryEmpty: 'Aucun historique d’envoi pour l’instant',
    K.tokenNotTransferable: 'Ce jeton est un NFT et ne peut pas être transféré',
    K.chatImage: 'Photo',
    K.chatVoice: 'Message vocal',
    K.chatSendImage: 'Envoyer une photo',
    K.chatRecord: 'Enregistrer',
    K.chatRecording: 'Enregistrement…',
    K.chatStop: 'Arrêter',
    K.chatCancel: 'Annuler',
    K.chatMediaTooLarge:
        'Média trop volumineux. Choisissez une image plus petite ou raccourcissez l’enregistrement.',
    K.chatPermissionMicrophone: 'L’autorisation du microphone est requise pour enregistrer un audio.',
    K.chatPermissionPhotos:
        'L’autorisation de la bibliothèque photo est requise pour choisir une image.',
    K.chatImagePickFailed: 'Impossible de lire l’image sélectionnée. Utilisez JPG / PNG.',
    K.chatImageUnavailable: 'Image indisponible',
    K.chatImageUnsupported: 'Image non prise en charge. Utilisez JPG ou PNG.',
    K.chatImageDownload: 'Télécharger l’image',
    K.chatImageSaved: 'Image enregistrée',
    K.chatImageSavedToAlbum: 'Image enregistrée dans l’album',
    K.chatImageSaveFailed: 'Impossible d’enregistrer l’image',
    K.chatImageZoomIn: 'Zoom avant',
    K.chatImageZoomOut: 'Zoom arrière',
    K.chatImageReset: 'Réinitialiser',
    K.settingsTitle: 'Paramètres',
    K.settingsAppearance: 'Apparence',
    K.settingsTheme: 'Thème',
    K.settingsThemeSystem: 'Système',
    K.settingsThemeLight: 'Clair',
    K.settingsThemeDark: 'Sombre',
    K.settingsLanguage: 'Langue',
    K.settingsNetwork: 'Réseau',
    K.settingsWakuNode: 'Nœuds Waku',
    K.settingsWakuTest: 'Revérifier',
    K.settingsWakuOk: 'Joignable',
    K.settingsWakuFail: 'Injoignable',
    K.settingsNodesDesc:
        'Les messages passent uniquement par le nœud sélectionné ; touchez un nœud pour changer. Les nœuds intégrés ne peuvent pas être supprimés.',
    K.settingsNodeBuiltin: 'Intégré',
    K.settingsNodeCustom: 'Personnalisé',
    K.settingsNodeAdd: 'Ajouter un nœud',
    K.settingsNodeAddTitle: 'Ajouter un nœud Waku',
    K.settingsNodeAddHint: 'ex. https://waku03.example.com',
    K.settingsNodeAdded: 'Nœud ajouté',
    K.settingsNodeRemove: 'Supprimer le nœud',
    K.settingsNodeRemoveConfirm: 'Supprimer %1\$s ?',
    K.settingsNodeInvalid: 'Adresse de nœud invalide',
    K.settingsNodeDuplicate: 'Ce nœud existe déjà',
    K.settingsNodeChecking: 'Vérification',
    K.settingsResync: 'Récupérer l’historique',
    K.settingsResyncDesc:
        'Récupérer depuis le store du nœud les messages et paquets de clés manqués (48 dernières heures)',
    K.settingsResyncDone: 'Historique récupéré',
    K.settingsBackup: 'Sauvegarder l’identité',
    K.settingsDelete: 'Supprimer l’identité sur cet appareil',
    K.settingsDeleteConfirm: 'Ceci efface l’identité locale et toutes les conversations. Continuer ?',
    K.settingsAbout: 'À propos',
    K.settingsLicense: 'Licence open source',
    K.settingsThirdPartyLicenses: 'Licences tierces',
    K.settingsVersion: 'Version',
    K.updateCheck: 'Vérifier les mises à jour',
    K.updateChecking: 'Vérification des mises à jour…',
    K.updateLatest: 'À jour',
    K.updateAvailableTitle: 'Mise à jour disponible',
    K.updateVersionLine: 'v%1\$s (build %2\$s)',
    K.updatePublished: 'Publié le %1\$s',
    K.updateNow: 'Mettre à jour',
    K.updateLater: 'Plus tard',
    K.updateFailed: 'Impossible de vérifier les mises à jour. Réessayez plus tard.',
    K.updateRefresh: 'Actualiser la page',
    K.updateWebHint:
        'L’application web est hébergée sur GitHub Pages ; actualisez simplement la page pour obtenir la dernière version.',
    K.updateLaunchFailed:
        'Impossible d’ouvrir le lien de téléchargement. Réessayez plus tard ou scannez le QR code.',
    K.scanToDownload: 'Scanner pour télécharger',
    K.settingsAdvanced: 'Avancé',
    K.settingsGroupGeneral: 'Général',
    K.settingsGroupAccount: 'Compte',
    K.settingsGroupConnection: 'Connexion',
    K.settingsGroupDanger: 'Zone de danger',
    K.settingsSubAppearance: 'Style du thème et langue de l’interface',
    K.settingsSubSecurity: 'Verrouillage, verrouillage auto et mot de passe',
    K.settingsSubNetwork: 'Nœuds Waku et connectivité',
    K.settingsSubBlockchain: 'Chaîne et points de terminaison RPC',
    K.settingsSubIdentity: 'DID et sauvegarde',
    K.settingsSubImportKey: 'Restaurer l’identité depuis une clé privée',
    K.settingsSubAbout: 'Version et mises à jour',
    K.settingsSubDanger: 'Supprimer l’identité sur cet appareil',
    K.settingsClearCache: 'Vider le cache',
    K.settingsCacheCleared: 'Cache vidé',
    K.settingsPublishKeys: 'Republier le paquet de clés',
    K.settingsKeysPublished: 'Paquet de clés publié sur Waku',
    K.identityTitle: 'Mon identité',
    K.identityDid: 'Identifiant décentralisé',
    K.identityMethod: 'Méthode DID',
    K.identityEthAddress: 'Adresse Ethereum',
    K.identitySignKey: 'Clé publique de signature',
    K.identityEncKey: 'Clé publique de chiffrement',
    K.identityBackup: 'Sauvegarder la phrase de récupération',
    K.identityBackupDesc: 'La phrase de récupération est le seul moyen de retrouver votre identité.',
    K.identityShowMnemonic: 'Afficher la phrase de récupération',
    K.identityHideMnemonic: 'Masquer la phrase de récupération',
    K.identityConfirmBackup: 'J’ai enregistré ma phrase',
    K.identityRisk: 'Avertissement de risque',
    K.errorGeneric: 'Une erreur est survenue, veuillez réessayer.',
    K.errorNetwork: 'Échec de la connexion réseau',
    K.errorInvalidInput: 'Saisie invalide',
    K.errorCrypto: 'Échec du chiffrement ou du déchiffrement',
    K.errorNotFound: 'Introuvable',
    K.errorTimeout: 'Délai de connexion dépassé',
    K.timeJustNow: 'à l’instant',
    K.timeMinutesAgo: 'il y a %1\$d min',
    K.timeHoursAgo: 'il y a %1\$d h',
  },
};

/// 單一語系的文案存取物件。
class Strings {
  Strings._(this.locale, this._data);

  final AppLocale locale;

  final Map<String, String> _data;

  static final Map<String, String> _fallback = _bundles['en']!;

  factory Strings.of(AppLocale locale) =>
      Strings._(locale, _bundles[locale.code] ?? _fallback);

  /// 依鍵取值，缺少時退回英文，再缺少則回傳鍵名本身。
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
  String get navDiscover => get(K.navDiscover);
  String get navSettings => get(K.navSettings);
  String get navMe => get(K.navMe);

  String get discoverTitle => get(K.discoverTitle);
  String get discoverSubtitle => get(K.discoverSubtitle);
  String get discoverTools => get(K.discoverTools);
  String get discoverScan => get(K.discoverScan);
  String get discoverScanDesc => get(K.discoverScanDesc);
  String get scanTitle => get(K.scanTitle);
  String get scanHint => get(K.scanHint);
  String get scanTorch => get(K.scanTorch);
  String get scanSwitchCamera => get(K.scanSwitchCamera);
  String get scanUnsupportedTitle => get(K.scanUnsupportedTitle);
  String get scanUnsupportedDesc => get(K.scanUnsupportedDesc);
  String get scanPermissionTitle => get(K.scanPermissionTitle);
  String get scanPermissionDesc => get(K.scanPermissionDesc);
  String get scanCameraError => get(K.scanCameraError);
  String get scanResultTitle => get(K.scanResultTitle);
  String get scanResultDid => get(K.scanResultDid);
  String get scanResultAddress => get(K.scanResultAddress);
  String get scanResultEns => get(K.scanResultEns);
  String get scanResultText => get(K.scanResultText);
  String get scanAddContact => get(K.scanAddContact);
  String get scanOpenFailed => get(K.scanOpenFailed);
  String get scanPayAction => get(K.scanPayAction);
  String get scanResultPayment => get(K.scanResultPayment);
  String get scanPickHint => get(K.scanPickHint);
  String get scanPickInvalid => get(K.scanPickInvalid);

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
  String get passphraseAdvanced => get(K.passphraseAdvanced);
  String get passphraseLabel => get(K.passphraseLabel);
  String get passphraseHint => get(K.passphraseHint);
  String get passphraseConfirmLabel => get(K.passphraseConfirmLabel);
  String get passphraseDesc => get(K.passphraseDesc);
  String get passphraseMismatch => get(K.passphraseMismatch);
  String get identityPassphrase => get(K.identityPassphrase);
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
  String get chatRecall => get(K.chatRecall);
  String get chatRecallConfirm => get(K.chatRecallConfirm);
  String get chatRecalled => get(K.chatRecalled);
  String get chatDeleteMessageConfirm => get(K.chatDeleteMessageConfirm);
  String get chatMessageDeleted => get(K.chatMessageDeleted);
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
  String get chainBase => get(K.chainBase);
  String get chainArbitrum => get(K.chainArbitrum);
  String get chainBsc => get(K.chainBsc);
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
  String get walletSendNetwork => get(K.walletSendNetwork);
  String walletSendNetworkNotice(String chain) =>
      format(K.walletSendNetworkNotice, [chain]);
  String get walletSwitchNetwork => get(K.walletSwitchNetwork);
  String get walletErrChainMismatch => get(K.walletErrChainMismatch);
  String get walletScanAddress => get(K.walletScanAddress);
  String get walletRpcMismatch => get(K.walletRpcMismatch);
  String get walletRpcUrlHint => get(K.walletRpcUrlHint);
  String get walletNativeToken => get(K.walletNativeToken);

  // ---------------------------------------------------- 錢包 · 常用通證面板
  String get tokenAdd => get(K.tokenAdd);
  String get tokenAddTitle => get(K.tokenAddTitle);
  String get tokenAdded => get(K.tokenAdded);
  String get tokenTabErc20 => get(K.tokenTabErc20);
  String get tokenTabErc721 => get(K.tokenTabErc721);
  String get tokenTabErc1155 => get(K.tokenTabErc1155);
  String get tokenEmpty => get(K.tokenEmpty);
  String get tokenCustom => get(K.tokenCustom);
  String get tokenCopyContract => get(K.tokenCopyContract);
  String get tokenViewExplorer => get(K.tokenViewExplorer);
  String get tokenRemove => get(K.tokenRemove);
  String get tokenRemoveConfirm => get(K.tokenRemoveConfirm);
  String get tokenName => get(K.tokenName);
  String get tokenSymbol => get(K.tokenSymbol);
  String get tokenStandard => get(K.tokenStandard);
  String get tokenDecimals => get(K.tokenDecimals);
  String get tokenContract => get(K.tokenContract);
  String get tokenIcon => get(K.tokenIcon);
  String get tokenColor => get(K.tokenColor);
  String get tokenTypeErc20 => get(K.tokenTypeErc20);
  String get tokenTypeErc721 => get(K.tokenTypeErc721);
  String get tokenTypeErc1155 => get(K.tokenTypeErc1155);
  String get tokenTypeNative => get(K.tokenTypeNative);
  String get tokenErrNameSymbol => get(K.tokenErrNameSymbol);
  String get tokenInvalidAddress => get(K.tokenInvalidAddress);
  String get tokenInvalidDecimals => get(K.tokenInvalidDecimals);
  String get tokenErrTronToken => get(K.tokenErrTronToken);
  String get tokenHistoryTitle => get(K.tokenHistoryTitle);
  String get tokenHistoryEmpty => get(K.tokenHistoryEmpty);
  String get tokenNotTransferable => get(K.tokenNotTransferable);

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
  String get chatImagePickFailed => get(K.chatImagePickFailed);
  String get chatImageUnavailable => get(K.chatImageUnavailable);
  String get chatImageUnsupported => get(K.chatImageUnsupported);
  String get chatImageDownload => get(K.chatImageDownload);
  String get chatImageSaved => get(K.chatImageSaved);
  String get chatImageSavedToAlbum => get(K.chatImageSavedToAlbum);
  String get chatImageSaveFailed => get(K.chatImageSaveFailed);
  String get chatImageZoomIn => get(K.chatImageZoomIn);
  String get chatImageZoomOut => get(K.chatImageZoomOut);
  String get chatImageReset => get(K.chatImageReset);

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
  String get settingsLicense => get(K.settingsLicense);
  String get settingsThirdPartyLicenses => get(K.settingsThirdPartyLicenses);
  String get settingsVersion => get(K.settingsVersion);
  String get settingsAdvanced => get(K.settingsAdvanced);
  String get settingsGroupGeneral => get(K.settingsGroupGeneral);
  String get settingsGroupAccount => get(K.settingsGroupAccount);
  String get settingsGroupConnection => get(K.settingsGroupConnection);
  String get settingsGroupDanger => get(K.settingsGroupDanger);
  String get settingsSubAppearance => get(K.settingsSubAppearance);
  String get settingsSubSecurity => get(K.settingsSubSecurity);
  String get settingsSubNetwork => get(K.settingsSubNetwork);
  String get settingsSubBlockchain => get(K.settingsSubBlockchain);
  String get settingsSubIdentity => get(K.settingsSubIdentity);
  String get settingsSubImportKey => get(K.settingsSubImportKey);
  String get settingsSubAbout => get(K.settingsSubAbout);
  String get settingsSubDanger => get(K.settingsSubDanger);

  String get updateCheck => get(K.updateCheck);
  String get updateChecking => get(K.updateChecking);
  String get updateLatest => get(K.updateLatest);
  String get updateAvailableTitle => get(K.updateAvailableTitle);
  String updateVersionLine(String version, int build) =>
      format(K.updateVersionLine, [version, build]);
  String updatePublished(String date) => format(K.updatePublished, [date]);
  String get updateNow => get(K.updateNow);
  String get updateLater => get(K.updateLater);
  String get updateFailed => get(K.updateFailed);
  String get updateLaunchFailed => get(K.updateLaunchFailed);
  String get updateRefresh => get(K.updateRefresh);
  String get updateWebHint => get(K.updateWebHint);
  String get scanToDownload => get(K.scanToDownload);
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
