import 'package:flutter/material.dart';

/// C 编辑风排版：衬线斜体大标题 + 宽字距小标签。
class StreamEditorialType {
  const StreamEditorialType._();

  static const TextStyle eyebrow = TextStyle(
    fontFamily: 'serif',
    fontWeight: FontWeight.w500,
    fontSize: 11.5,
    letterSpacing: 2.4,
  );

  static const TextStyle title = TextStyle(
    fontFamily: 'serif',
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    fontSize: 40,
    height: 44 / 40,
    letterSpacing: -1.2,
  );

  static const TextStyle subtitle = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 13.5,
    letterSpacing: 2.2,
  );

  static const TextStyle dayNumber = TextStyle(
    fontFamily: 'serif',
    fontWeight: FontWeight.w300,
    fontSize: 30,
    height: 32 / 30,
    letterSpacing: -0.8,
  );

  static const TextStyle dayLabel = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 11,
    letterSpacing: 1.2,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontFamily: 'serif',
    fontWeight: FontWeight.w500,
    fontSize: 11,
    letterSpacing: 1.8,
  );
}