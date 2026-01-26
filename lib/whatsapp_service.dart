import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class WhatsAppService {
  // 🔴 INSERISCI QUI IL NUMERO DELLA RADIO (con prefisso 39, senza +)
  static const String _phoneNumber = "393400847271";

  // Messaggio preimpostato (opzionale)
  static const String _message = "Ciao Radio Fossano!";

  static Future<void> openWhatsApp(BuildContext context) async {
    // Tentiamo di aprire l'app nativa
    final Uri whatsappUrl = Uri.parse(
      "whatsapp://send?phone=$_phoneNumber&text=${Uri.encodeComponent(_message)}",
    );
    // Fallback: apriamo il browser se l'app non c'è
    final Uri webUrl = Uri.parse(
      "https://wa.me/$_phoneNumber?text=${Uri.encodeComponent(_message)}",
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else {
        // Se non ha WhatsApp installato, apre il browser
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire WhatsApp')),
      );
    }
  }
}
