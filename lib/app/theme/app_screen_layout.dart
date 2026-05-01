import 'package:flutter/material.dart';

/// Отступы, радиусы и минимальные размеры касания - доли от **короткой стороны** экрана
/// (как на телефоне в портрете/ландшафте), без фиксированных dp в виджетах.
///
/// Калибровка: при `shortestSide ≈ 390` совпадает с прежними `AppSizes`.
@immutable
class AppScreenLayout {
  const AppScreenLayout._(this.shortestSide, this.screenWidth, this.screenHeight);

  factory AppScreenLayout.fromSize(Size size) {
    final s = size.shortestSide;
    return AppScreenLayout._(s, size.width, size.height);
  }

  /// Для стартовой темы до первого `MediaQuery` (типичный телефон).
  factory AppScreenLayout.reference([double shortestSide = 390]) {
    return AppScreenLayout._(shortestSide, shortestSide * 0.52, shortestSide);
  }

  final double shortestSide;
  final double screenWidth;
  final double screenHeight;

  double _r(double fractionOfShortest) => shortestSide * fractionOfShortest;

  double get spaceXs => _r(0.0153846);
  double get spaceS => _r(0.025641);
  double get spaceM => _r(0.051282);
  double get spaceL => _r(0.076923);
  double get spaceXl => _r(0.107692);
  double get minTouch => _r(0.143590);
  double get preferredTouch => _r(0.184615);
  double get primaryButtonHeight => _r(0.297436);
  double get cardRadius => _r(0.061538);
  double get buttonRadius => _r(0.051282);
  double get borderWidth => _r(0.005128).clamp(1.0, 3.0);

  /// Нижний отступ под FAB: доля высоты + safe area (как раньше ~128 + bottom).
  double bottomFabClearance(double viewPaddingBottom) =>
      screenHeight * 0.164 + viewPaddingBottom;

  /// Ширина полноширинной кнопки с боковыми полями `spaceM`.
  double wideButtonWidth() => screenWidth - spaceM * 2;
}

extension AppScreenLayoutContext on BuildContext {
  AppScreenLayout get layout => AppScreenLayout.fromSize(MediaQuery.sizeOf(this));
}
