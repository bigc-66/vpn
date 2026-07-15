import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' as wf;
import 'package:webview_windows/webview_windows.dart' as ww;

/// 跨平台 WebView 控制器 —— Windows 使用 webview_windows，Android/iOS 使用 webview_flutter。
class PlatformWebViewController {
  ww.WebviewController? _win;
  wf.WebViewController? _mobile;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// 页面加载完成回调
  void Function()? onPageFinished;

  Future<void> initialize() async {
    if (Platform.isWindows) {
      _win = ww.WebviewController();
      await _win!.initialize();
      _win!.loadingState.listen((state) {
        if (state == ww.LoadingState.navigationCompleted) {
          onPageFinished?.call();
        }
      });
    } else {
      _mobile = wf.WebViewController()
        ..setJavaScriptMode(wf.JavaScriptMode.unrestricted)
        ..setNavigationDelegate(wf.NavigationDelegate(
          onPageFinished: (_) => onPageFinished?.call(),
        ));
    }
    _initialized = true;
  }

  Future<String> executeScript(String script) async {
    if (Platform.isWindows) {
      final result = await _win?.executeScript(script);
      return result?.toString() ?? '';
    } else {
      final result = await _mobile?.runJavaScriptReturningResult(script);
      return result?.toString() ?? '';
    }
  }

  Future<void> loadUrl(String url) async {
    if (Platform.isWindows) {
      await _win?.loadUrl(url);
    } else {
      await _mobile?.loadRequest(Uri.parse(url));
    }
  }

  Future<void> reload() async {
    if (Platform.isWindows) {
      await _win?.reload();
    } else {
      await _mobile?.reload();
    }
  }

  Future<void> goBack() async {
    if (Platform.isWindows) {
      await _win?.goBack();
    } else {
      await _mobile?.goBack();
    }
  }

  Future<void> goForward() async {
    if (Platform.isWindows) {
      await _win?.goForward();
    } else {
      await _mobile?.goForward();
    }
  }

  Future<bool> canGoBack() async {
    if (Platform.isWindows) {
      // webview_windows 没有 canGoBack API，用 JS 检测
      try {
        final result = await executeScript('window.history.length > 1');
        return result == 'true';
      } catch (_) {
        return false;
      }
    } else {
      return await _mobile?.canGoBack() ?? false;
    }
  }

  Future<bool> canGoForward() async {
    if (Platform.isWindows) {
      return false; // webview_windows 无直接 API
    } else {
      return await _mobile?.canGoForward() ?? false;
    }
  }

  void dispose() {
    _win?.dispose();
  }

  Widget buildWidget() {
    if (Platform.isWindows) {
      return ww.Webview(_win!);
    } else {
      return wf.WebViewWidget(controller: _mobile!);
    }
  }
}
