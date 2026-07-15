import '../i18n/app_strings.dart';

enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

extension VpnStatusLabel on VpnStatus {
  String get zhLabel => label(AppLocale.zh);

  String label(AppLocale locale) {
    final s = AppStrings.forLocale(locale);
    return switch (this) {
      VpnStatus.disconnected => s.statusDisconnected,
      VpnStatus.connecting => s.statusConnecting,
      VpnStatus.connected => s.statusConnected,
      VpnStatus.disconnecting => s.statusDisconnecting,
      VpnStatus.error => s.statusError,
    };
  }
}
