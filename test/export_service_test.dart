import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_ledger/core/pbkdf2.dart';
import 'package:stream_ledger/data/export_service.dart';
import 'package:stream_ledger/data/models.dart';

Account _account() => const Account(
      id: 'a1',
      name: '微信,零钱',
      type: AccountType.wechat,
      symbolText: '微',
      colorHex: '#07C160',
    );

Category _category() => const Category(
      id: 'c1',
      name: '餐饮',
      type: TransactionType.expense,
      symbolText: '餐',
      colorHex: '#D97757',
    );

LedgerTransaction _tx() => LedgerTransaction(
      id: 't1',
      type: TransactionType.expense,
      amount: 1234,
      accountId: 'a1',
      categoryId: 'c1',
      occurredAt: DateTime(2026, 11, 20, 12, 30).millisecondsSinceEpoch,
      note: '含"引号"与,逗号',
      createdAt: 1,
      updatedAt: 2,
    );

void main() {
  group('PBKDF2-HMAC-SHA256', () {
    test('与标准测试向量一致', () {
      final one = pbkdf2HmacSha256(
        passwordBytes: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: 1,
        keyLength: 32,
      );
      expect(
        bytesToHex(one),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );

      final fourK = pbkdf2HmacSha256(
        passwordBytes: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: 4096,
        keyLength: 32,
      );
      expect(
        bytesToHex(fourK),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });
  });

  group('CSV 导出', () {
    test('表头、BOM 与金额格式', () {
      final csv = ExportService.toCsv([_tx()], [_account()], [_category()]);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv, contains('日期,类型,金额,账户,转入账户,分类,备注'));
      expect(csv, contains('12.34'));
      expect(csv, contains('支出'));
    });

    test('含逗号与引号的字段被正确转义', () {
      final csv = ExportService.toCsv([_tx()], [_account()], [_category()]);
      expect(csv, contains('"微信,零钱"'));
      expect(csv, contains('"含""引号""与,逗号"'));
    });

    test('未知账户与分类留空', () {
      final orphan = _tx().copyWith(accountId: 'missing', categoryId: 'missing');
      final csv = ExportService.toCsv([orphan], [_account()], [_category()]);
      expect(csv, isNot(contains('missing')));
    });
  });

  group('加密备份', () {
    const plain = '{"schemaVersion":2,"accounts":[],"transactions":[]}';

    test('v2 格式（PBKDF2 + Encrypt-then-MAC）同口令可往返解密', () {
      final encrypted = ExportService.encryptJson(
        plain,
        'p@ss-123',
        iterations: 2000,
      );
      final envelope = jsonDecode(encrypted) as Map<String, Object?>;
      expect(envelope['schemaVersion'], 2);
      expect(envelope['cipher'], ExportService.cipherName);
      expect(envelope['kdf'], ExportService.kdfName);
      expect(envelope['mac'], isA<String>());
      expect(encrypted, isNot(contains('accounts')));
      expect(ExportService.tryDecryptJson(encrypted, 'p@ss-123'), plain);
    });

    test('错误口令与明文输入返回 null', () {
      final encrypted = ExportService.encryptJson(
        plain,
        'p@ss-123',
        iterations: 2000,
      );
      expect(ExportService.tryDecryptJson(encrypted, 'wrong-pass'), isNull);
      expect(ExportService.tryDecryptJson(plain, 'p@ss-123'), isNull);
    });

    test('篡改密文或 MAC 时认证失败并返回 null', () {
      final encrypted = ExportService.encryptJson(
        plain,
        'p@ss-123',
        iterations: 2000,
      );
      final map = jsonDecode(encrypted) as Map<String, Object?>;

      final macBytes = base64Decode(map['mac']! as String);
      macBytes[0] ^= 0xFF;
      final badMac = jsonEncode({...map, 'mac': base64Encode(macBytes)});
      expect(ExportService.tryDecryptJson(badMac, 'p@ss-123'), isNull);

      final dataBytes = base64Decode(map['data']! as String);
      dataBytes[0] ^= 0xFF;
      final badData = jsonEncode({...map, 'data': base64Encode(dataBytes)});
      expect(ExportService.tryDecryptJson(badData, 'p@ss-123'), isNull);
    });

    test('随机 salt 与 IV：同内容两次加密结果不同', () {
      final a = ExportService.encryptJson(plain, 'p@ss-123', iterations: 2000);
      final b = ExportService.encryptJson(plain, 'p@ss-123', iterations: 2000);
      expect(a, isNot(b));
    });

    test('兼容旧版 v1 加密备份格式', () {
      const password = 'legacy-password';
      final iv = IV.fromSecureRandom(16);
      final legacyKey = Key(
        Uint8List.fromList(sha256.convert(utf8.encode(password)).bytes),
      );
      final cipher = Encrypter(AES(legacyKey, mode: AESMode.cbc))
          .encrypt(plain, iv: iv);
      final legacyPayload = jsonEncode({
        'schemaVersion': 1,
        'encrypted': true,
        'cipher': ExportService.legacyCipherName,
        'iv': iv.base64,
        'data': cipher.base64,
      });

      expect(ExportService.tryDecryptJson(legacyPayload, password), plain);
      expect(ExportService.tryDecryptJson(legacyPayload, 'wrong'), isNull);
    });
  });
}
