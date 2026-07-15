import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/state/app_controller.dart';
import '../../core/widgets/platform_webview.dart';

/// F-Link 标签页 —— 用内嵌 WebView 显示 f_link_url 对应的服务页面。
class FLinkPage extends StatefulWidget {
  const FLinkPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<FLinkPage> createState() => _FLinkPageState();
}

class _FLinkPageState extends State<FLinkPage> {
  final _webviewController = PlatformWebViewController();
  bool _ready = false;
  bool _error = false;
  String? _lastUrl;

  @override
  void initState() {
    super.initState();
    _initWebView();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _webviewController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final url = _buildUrl();
    if (url != _lastUrl && _ready) {
      _lastUrl = url;
      if (url != null) {
        _webviewController.loadUrl(url);
      }
    }
  }

  String? _buildUrl() {
    final fLinkUrl = widget.controller.liInfo?.fLinkUrl;
    if (fLinkUrl == null || fLinkUrl.isEmpty) return null;
    return widget.controller.buildAuthUrl(fLinkUrl);
  }

  Future<void> _initWebView() async {
    try {
      await _webviewController.initialize();
      final url = _buildUrl();
      _lastUrl = url;
      if (url != null) {
        await _webviewController.loadUrl(url);
      }
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final hasFLink = _buildUrl() != null;

        return Scaffold(
          appBar: AppBar(
            title: Text(s.navFlink),
            actions: [
              if (_ready && hasFLink) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _webviewController.goBack(),
                  tooltip: '后退',
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _webviewController.goForward(),
                  tooltip: '前进',
                ),
                IconButton(
                  icon: const Icon(Icons.home_outlined),
                  onPressed: () {
                    final url = _buildUrl();
                    if (url != null) _webviewController.loadUrl(url);
                  },
                  tooltip: '首页',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _webviewController.reload(),
                  tooltip: s.serviceWebLoading,
                ),
              ],
            ],
          ),
          body: _buildBody(theme, s, hasFLink),
        );
      },
    );
  }

  Widget _buildBody(ThemeData theme, AppStrings s, bool hasFLink) {
    if (!hasFLink) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.web_outlined, size: 48, color: theme.disabledColor),
            const SizedBox(height: 12),
            Text(s.navFlink,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.disabledColor)),
          ],
        ),
      );
    }

    if (_error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(s.serviceWebError, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _error = false;
                  _ready = false;
                });
                _initWebView();
              },
              icon: const Icon(Icons.refresh),
              label: Text(s.speedTestStart),
            ),
          ],
        ),
      );
    }

    if (!_ready) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(s.serviceWebLoading),
          ],
        ),
      );
    }

    return _webviewController.buildWidget();
  }
}
