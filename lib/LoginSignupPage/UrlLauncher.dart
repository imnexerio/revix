import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../Utils/customSnackBar_error.dart';

class UrlLauncher {
  static void launchURL(BuildContext context, String url) async {
    if (kIsWeb) {
      final urlUri = Uri.parse(url);
      try {
        await launchUrl(urlUri, webOnlyWindowName: '_blank');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          customSnackBar_error(
            context: context,
            message: 'Error launching URL: $e',
          ),
        );
      }
    } else {
      final Uri uri = Uri.parse(url);
      try {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception('Could not launch $url');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          customSnackBar_error(
            context: context,
            message: 'Error launching URL: $e',
          ),
        );
      }
    }
  }
}