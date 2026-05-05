import 'package:flutter/foundation.dart';

class GoogleOAuthConfig {
  GoogleOAuthConfig._();

  static const androidPackageName = 'com.debbie.debbie';

  static const _serverClientIdValue = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const _iosClientIdValue = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  static String? get serverClientId => _normalized(_serverClientIdValue);
  static String? get iosClientId => _normalized(_iosClientIdValue);

  static bool get requiresIosClientId =>
      defaultTargetPlatform == TargetPlatform.iOS;

  static String? _normalized(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
