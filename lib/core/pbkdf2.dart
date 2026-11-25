import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// RFC 2898 PBKDF2-HMAC-SHA256 密钥派生；纯 Dart 实现，不依赖平台通道。
Uint8List pbkdf2HmacSha256({
  required List<int> passwordBytes,
  required List<int> salt,
  required int iterations,
  required int keyLength,
}) {
  if (iterations <= 0) {
    throw ArgumentError.value(iterations, 'iterations', '必须大于 0');
  }
  if (keyLength <= 0) {
    throw ArgumentError.value(keyLength, 'keyLength', '必须大于 0');
  }

  const hashLength = 32; // SHA-256 输出 32 字节
  final blockCount = (keyLength + hashLength - 1) ~/ hashLength;
  final hmac = Hmac(sha256, passwordBytes);
  final output = Uint8List(blockCount * hashLength);
  final blockInput = Uint8List(salt.length + 4)..setAll(0, salt);

  for (var block = 1; block <= blockCount; block++) {
    final offset = salt.length;
    blockInput[offset] = (block >> 24) & 0xFF;
    blockInput[offset + 1] = (block >> 16) & 0xFF;
    blockInput[offset + 2] = (block >> 8) & 0xFF;
    blockInput[offset + 3] = block & 0xFF;

    var u = hmac.convert(blockInput).bytes;
    final t = Uint8List.fromList(u);

    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < hashLength; j++) {
        t[j] ^= u[j];
      }
    }

    output.setAll((block - 1) * hashLength, t);
  }

  return Uint8List.sublistView(output, 0, keyLength);
}

/// 常量时间字节比较，避免 MAC 或哈希比对泄露长度/前缀时序差异。
bool constantTimeBytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// 生成密码学安全的随机字节。
Uint8List secureRandomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

String bytesToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
