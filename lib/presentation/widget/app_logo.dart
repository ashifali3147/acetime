import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  const AppLogo({
    super.key,
    this.text = "AceTime",
    this.color = Colors.deepPurpleAccent,
    this.fontSize = 50,
    this.fontWeight = FontWeight.bold,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }
}
