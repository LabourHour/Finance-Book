import 'package:flutter/material.dart';

/// 圆角与胶囊形状 token。
class StreamShapes {
  const StreamShapes._();

  static const BorderRadius mainCard = BorderRadius.all(Radius.circular(24));
  static const BorderRadius listCard = BorderRadius.all(Radius.circular(20));
  static const BorderRadius smallCard = BorderRadius.all(Radius.circular(16));
  static const BorderRadius tag = BorderRadius.all(Radius.circular(8));
  static const ShapeBorder capsule = StadiumBorder();
}