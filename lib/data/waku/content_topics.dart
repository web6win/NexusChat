/// Waku v2 的 content topic 定义。
///
/// 格式遵循社群惯例：`/{application}/{version}/{name}/{encoding}`
abstract final class ContentTopics {
  /// 协议版本号，会嵌入 topic 名称。
  static const version = '1';

  /// 应用程式前缀。
  static const app = 'nexuschat';

  /// 金钥包：公布自己的 X25519 公钥，让别人能加密讯息给自己。
  static const keyBundle = '/nexuschat/1/keys/json';

  /// 一对一讯息：由双方 DID 排序后派生，两端都能算出同一个 topic。
  static String directMessage(String a, String b) {
    final pair = <String>[a.toLowerCase(), b.toLowerCase()]..sort();
    return '/nexuschat/1/dm-${_shortHash('${pair[0]}|${pair[1]}')}/json';
  }

  /// 收件匣：只由「收件人自己的 DID」派生。
  ///
  /// 任何人都可以在上面丢讯息给某个 DID。**每一则私讯都会同时发到
  /// [directMessage] 与这里**，因为 pairwise topic 只有在「收件人已把发送者
  /// 加进联络人」时才会被轮询；对方还不认识你时，收件匣是唯一的投递路径。
  static String inbox(String did) =>
      '/nexuschat/1/inbox-${_shortHash(did.toLowerCase())}/json';

  /// 在线状态 / 正在输入（ephemeral，不进 store）。
  static const presence = '/nexuschat/1/presence/json';

  /// 群组聊天（预留）。
  static String group(String groupId) => '/nexuschat/1/g-${_shortHash(groupId)}/json';

  /// FNV-1a 64 位元杂凑的十六进位。
  ///
  /// 使用 [BigInt] 运算，避免 dart2js 上 64 位元整数被截断。
  static String _shortHash(String input) {
    const offsetBasis = '14695981039346656037'; // 0xcbf29ce484222325
    const prime = '1099511628211'; // 0x100000001b3
    final mask = BigInt.parse('ffffffffffffffff', radix: 16);

    var hash = BigInt.parse(offsetBasis);
    final primeValue = BigInt.parse(prime);
    for (final unit in input.codeUnits) {
      hash = (hash ^ BigInt.from(unit)) * primeValue;
      hash = hash & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
