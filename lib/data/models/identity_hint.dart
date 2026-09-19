import 'package:meta/meta.dart' show immutable;

/// 身份的「公開提示」：只含對外可見的資訊，不含助記詞或私鑰。
///
/// 這份資料**明文**存放於本地儲存，用途有三：
/// 1. 判斷本機是否已存在身份（決定「引導頁」或「鎖屏」）。
/// 2. 在未解鎖狀態下顯示是哪個帳戶（地址尾碼），讓使用者確認。
/// 3. 讓路由在鎖定時仍知道要導向鎖屏而非引導頁。
///
/// 這些欄位本來就是公開識別碼，且 `encPublicKeyB64` 會主動發布到 Waku，
/// 因此明文存放不構成新的洩漏面。**真正的秘密（助記詞、私鑰、加密種子）
/// 一律只存在於加密保險庫中。**
@immutable
class IdentityHint {
  const IdentityHint({
    required this.did,
    required this.address,
    required this.tronAddress,
    required this.encPublicKeyB64,
    required this.hasMnemonic,
    required this.createdAt,
  });

  final String did;
  final String address;
  final String tronAddress;
  final String encPublicKeyB64;

  /// 是否為助記詞身份（決定備份頁顯示助記詞還是私鑰）。
  final bool hasMnemonic;

  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'did': did,
        'address': address,
        'tronAddress': tronAddress,
        'encPublicKeyB64': encPublicKeyB64,
        'hasMnemonic': hasMnemonic,
        'createdAt': createdAt.toIso8601String(),
      };

  static IdentityHint? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final did = raw['did'];
    final address = raw['address'];
    if (did is! String || address is! String) return null;
    final created = raw['createdAt'];
    return IdentityHint(
      did: did,
      address: address,
      tronAddress: (raw['tronAddress'] as String?) ?? '',
      encPublicKeyB64: (raw['encPublicKeyB64'] as String?) ?? '',
      hasMnemonic: (raw['hasMnemonic'] as bool?) ?? false,
      createdAt: created is String
          ? DateTime.tryParse(created) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }
}
