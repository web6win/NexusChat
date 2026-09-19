/// Waku v2 的 content topic 定義。
///
/// 格式遵循社群慣例：`/{application}/{version}/{name}/{encoding}`
abstract final class ContentTopics {
  /// 協議版本號，會嵌入 topic 名稱。
  static const version = '1';

  /// 應用程式前綴。
  static const app = 'nexuschat';

  /// 金鑰包：公布自己的 X25519 公鑰，讓別人能加密訊息給自己。
  static const keyBundle = '/nexuschat/1/keys/json';

  /// 一對一訊息：由雙方 DID 排序後派生，兩端都能算出同一個 topic。
  static String directMessage(String a, String b) {
    final pair = <String>[a.toLowerCase(), b.toLowerCase()]..sort();
    return '/nexuschat/1/dm-${_shortHash('${pair[0]}|${pair[1]}')}/json';
  }

  /// 收件匣：只由「收件人自己的 DID」派生。
  ///
  /// 任何人都可以在上面丟訊息給某個 DID。**每一則私訊都會同時發到
  /// [directMessage] 與這裡**，因為 pairwise topic 只有在「收件人已把發送者
  /// 加進聯絡人」時才會被輪詢；對方還不認識你時，收件匣是唯一的投遞路徑。
  static String inbox(String did) =>
      '/nexuschat/1/inbox-${_shortHash(did.toLowerCase())}/json';

  /// 在線狀態 / 正在輸入（ephemeral，不進 store）。
  static const presence = '/nexuschat/1/presence/json';

  /// 群組聊天（預留）。
  static String group(String groupId) => '/nexuschat/1/g-${_shortHash(groupId)}/json';

  /// FNV-1a 64 位元雜湊的十六進位。
  ///
  /// 使用 [BigInt] 運算，避免 dart2js 上 64 位元整數被截斷。
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
