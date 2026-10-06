import 'package:web3dart/credentials.dart' show EthereumAddress;

/// DID 相关工具：目前主要支援 `did:ethr`，同时容许直接以地址或 ENS 输入。
abstract final class Did {
  /// did:ethr 的 method 名称。
  static const ethrMethod = 'ethr';

  /// 由以太坊地址产生 DID（地址一律小写，符合 did:ethr 惯例）。
  static String fromAddress(String address) {
    final normalized = address.toLowerCase().startsWith('0x')
        ? address.toLowerCase()
        : '0x${address.toLowerCase()}';
    return 'did:ethr:$normalized';
  }

  /// 由 DID 取出地址；若输入不是 DID 则原样回传（可能是地址）。
  static String toAddress(String didOrAddress) {
    final value = didOrAddress.trim();
    if (value.startsWith('did:ethr:')) {
      return value.substring('did:ethr:'.length);
    }
    if (value.startsWith('did:')) {
      final parts = value.split(':');
      if (parts.length >= 3) return parts.last;
    }
    return value;
  }

  /// 是否为合法的 did:ethr 格式。
  static bool isEthrDid(String value) {
    final v = value.trim();
    if (!v.startsWith('did:ethr:')) return false;
    return _addressPattern.hasMatch(v.substring('did:ethr:'.length));
  }

  /// 是否为 0x 开头的 20 位元组地址。
  ///
  /// 混合大小写时会一并验证 EIP-55 校验和：一旦出现大小写混用，就代表
  /// 这个地址自称带有校验和，必须正确才算合法 —— 抄错或被窜改的地址
  /// 送出去就找不回来。全小写或全大写视为「未带校验和」，依惯例接受。
  static bool isAddress(String value) {
    final v = value.trim();
    if (!_addressPattern.hasMatch(v)) return false;
    return hasValidChecksum(v);
  }

  /// EIP-55 校验和是否合法（全小写 / 全大写视为未带校验和）。
  static bool hasValidChecksum(String address) {
    final v = address.trim();
    if (!_addressPattern.hasMatch(v)) return false;
    final body = v.substring(2);
    if (body == body.toLowerCase() || body == body.toUpperCase()) return true;
    // 校验和形式的地址是唯一的：只要大小写混用就必须等于 EIP-55 的结果。
    return eip55(v) == v;
  }

  /// 是否为 ENS 名称（xxx.eth）。
  static bool isEnsName(String value) {
    final v = value.trim().toLowerCase();
    return v.endsWith('.eth') && v.length > 4 && !v.contains(' ');
  }

  static final RegExp _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');

  /// 把地址转成 EIP-55 检查码格式，用于显示。
  static String eip55(String address) {
    try {
      return EthereumAddress.fromHex(address).hexEip55;
    } catch (_) {
      return address;
    }
  }

  /// 显示用短地址：`0x1234…abcd`
  static String shortAddress(String address, {int head = 6, int tail = 4}) {
    final v = toAddress(address);
    if (v.length <= head + tail) return v;
    return '${v.substring(0, head)}…${v.substring(v.length - tail)}';
  }

  /// 显示用短 DID。
  static String shortDid(String did, {int tail = 6}) {
    final addr = toAddress(did);
    if (addr.length > tail + 2) {
      return 'did:ethr:${addr.substring(0, 6)}…${addr.substring(addr.length - tail)}';
    }
    return did;
  }
}
