// import 'package:url_launcher/url_launcher.dart';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'dart:js' as js;
//
// class UrlLauncher {
//   static void launchURL(String url) async {
//     if (kIsWeb) {
//       // Web-specific launch method
//       js.context.callMethod('open', [url, '_blank']);
//     } else {
//       // Mobile and desktop launch method
//       final Uri uri = Uri.parse(url);
//       try {
//         if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
//           throw Exception('Could not launch $url');
//         }
//       } catch (e) {
//         print('Error launching URL: $e');
//       }
//     }
//   }
// }


import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// For web platform
// @JS()
// library javascript_launcher;

class UrlLauncher {
  static void launchURL(String url) async {
    if (kIsWeb) {
      // Web platform
      // Using window.open() through a JavaScript interop
      // This part will only be included in web builds
      final urlUri = Uri.parse(url);
      try {
        await launchUrl(urlUri, webOnlyWindowName: '_blank');
      } catch (e) {
        print('Error launching URL: $e');
      }
    } else {
      // Mobile and desktop platforms
      final Uri uri = Uri.parse(url);
      try {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception('Could not launch $url');
        }
      } catch (e) {
        print('Error launching URL: $e');
      }
    }
  }
}