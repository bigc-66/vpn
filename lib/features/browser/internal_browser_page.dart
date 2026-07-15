import 'package:flutter/material.dart';

import '../../core/widgets/platform_webview.dart';

/// 内置浏览器页面，支持后退、前进、首页、刷新操作。
class InternalBrowserPage extends StatefulWidget {
  const InternalBrowserPage({
    super.key,
    required this.url,
    this.title,
  });

  final String url;
  final String? title;

  @override
  State<InternalBrowserPage> createState() => _InternalBrowserPageState();
}

class _InternalBrowserPageState extends State<InternalBrowserPage> {
  final _controller = PlatformWebViewController();
  bool _ready = false;
  bool _error = false;
  String _currentTitle = '';

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.title ?? '';
    _init();
  }

  Future<void> _init() async {
    try {
      _controller.onPageFinished = _onPageFinished;
      await _controller.initialize();
      await _controller.loadUrl(widget.url);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _onPageFinished() async {
    try {
      final title = await _controller.executeScript('document.title');
      final cleaned = title.replaceAll('"', '');
      if (cleaned.isNotEmpty && mounted) {
        setState(() => _currentTitle = cleaned);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTitle.isNotEmpty ? _currentTitle : '浏览器',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _ready ? () => _controller.goBack() : null,
            tooltip: '后退',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _ready ? () => _controller.goForward() : null,
            tooltip: '前进',
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: _ready
                ? () => _controller.loadUrl(widget.url)
                : null,
            tooltip: '首页',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _ready ? () => _controller.reload() : null,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            const Text('加载失败'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _error = false;
                  _ready = false;
                });
                _init();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return _controller.buildWidget();
  }
}
