import 'package:web3dart/credentials.dart' show EthereumAddress;

/// DID 相關工具：目前主要支援 `did:ethr`，同時容許直接以地址或 ENS 輸入。
abstract final class Did {
  /// did:ethr 的 method 名稱。
  static const ethrMethod = 'ethr';

  /// 由以太坊地址產生 DID（地址一律小寫，符合 did:ethr 慣例）。
  static String fromAddress(String address) {
    final normalized = address.toLowerCase().startsWith('0x')
        ? address.toLowerCase()
        : '0x${address.toLowerCase()}';
    return 'did:ethr:$normalized';
  }

  /// 由 DID 取出地址；若輸入不是 DID 則原樣回傳（可能是地址）。
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

  /// 是否為合法的 did:ethr 格式。
  static bool isEthrDid(String value) {
    final v = value.trim();
    if (!v.startsWith('did:ethr:')) return false;
    return _addressPattern.hasMatch(v.substring('did:ethr:'.length));
  }

  /// 是否為 0x 開頭的 20 位元組地址。
  static bool isAddress(String value) {
    return _addressPattern.hasMatch(value.trim());
  }

  /// 是否為 ENS 名稱（xxx.eth）。
  static bool isEnsName(String value) {
    final v = value.trim().toLowerCase();
    return v.endsWith('.eth') && v.length > 4 && !v.contains(' ');
  }

  static final RegExp _addressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');

  /// 把地址轉成 EIP-55 檢查碼格式，用於顯示。
  static String eip55(String address) {
    try {
      return EthereumAddress.fromHex(address).hexEip55;
    } catch (_) {
      return address;
    }
  }

  /// 顯示用短地址：`0x1234…abcd`
  static String shortAddress(String address, {int head = 6, int tail = 4}) {
    final v = toAddress(address);
    if (v.length <= head + tail) return v;
    return '${v.substring(0, head)}…${v.substring(v.length - tail)}';
  }

  /// 顯示用短 DID。
  static String shortDid(String did, {int tail = 6}) {
    final addr = toAddress(did);
    if (addr.length > tail + 2) {
      return 'did:ethr:${addr.substring(0, 6)}…${addr.substring(addr.length - tail)}';
    }
    return did;
  }
}
