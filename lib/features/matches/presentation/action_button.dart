import 'package:flutter/material.dart';

/// 「いいね」タブの各アクション(スキップ/マッチ等)で使う丸ボタン。
/// アイコン指定時は正円、ラベル指定時はテキストの長さに応じて横に伸びる
/// 楕円(スタジアム型)になる——正円のまま長いラベルを入れると窮屈になるため、
/// 表示内容によって形状を切り替えている。
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    this.icon,
    this.label,
    required this.color,
    required this.onTap,
    this.size = 40,
    this.horizontalPadding,
  }) : assert(icon != null || label != null);

  final IconData? icon;
  final String? label;
  final Color color;
  final VoidCallback? onTap;

  /// アイコン/文字サイズや余白のスケール基準となる大きさ。
  /// アイコン表示時はこの値がそのままボタンの直径になる。
  final double size;

  /// ラベル表示時の左右余白。省略時は[size]から自動計算する。
  /// 楕円の横幅をもっと広げたい画面でだけ明示的に指定する想定。
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final shape = label != null ? const StadiumBorder() : const CircleBorder();
    final child = label != null
        ? Text(label!, style: TextStyle(color: color, fontSize: size * 0.325, fontWeight: FontWeight.bold))
        : Icon(icon, color: color, size: size * 0.45);
    final padding = label != null
        ? EdgeInsets.symmetric(horizontal: horizontalPadding ?? size * 0.35, vertical: size * 0.2)
        : EdgeInsets.all(size * 0.15);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: shape,
      elevation: 1,
      child: InkWell(customBorder: shape, onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}
