import 'package:flutter_test/flutter_test.dart';
import 'package:stream_ledger/core/money.dart';

void main() {
  group('MoneyFormat 格式化', () {
    test('正数拆分为千分位整数与两位小数', () {
      final parts = MoneyFormat.formatParts(158050);
      expect(parts.isNegative, isFalse);
      expect(parts.prefix, '');
      expect(parts.integerString, '1,580');
      expect(parts.decimalString, '.50');
    });

    test('负数带负号且绝对值参与格式化', () {
      final parts = MoneyFormat.formatParts(-158050);
      expect(parts.isNegative, isTrue);
      expect(parts.prefix, '-');
      expect(parts.integerString, '1,580');
      expect(parts.decimalString, '.50');
    });

    test('showSign 只在正数时补加号', () {
      expect(MoneyFormat.formatParts(158050, showSign: true).prefix, '+');
      expect(MoneyFormat.formatParts(-158050, showSign: true).prefix, '-');
      expect(MoneyFormat.formatParts(0, showSign: true).prefix, '');
    });

    test('零值格式化为 0.00', () {
      final parts = MoneyFormat.formatParts(0);
      expect(parts.integerString, '0');
      expect(parts.decimalString, '.00');
    });

    test('百万级金额使用完整千分位', () {
      expect(MoneyFormat.formatPlain(123456789), '¥1,234,567.89');
    });

    test('formatPlain 拼接符号与符号位', () {
      expect(MoneyFormat.symbol, '¥');
      expect(MoneyFormat.formatPlain(158050), '¥1,580.50');
      expect(MoneyFormat.formatPlain(-158050), '-¥1,580.50');
      expect(MoneyFormat.formatPlain(158050, withSymbol: false), '1,580.50');
    });

    test('formatYuanPlain 用于句内金额，无货币符号', () {
      expect(MoneyFormat.formatYuanPlain(-158050), '-1,580.50');
      expect(MoneyFormat.formatYuanPlain(8800), '88.00');
      expect(MoneyFormat.formatYuanPlain(0), '0.00');
    });
  });

  group('ArithmeticParser', () {
    test('经典浮点陷阱 0.1 + 0.2 严格等于 30 分', () {
      expect(ArithmeticParser.evaluate('0.1+0.2'), 30);
    });

    test('基础加减', () {
      expect(ArithmeticParser.evaluate('30+8'), 3800);
      expect(ArithmeticParser.evaluate('100-25.5'), 7450);
      expect(ArithmeticParser.evaluate('10 + 5'), 1500);
    });

    test('末尾运算符按有效前缀计算', () {
      expect(ArithmeticParser.evaluate('12+'), 1200);
      expect(ArithmeticParser.evaluate('25.5-'), 2550);
    });

    test('多个小数点只保留第一个', () {
      expect(ArithmeticParser.evaluate('12.3.4'), 1234);
    });

    test('超过两位小数四舍五入', () {
      expect(ArithmeticParser.evaluate('0.125'), 13);
      expect(ArithmeticParser.evaluate('0.124'), 12);
    });

    test('负数参与混合运算，纯负数兜底为 0', () {
      expect(ArithmeticParser.evaluate('-10+20'), 1000);
      expect(ArithmeticParser.evaluate('-50'), 0);
    });

    test('超大金额被上限截断', () {
      expect(
        ArithmeticParser.evaluate('999999999999999'),
        ArithmeticParser.maxAmountCents,
      );
    });

    test('空串与纯运算符返回 0 且不抛异常', () {
      expect(ArithmeticParser.evaluate(''), 0);
      expect(ArithmeticParser.evaluate('+'), 0);
      expect(ArithmeticParser.evaluate('  '), 0);
    });

    test('parseNumberToCents 精确换算', () {
      expect(ArithmeticParser.parseNumberToCents(''), 0);
      expect(ArithmeticParser.parseNumberToCents('12.5'), 1250);
      expect(ArithmeticParser.parseNumberToCents('0.125'), 13);
      expect(ArithmeticParser.parseNumberToCents('-2'), -200);
    });

    test('centsToDisplayInput 回填输入框', () {
      expect(ArithmeticParser.centsToDisplayInput(0), '');
      expect(ArithmeticParser.centsToDisplayInput(1200), '12');
      expect(ArithmeticParser.centsToDisplayInput(1250), '12.5');
      expect(ArithmeticParser.centsToDisplayInput(1234), '12.34');
    });
  });
}