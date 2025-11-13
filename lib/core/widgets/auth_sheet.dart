import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import 'top_wave_sheet_clipper.dart';

/// Sheet inferior pegado a laterales e inferior,
/// con borde superior ondulado que separa del fondo.
/// El contenido (título + formulario) hace scroll y sube con el teclado.
class AuthSheet extends StatelessWidget {
  final String title;
  final Widget child;

  /// Porción mínima de pantalla que ocupa el sheet (alto).
  final double minHeightFactor;

  /// Ajustes finos de la ola (en píxeles).
  final double waveBaseY; // distancia desde el tope del sheet hasta el eje de la ola
  final double waveHeight; // profundidad de la ola

  const AuthSheet({
    super.key,
    required this.title,
    required this.child,
    this.minHeightFactor = 0.60,
    this.waveBaseY = 44,
    this.waveHeight = 32,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final kb = MediaQuery.of(context).viewInsets.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: kb), // sube completo con teclado
        child: ClipPath(
          clipper: TopWaveSheetClipper(baseY: waveBaseY, waveH: waveHeight),
          child: Container(
            width: size.width,
            constraints: BoxConstraints(minHeight: size.height * minHeightFactor),
            color: ResQColors.primary50,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, waveBaseY + waveHeight + 8, 24, 24),
              // ↑ dejamos espacio justo debajo de la ola para que el título siempre se vea
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
