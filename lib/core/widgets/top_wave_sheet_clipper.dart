import 'package:flutter/material.dart';

/// Recorta TODO el panel con una ola en el BORDE SUPERIOR.
/// - baseY: qué tan abajo empieza la ola (en px desde el tope; 32–56 recomendable)
/// - waveH: altura/“profundidad” de la ola (en px; 22–48 recomendable)
class TopWaveSheetClipper extends CustomClipper<Path> {
  final double baseY;
  final double waveH;
  const TopWaveSheetClipper({this.baseY = 44, this.waveH = 32});

  @override
  Path getClip(Size size) {
    final y0 = baseY;          // línea base donde empieza la curva
    final a  = waveH.clamp(8, 64); // amplitud (profundidad)

    final p = Path();

    // Borde superior ondulado de izquierda a derecha
    p.moveTo(0, y0);
    p.cubicTo(size.width * 0.22, y0 - a * .40,
        size.width * 0.38, y0 + a * .55,
        size.width * 0.50, y0 + a * .15);
    p.cubicTo(size.width * 0.70, y0 - a * .35,
        size.width * 0.85, y0 + a * .20,
        size.width,        y0);

    // Bordes laterales e inferior (rectos, pegados a los bordes)
    p.lineTo(size.width, size.height);
    p.lineTo(0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant TopWaveSheetClipper oldClipper) =>
      oldClipper.baseY != baseY || oldClipper.waveH != waveH;
}
