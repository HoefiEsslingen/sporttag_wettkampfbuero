import 'package:flutter/material.dart';

const Widget abstandHalter = SizedBox(height: 8.0);
const labelTextStyle = TextStyle(
  fontSize: 20.0,
//               color: Color.fromARGB(255, 232, 232, 38),
  color: Colors.white,
);

class KartenIcon extends StatelessWidget {
  const KartenIcon(
      {super.key,
      required this.icon,
      required this.color,
      required this.derText});

  final IconData icon;
  final Color color;
  final String derText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 60.0,
          color: color,
        ),
        abstandHalter,
        Text(
          derText,
          style: labelTextStyle,
        ),
      ],
    );
  }
}
