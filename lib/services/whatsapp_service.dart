import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

/*
 * interfaccia verso il mondo esterno (whatsapp).
 * gestisce il fallback intelligente: prova app nativa -> se manca usa browser.
 * isola la logica di 'url_launcher' per non sporcare i widget.
 */
class WhatsAppService {
  // numero target. prefisso 39 obbligatorio, niente +.
  static const String _phoneNumber = "393400847271";
  static const String _message = "Ciao Radio Fossano!";

  static Future<void> openWhatsApp(BuildContext context) async {
    // uri scheme per app nativa
    final Uri whatsappUrl = Uri.parse(
      "whatsapp://send?phone=$_phoneNumber&text=${Uri.encodeComponent(_message)}",
    );

    // uri fallback per browser/whatsapp web
    final Uri webUrl = Uri.parse(
      "https://wa.me/$_phoneNumber?text=${Uri.encodeComponent(_message)}",
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl); // corsia preferenziale: app installata
      } else {
        // niente app, andiamo di browser esterno
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // tutto fallito. notifica utente e amen.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire WhatsApp')),
      );
    }
  }
}
