import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

import '../core/pbkdf2.dart';
import 'models.dart';

/// CSV 与口令加密备份的纯函数实现：不接触数据库与界面，可在单元测试中直接调用。
class ExportService {
  const ExportService._();

  static const String csvHeader = '日期,类型,金额,账户,转入账户,分类,备注';
  static const String legacyCipherName = 'AES-256-CBC';
  static const String cipherName = 'AES-256-CBC-HMAC-SHA256';
  static const String kdfName = 'PBKDF2-HMAC-SHA256';
  static const int defaultKdfIterations = 100000;
  static const int _minKdfIterations = 1000;
  static const int _maxKdfIterations = 2000000;

  /// 首字符为 UTF-8 BOM，保证 Excel 直接双击打开时按 UTF-8 解码。
  static String toCsv(
    List<LedgerTransaction> txs,
    List<Account> accounts,
    List<Category> categories,
  ) {
    final accountNames = <String, String>{
      for (final account in accounts) account.id: account.name,
    };
    final categoryNames = <String, String>{
      for (final category in categories) category.id: category.name,
    };

    final buffer = StringBuffer('\uFEFF$csvHeader\n');
    for (final transaction in txs) {
      final isTransfer = transaction.type == TransactionType.transfer;
      final categoryId = transaction.categoryId;
      final row = <String>[
        _formatDateTime(transaction.occurredAt),
        _typeLabel(transaction.type),
        (transaction.amount / 100).toStringAsFixed(2),
        accountNames[transaction.accountId] ?? '',
        accountNames[transaction.toAccountId] ?? '',
        isTransfer || categoryId == null ? '' : categoryNames[categoryId] ?? '',
        transaction.note ?? '',
      ];
      buffer.writeln(row.map(_escapeCsvField).join(','));
    }
    return buffer.toString();
  }

  /// v2 加密格式：PBKDF2-HMAC-SHA256 派生 64 字节（32B 加密 + 32B MAC），
  /// 采用 AES-256-CBC + Encrypt-then-MAC（HMAC-SHA256）。
  static String encryptJson(
    String plainJson,
    String password, {
    int iterations = defaultKdfIterations,
  }) {
    final salt = secureRandomBytes(16);
    final iv = IV.fromSecureRandom(16);
    final derived = pbkdf2HmacSha256(
      passwordBytes: utf8.encode(password),
      salt: salt,
      iterations: iterations,
      keyLength: 64,
    );
    final encKey = Key(Uint8List.sublistView(derived, 0, 32));
    final macKey = Uint8List.sublistView(derived, 32, 64);

    final encrypter = Encrypter(AES(encKey, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainJson, iv: iv);
    final mac = _computeMac(macKey, salt, iv.bytes, encrypted.bytes);

    return jsonEncode(<String, Object>{
      'schemaVersion': 2,
      'encrypted': true,
      'cipher': cipherName,
      'kdf': kdfName,
      'iterations': iterations,
      'salt': base64Encode(salt),
      'iv': iv.base64,
      'data': encrypted.base64,
      'mac': base64Encode(mac),
    });
  }

  /// 非加密格式、结构不符、完整性校验失败或口令错误一律返回 null，不向上抛异常。
  static String? tryDecryptJson(String fileContent, String password) {
    try {
      final decoded = jsonDecode(fileContent);
      if (decoded is! Map) return null;
      if (decoded['encrypted'] != true) return null;

      final cipher = decoded['cipher'];
      if (cipher == cipherName) {
        return _tryDecryptV2(decoded, password);
      }
      if (cipher == legacyCipherName) {
        return _tryDecryptLegacyV1(decoded, password);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String? _tryDecryptV2(Map<dynamic, dynamic> decoded, String password) {
    if (decoded['kdf'] != kdfName) return null;
    final iterations = decoded['iterations'];
    if (iterations is! int ||
        iterations < _minKdfIterations ||
        iterations > _maxKdfIterations) {
      return null;
    }

    final saltB64 = decoded['salt'];
    final ivB64 = decoded['iv'];
    final dataB64 = decoded['data'];
    final macB64 = decoded['mac'];
    if (saltB64 is! String ||
        ivB64 is! String ||
        dataB64 is! String ||
        macB64 is! String) {
      return null;
    }

    final salt = base64Decode(saltB64);
    final ivBytes = base64Decode(ivB64);
    final cipherBytes = base64Decode(dataB64);
    final macBytes = base64Decode(macB64);
    if (salt.length < 8 || ivBytes.length != 16 || cipherBytes.isEmpty) {
      return null;
    }

    final derived = pbkdf2HmacSha256(
      passwordBytes: utf8.encode(password),
      salt: salt,
      iterations: iterations,
      keyLength: 64,
    );
    final encKey = Key(Uint8List.sublistView(derived, 0, 32));
    final macKey = Uint8List.sublistView(derived, 32, 64);

    final expectedMac = _computeMac(macKey, salt, ivBytes, cipherBytes);
    if (!constantTimeBytesEqual(expectedMac, macBytes)) {
      return null;
    }

    final encrypter = Encrypter(AES(encKey, mode: AESMode.cbc));
    final plain = encrypter.decrypt(
      Encrypted(cipherBytes),
      iv: IV(ivBytes),
    );
    if (jsonDecode(plain) is! Map) return null;
    return plain;
  }

  static String? _tryDecryptLegacyV1(
    Map<dynamic, dynamic> decoded,
    String password,
  ) {
    final ivBase64 = decoded['iv'];
    final dataBase64 = decoded['data'];
    if (ivBase64 is! String || dataBase64 is! String) return null;

    final encrypter = Encrypter(
      AES(_legacyKeyFromPassword(password), mode: AESMode.cbc),
    );
    final plain = encrypter.decrypt64(dataBase64, iv: IV.fromBase64(ivBase64));
    // 口令错误时 PKCS7 反填充通常直接抛错；这里再校验一次明文结构，避免返回乱码。
    if (jsonDecode(plain) is! Map) return null;
    return plain;
  }

  static List<int> _computeMac(
    List<int> macKey,
    List<int> salt,
    List<int> iv,
    List<int> cipherBytes,
  ) {
    final payload = Uint8List(salt.length + iv.length + cipherBytes.length)
      ..setAll(0, salt)
      ..setAll(salt.length, iv)
      ..setAll(salt.length + iv.length, cipherBytes);
    return Hmac(sha256, macKey).convert(payload).bytes;
  }

  static Key _legacyKeyFromPassword(String password) =>
      Key(Uint8List.fromList(sha256.convert(utf8.encode(password)).bytes));

  static String _typeLabel(TransactionType type) => switch (type) {
        TransactionType.expense => '支出',
        TransactionType.income => '收入',
        TransactionType.transfer => '转账',
      };

  static String _formatDateTime(int milliseconds) {
    final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.year}-$month-$day $hour:$minute';
  }

  static String _escapeCsvField(String value) {
    final needsQuoting = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuoting) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}