/// 金额一律以「分」为单位的 int 表示；本文件为纯 Dart，无 Flutter 依赖，可在单元测试中直接使用。
class FormattedAmountParts {
  final bool isNegative;

  /// "-" / "+" / ""
  final String prefix;

  /// 千分位整数部分，如 "1,580"
  final String integerString;

  /// 小数部分，含小数点，如 ".50"
  final String decimalString;

  const FormattedAmountParts({
    required this.isNegative,
    required this.prefix,
    required this.integerString,
    required this.decimalString,
  });
}

class MoneyFormat {
  const MoneyFormat._();

  static const String symbol = '¥';

  static FormattedAmountParts formatParts(int cents, {bool showSign = false}) {
    final isNegative = cents < 0;
    final absValue = cents.abs();
    final integerPart = absValue ~/ 100;
    final decimalPart = (absValue % 100).toString().padLeft(2, '0');

    final prefix = isNegative
        ? '-'
        : (showSign && cents > 0 ? '+' : '');

    return FormattedAmountParts(
      isNegative: isNegative,
      prefix: prefix,
      integerString: _groupThousands(integerPart.toString()),
      decimalString: '.$decimalPart',
    );
  }

  /// 如 "-¥1,580.50"
  static String formatPlain(int cents, {bool withSymbol = true}) {
    final parts = formatParts(cents);
    final sym = withSymbol ? symbol : '';
    return '${parts.prefix}$sym${parts.integerString}${parts.decimalString}';
  }

  /// 句子内使用，无货币符号：如 "-1,580.50"
  static String formatYuanPlain(int cents) =>
      formatPlain(cents, withSymbol: false);

  static String _groupThousands(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

/// 安全金额表达式解析器（禁止 eval / 反射）；全程按「分」整数运算，避免浮点漂移。
class ArithmeticParser {
  const ArithmeticParser._();

  /// 单笔上限：999.9999 万元
  static const int maxAmountCents = 999999999;

  static int parseNumberToCents(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 0;

    final isNegative = trimmed.startsWith('-');
    final clean = isNegative ? trimmed.substring(1) : trimmed;

    final parts = clean.split('.');
    final intPart = int.tryParse(parts[0]) ?? 0;

    var centsPart = 0;
    if (parts.length > 1) {
      final decStr = parts[1];
      if (decStr.isEmpty) {
        centsPart = 0;
      } else if (decStr.length == 1) {
        centsPart = _digit(decStr[0]) * 10;
      } else if (decStr.length == 2) {
        centsPart = int.tryParse(decStr) ?? 0;
      } else {
        // 超过两位小数进行四舍五入
        final firstTwo = int.tryParse(decStr.substring(0, 2)) ?? 0;
        centsPart = _digit(decStr[2]) >= 5 ? firstTwo + 1 : firstTwo;
      }
    }

    final total = intPart * 100 + centsPart;
    return isNegative ? -total : total;
  }

  /// 支持加减、负号、未完成末尾操作符、多小数点等边界。
  /// 例："30+8" -> 3800，"0.1+0.2" -> 30，"100-25.5" -> 7450
  static int evaluate(String expression) {
    final cleaned = expression.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return 0;

    final tokens = <String>[];
    var currentNumber = '';

    for (var i = 0; i < cleaned.length; i++) {
      final c = cleaned[i];
      if (c == '+' || c == '-') {
        final startsWithOperator = currentNumber.isEmpty &&
            (tokens.isEmpty || tokens.last == '+' || tokens.last == '-');
        if (startsWithOperator) {
          currentNumber += c;
        } else {
          if (currentNumber.isNotEmpty) {
            tokens.add(currentNumber);
            currentNumber = '';
          }
          tokens.add(c);
        }
      } else if (_isDigit(c)) {
        currentNumber += c;
      } else if (c == '.') {
        // 多小数点边界：只保留当前数字块中的第一个小数点
        if (!currentNumber.contains('.')) {
          currentNumber += c;
        }
      }
    }

    if (currentNumber.isNotEmpty) {
      tokens.add(currentNumber);
    }
    if (tokens.isEmpty) return 0;

    // 处理末尾多余操作符（如用户输入 "12+" 后直接点击完成）
    if (tokens.last == '+' || tokens.last == '-') {
      tokens.removeLast();
    }
    if (tokens.isEmpty) return 0;

    var totalCents = 0;
    var currentOp = '+';
    for (final token in tokens) {
      if (token == '+' || token == '-') {
        currentOp = token;
      } else {
        final numCents = parseNumberToCents(token);
        totalCents = currentOp == '+' ? totalCents + numCents : totalCents - numCents;
      }
    }

    if (totalCents < 0) return 0;
    if (totalCents > maxAmountCents) return maxAmountCents;
    return totalCents;
  }

  /// 将分转换为输入框回填字符串；0 返回空串。
  static String centsToDisplayInput(int cents) {
    if (cents == 0) return '';
    final yuan = cents ~/ 100;
    final fen = cents % 100;
    if (fen == 0) {
      return yuan.toString();
    }
    if (fen % 10 == 0) {
      return '$yuan.${fen ~/ 10}';
    }
    return '$yuan.${fen.toString().padLeft(2, '0')}';
  }

  static int _digit(String c) => int.tryParse(c) ?? 0;

  static bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}