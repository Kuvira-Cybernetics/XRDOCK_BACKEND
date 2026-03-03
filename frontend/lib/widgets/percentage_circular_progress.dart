import 'package:flutter/material.dart';

class PercentageCircularProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final Color? color;

  const PercentageCircularProgress({
    super.key,
    required this.progress,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = color ?? Theme.of(context).primaryColor;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: themeColor.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(themeColor),
          ),
          FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
