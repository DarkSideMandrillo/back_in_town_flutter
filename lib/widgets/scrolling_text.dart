import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

/*
 * utility visuale.
 * gestisce il testo che scorre (marquee) se supera la larghezza del contenitore.
 * se il testo è breve, sta fermo. centralizza la logica per non duplicarla nelle view.
 */
class ScrollingText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final bool centerIfStationary; // true per full player, false per mini

  const ScrollingText({
    super.key,
    required this.text,
    required this.style,
    this.centerIfStationary = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // calcoliamo quanto spazio occupa il testo renderizzato
        final textSpan = TextSpan(text: text, style: style);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        // overflow rilevato -> attiva marquee
        if (textPainter.width > constraints.maxWidth) {
          return Marquee(
            text: text,
            style: style,
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            blankSpace: 30.0,
            velocity: 30.0, // velocità standard, non troppo aggressiva
            pauseAfterRound: const Duration(seconds: 3),
            startPadding: 0.0,
            accelerationDuration: const Duration(seconds: 1),
            accelerationCurve: Curves.linear,
            decelerationDuration: const Duration(milliseconds: 500),
            decelerationCurve: Curves.easeOut,
          );
        }
        // nessun overflow -> testo statico
        else {
          if (centerIfStationary) {
            return Center(
              child: Text(
                text,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }
          return Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
      },
    );
  }
}
