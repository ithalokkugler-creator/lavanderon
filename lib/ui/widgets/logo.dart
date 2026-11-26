import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../tema/tema.dart';

/// Marca Lavanderon: o "O" é a porta redonda de uma lavadora,
/// que também lembra um olho (Vision). Seção 18.8 do plano.
class PortaLogo extends StatelessWidget {
  const PortaLogo({super.key, this.tamanho = 40, this.claro = false});
  final double tamanho;
  final bool claro;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: tamanho, child: CustomPaint(painter: _PortaPainter(claro: claro)));
}

class _PortaPainter extends CustomPainter {
  _PortaPainter({required this.claro});
  final bool claro;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final aro = claro ? Colors.white : Cores.marca;
    final vidro = claro ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFE3F2FD);

    canvas.drawCircle(c, r * 0.92, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.16
      ..color = aro);
    canvas.drawCircle(c, r * 0.70, Paint()..color = vidro);

    // Água (onda) dentro do vidro
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.70)));
    final onda = Path()..moveTo(c.dx - r, c.dy + r * 0.08);
    for (var i = 0; i <= 20; i++) {
      final x = c.dx - r + (2 * r) * i / 20;
      final y = c.dy + r * 0.08 + math.sin(i / 20 * 2 * math.pi * 1.5) * r * 0.10;
      onda.lineTo(x, y);
    }
    onda
      ..lineTo(c.dx + r, c.dy + r)
      ..lineTo(c.dx - r, c.dy + r)
      ..close();
    canvas.drawPath(onda, Paint()..color = claro ? Colors.white.withValues(alpha: 0.55) : Cores.agua);
    canvas.restore();

    // Pupila/brilho: o "olho" do Vision
    canvas.drawCircle(c.translate(-r * 0.22, -r * 0.24), r * 0.11,
        Paint()..color = claro ? Colors.white : Colors.white.withValues(alpha: 0.95));
  }

  @override
  bool shouldRepaint(covariant _PortaPainter old) => old.claro != claro;
}

class LogoLavanderon extends StatelessWidget {
  const LogoLavanderon({super.key, this.altura = 28, this.claro = false, this.comAssinatura = false});
  final double altura;
  final bool claro;
  final bool comAssinatura;

  @override
  Widget build(BuildContext context) {
    final cor = claro ? Colors.white : Cores.marca;
    final estilo = GoogleFonts.nunito(fontSize: altura, fontWeight: FontWeight.w900, color: cor, height: 1, letterSpacing: -0.5);
    final palavra = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Lavander', style: estilo),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: altura * 0.04),
          child: PortaLogo(tamanho: altura * 0.86, claro: claro),
        ),
        Text('n', style: estilo),
      ],
    );
    if (!comAssinatura) return palavra;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        palavra,
        const SizedBox(height: 4),
        Text('Lavanderia do Vision',
            style: GoogleFonts.nunito(
                fontSize: altura * 0.42, fontWeight: FontWeight.w700, color: claro ? Colors.white70 : Cores.textoSuave)),
      ],
    );
  }
}
