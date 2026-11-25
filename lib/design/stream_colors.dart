import 'package:flutter/material.dart';

/// Apple 备忘录质感色彩设计系统（C 编辑风），取值照搬原 StreamColors.kt。
class StreamColors {
  const StreamColors._();

  // 浅色模式 - 温暖纸张调色板
  static const Color lightPaperBase = Color(0xFFF3EFE6);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF221F1A);
  static const Color lightTextSecondary = Color(0xFF7C7264);
  static const Color lightHairline = Color(0xFFE5DED1);
  static const Color lightInputBackground = Color(0xFFEDE7DA);

  // 深色主卡（编辑风 hero / 账户主卡）
  static const Color deepSurface = Color(0xFF231F1A);
  static const Color deepSurfaceDark = Color(0xFF332E26);
  static const Color onDeep = Color(0xFFF2EBDD);
  static const Color onDeepMuted = Color(0x80F2EBDD);

  // 深色模式 - 纸张碳素深灰调色板
  static const Color darkPaperBase = Color(0xFF181715);
  static const Color darkCardBackground = Color(0xFF24221F);
  static const Color darkTextPrimary = Color(0xFFEDEAE3);
  static const Color darkTextSecondary = Color(0xFFA69E92);
  static const Color darkHairline = Color(0xFF33302B);
  static const Color darkInputBackground = Color(0xFF2C2A26);

  // 核心品牌主色
  static const Color accentWarmYellow = Color(0xFFE5A93C);
  static const Color textOnAccent = Color(0xFF1C1B18);
  static const Color accentPillBackground = Color(0xFFFBF1DE);

  // 语义色彩
  static const Color incomeGreen = Color(0xFF2F7D52);
  static const Color darkIncomeGreen = Color(0xFF3D9A66);
  static const Color overBudgetRed = Color(0xFFC0463F);
  static const Color fixedExpenseGray = Color(0xFF9E9B93);

  // 8 组基于 OKLCH 均匀明度/彩度生成的分类色彩
  static const List<Color> categoryColors = <Color>[
    Color(0xFFD97757), // 陶土暖橙（餐饮美食）
    Color(0xFF5B88A5), // 雾霾蓝（交通出行）
    Color(0xFF5B9B88), // 鼠尾青（日常购物）
    Color(0xFF7E72A6), // 浅紫灰（休闲娱乐）
    Color(0xFFC98B3E), // 暖琥珀（生活日用）
    Color(0xFFBF6B7B), // 枯玫瑰红（医疗健康）
    Color(0xFF6A9A7B), // 橄榄绿（教育成长）
    Color(0xFF8C867A), // 亚麻灰（其他杂项）
  ];

  // 固定支出专用块色
  static const Color fixedExpenseBlockColor = fixedExpenseGray;
}