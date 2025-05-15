import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

class PlatformUtils {
  PlatformUtils._();

  static final PlatformUtils _instance = PlatformUtils._();
  static PlatformUtils get instance => _instance;

  late final bool isWeb;
  late final bool isAndroid;
  late final bool isIOS;
  late final bool isMacOS;
  late final bool isWindows;
  late final bool isLinux;
  late final bool isFuchsia;

  // Initialize platform checks
  static void init() {
    _instance.isWeb = kIsWeb;

    if (!kIsWeb) {
      _instance.isAndroid = io.Platform.isAndroid;
      _instance.isIOS = io.Platform.isIOS;
      _instance.isMacOS = io.Platform.isMacOS;
      _instance.isWindows = io.Platform.isWindows;
      _instance.isLinux = io.Platform.isLinux;
      _instance.isFuchsia = io.Platform.isFuchsia;
    } else {
      // Default values for web
      _instance.isAndroid = false;
      _instance.isIOS = false;
      _instance.isMacOS = false;
      _instance.isWindows = false;
      _instance.isLinux = false;
      _instance.isFuchsia = false;
    }
  }
}