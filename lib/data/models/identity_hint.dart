import 'package:meta/meta.dart' show immutable;

/// 身份的「公开提示」：只含对外可见的资讯，不含助记词或私钥。
///
/// 这份资料**明文**存放于本地储存，用途有三：
/// 1. 判断本机是否已存在身份（决定「引导页」或「锁屏」）。
/// 2. 在未解锁状态下显示是哪个帐户（地址尾码），让使用者确认。
/// 3. 让路由在锁定时仍知道要导向锁屏而非引导页。
///
/// 这些栏位本来就是公开识别码，且 `encPublicKeyB64` 会主动发布到 Waku，
/// 因此明文存放不构成新的泄漏面。**真正的秘密（助记词、私钥、加密种子）
/// 一律只存在于加密保险库中。**
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

  /// 是否为助记词身份（决定备份页显示助记词还是私钥）。
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
