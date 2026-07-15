import 'package:flutter/material.dart';

import 'app_strings.dart';

/// 管理当前 App 语言，挂载到 [MaterialApp.locale]。
class LocaleController extends ChangeNotifier {
  AppLocale _locale = AppLocale.zh;

  AppLocale get appLocale => _locale;
  Locale get locale => _locale.locale;

  void setLocale(AppLocale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  void toggle() {
    setLocale(_locale == AppLocale.zh ? AppLocale.en : AppLocale.zh);
  }
}
