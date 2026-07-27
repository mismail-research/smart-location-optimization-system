import 'package:flutter/material.dart';

class LocaLogo extends StatelessWidget {
  final double animationValue; // 0.0 to 1.0 driving the whole sequence
  final bool animate; // if false, renders the final state immediately
  final double scale;

  const LocaLogo({
    super.key,
    this.animationValue = 1.0,
    this.animate = false,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // If animate is true, just fade the image in using the animationValue
    double opacity = animate ? animationValue.clamp(0.0, 1.0) : 1.0;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Image.asset(
          'assets/logo.png',
          height: 100,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
