import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/widgets/platform_webview.dart';
import '../../core/models/auth_models.dart';
import '../../core/models/vpn_status.dart';
import '../../core/state/app_controller.dart';
import '../browser/internal_browser_page.dart';

class ConnectPage extends StatelessWidget {
  const ConnectPage({
    super.key,
    required this.controller,
    this.onAddService,
  });

  final AppController controller;

  /// 点击"添加新服务"时的回调（由 app.dart 处理导航）。
  final VoidCallback? onAddService;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final status = controller.vpnStatus;
        final busy = status == VpnStatus.connecting ||
            status == VpnStatus.disconnecting ||
            controller.isBusy;
        final connected = status == VpnStatus.connected;
        final hasLi = controller.liInfo != null;
        final protocols = controller.availableProtocolsForNode;

        // 动态服务公告 URL（携带鉴权）
        final serviceUrl = controller.liInfo?.serviceUrl;
        final authServiceUrl = (serviceUrl != null && serviceUrl.isNotEmpty)
            ? controller.buildAuthUrl(serviceUrl)
            : null;

        // 动态快速服务 URL
        final fLinkUrl = controller.liInfo?.fLinkUrl;
        final customServiceUrl = controller.liInfo?.customServiceUrl;
        final quickUrl = fLinkUrl ?? customServiceUrl;
        final authQuickUrl = (quickUrl != null && quickUrl.isNotEmpty)
            ? controller.buildAuthUrl(quickUrl)
            : null;

        return Scaffold(
          body: SafeArea(
            child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── 接入服务名称 + 连接开关 ──
                  Row(
                    children: [
                      _StatusIndicator(status: status),
                      const Spacer(),
                      SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: busy
                              ? null
                              : () {
                                  if (connected) {
                                    controller.disconnect();
                                  } else {
                                    controller.connect();
                                  }
                                },
                          style: connected
                              ? FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                )
                              : null,
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : Text(connected
                                  ? strings.connectButtonDisconnect
                                  : strings.connectButtonConnect),
                        ),
                      ),
                    ],
                  ),
                  if (controller.lastError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      controller.lastError!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // ── 接入服务选择（默认上次使用）──
                  if (controller.services.isNotEmpty) ...[
                    Text(strings.siteDropdownLabel,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _ServiceDropdown(
                      services: controller.services,
                      currentLiUrl: controller.liUrl,
                      currentUsername: controller.username,
                      serverName: controller.liInfo?.serverName,
                      busy: busy,
                      connected: connected,
                      onServiceSelected: (svc) =>
                          controller.switchService(svc.id),
                      onAddService: onAddService,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── 用户：用户名 + 更换按钮 ──
                  if (controller.username.isNotEmpty) ...[
                    _UserInfoRow(
                      username: controller.username,
                      busy: busy,
                      connected: connected,
                      onChangeUser: onAddService,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── 连接节点选择 ──
                  Text(strings.nodeDropdownLabel,
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _NodeDropdown(
                    nodes: controller.availableNodes,
                    selected: controller.selectedNode,
                    connected: connected,
                    busy: busy,
                    enabled: hasLi && controller.availableNodes.isNotEmpty,
                    onNodeSelected: controller.selectNode,
                    onAddService: onAddService,
                  ),
                  const SizedBox(height: 12),

                  // ── 路由表下载进度 ──
                  if (controller.isBusy &&
                      controller.routeDownloadProgress > 0.0 &&
                      controller.routeDownloadProgress < 1.0) ...[
                    Text('${strings.connectDownloadingRoute}…'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                        value: controller.routeDownloadProgress),
                    Text(
                      '${(controller.routeDownloadProgress * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── 服务公告（后台接口返回 serviceUrl）──
                  if (authServiceUrl != null) ...[
                    _ServiceWebView(authUrl: authServiceUrl),
                    const SizedBox(height: 16),
                  ],

                  // ── 快速服务（后台接口返回 fLinkUrl / customServiceUrl）──
                  if (authQuickUrl != null) ...[
                    Text(strings.quickService,
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    _ServiceUrlCard(
                      url: quickUrl!,
                      authUrl: authQuickUrl,
                    ),
                  ],
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}

/// 接入服务下拉菜单
class _ServiceDropdown extends StatelessWidget {
  const _ServiceDropdown({
    required this.services,
    required this.currentLiUrl,
    required this.currentUsername,
    required this.serverName,
    required this.busy,
    required this.connected,
    required this.onServiceSelected,
    this.onAddService,
  });

  final List<ServiceEntry> services;
  final String currentLiUrl;
  final String currentUsername;
  final String? serverName;
  final bool busy;
  final bool connected;
  final ValueChanged<ServiceEntry> onServiceSelected;
  final VoidCallback? onAddService;

  bool _isCurrent(ServiceEntry svc) =>
      svc.liUrl == currentLiUrl && svc.username == currentUsername;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final isEnabled = !busy && !connected;

    return PopupMenuButton<Object>(
      enabled: isEnabled,
      offset: const Offset(0, 48),
      onSelected: (v) {
        if (v is ServiceEntry) {
          onServiceSelected(v);
        } else if (v == '__add_service__') {
          onAddService?.call();
        }
      },
      itemBuilder: (_) {
        return [
          ...services.map((svc) => PopupMenuItem<Object>(
                value: svc,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _isCurrent(svc)
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color: _isCurrent(svc)
                        ? theme.colorScheme.primary
                        : null,
                  ),
                  title: Text(svc.serverName.isNotEmpty
                      ? svc.serverName
                      : svc.liUrl),
                  subtitle: Text(svc.username,
                      style: theme.textTheme.bodySmall),
                ),
              )),
          const PopupMenuDivider(),
          PopupMenuItem<Object>(
            value: '__add_service__',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.add_circle_outline,
                  size: 20, color: theme.colorScheme.primary),
              title: Text(s.addNewService,
                  style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ),
        ];
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isEnabled
                ? theme.colorScheme.outline
                : theme.colorScheme.outline.withValues(alpha: 0.38),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.dns_outlined,
                size: 20,
                color: isEnabled
                    ? theme.colorScheme.primary
                    : theme.disabledColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serverName ?? currentLiUrl,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isEnabled ? null : theme.disabledColor,
                    ),
                  ),
                  if (serverName != null)
                    Text(currentLiUrl,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor)),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down,
                color: isEnabled ? null : theme.disabledColor),
          ],
        ),
      ),
    );
  }
}

/// 用户信息行：显示当前用户名 + 更换按钮
class _UserInfoRow extends StatelessWidget {
  const _UserInfoRow({
    required this.username,
    required this.busy,
    required this.connected,
    this.onChangeUser,
  });

  final String username;
  final bool busy;
  final bool connected;
  final VoidCallback? onChangeUser;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text('${s.userLabel}：', style: theme.textTheme.bodyMedium),
          Expanded(
            child: Text(
              username,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: busy || connected ? null : onChangeUser,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(s.changeUser),
          ),
        ],
      ),
    );
  }
}

/// 节点下拉菜单（包含所有已添加节点 + "添加新服务"入口）
class _NodeDropdown extends StatelessWidget {
  const _NodeDropdown({
    required this.nodes,
    required this.selected,
    required this.connected,
    required this.busy,
    required this.onNodeSelected,
    this.onAddService,
    this.enabled = true,
  });

  final List<LiNode> nodes;
  final LiNode? selected;
  final bool connected;
  final bool busy;
  final bool enabled;
  final ValueChanged<LiNode> onNodeSelected;
  final VoidCallback? onAddService;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final isEnabled = enabled && !busy && !connected;

    return PopupMenuButton<Object>(
      enabled: isEnabled,
      offset: const Offset(0, 48),
      onSelected: (v) {
        if (v is LiNode) {
          onNodeSelected(v);
        } else if (v == '__add_service__') {
          onAddService?.call();
        }
      },
      itemBuilder: (_) {
        return [
          ...nodes.map((n) => PopupMenuItem<Object>(
                value: n,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    selected == n
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 20,
                    color: selected == n ? theme.colorScheme.primary : null,
                  ),
                  title: Text(n.name),
                  subtitle:
                      Text(n.protocol.label,
                          style: theme.textTheme.bodySmall),
                ),
              )),
          const PopupMenuDivider(),
          PopupMenuItem<Object>(
            value: '__add_service__',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.add_circle_outline,
                  size: 20, color: theme.colorScheme.primary),
              title: Text(s.addNewService,
                  style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ),
        ];
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isEnabled
                ? theme.colorScheme.outline
                : theme.colorScheme.outline.withValues(alpha: 0.38),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.hub_outlined,
                size: 20,
                color: isEnabled
                    ? theme.colorScheme.primary
                    : theme.disabledColor),
            const SizedBox(width: 10),
            Expanded(
              child: selected != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(selected!.name,
                            style: theme.textTheme.bodyMedium),
                        Text(selected!.protocol.label,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.hintColor)),
                      ],
                    )
                  : Text(
                      nodes.isEmpty
                          ? (enabled ? s.connectSelectNode : s.connectSelectNode)
                          : s.connectSelectNode,
                      style: TextStyle(color: theme.hintColor),
                    ),
            ),
            Icon(Icons.keyboard_arrow_down,
                color: isEnabled ? null : theme.disabledColor),
          ],
        ),
      ),
    );
  }
}

/// 连接模式（协议）下拉
class _ProtocolDropdown extends StatelessWidget {
  const _ProtocolDropdown({
    required this.protocols,
    required this.selected,
    required this.busy,
    required this.connected,
    required this.enabled,
    required this.onSelected,
  });

  final List<VpnProtocol> protocols;
  final VpnProtocol selected;
  final bool busy;
  final bool connected;
  final bool enabled;
  final ValueChanged<VpnProtocol> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final isEnabled = enabled && !busy && !connected;

    // 如果只有一种协议，显示为禁用的固定选项
    final effectiveSelected = protocols.length == 1
        ? protocols.first
        : (protocols.contains(selected) ? selected : VpnProtocol.auto);

    final displayLabel = protocols.length == 1
        ? protocols.first.label
        : effectiveSelected == VpnProtocol.auto
            ? s.connectAuto
            : effectiveSelected.label;

    return PopupMenuButton<VpnProtocol>(
      enabled: isEnabled && protocols.length > 1,
      offset: const Offset(0, 48),
      onSelected: onSelected,
      itemBuilder: (_) {
        return protocols.map((p) => PopupMenuItem<VpnProtocol>(
              value: p,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  effectiveSelected == p
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: effectiveSelected == p
                      ? theme.colorScheme.primary
                      : null,
                ),
                title: Text(p.label),
              ),
            )).toList();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isEnabled
                ? theme.colorScheme.outline
                : theme.colorScheme.outline.withValues(alpha: 0.38),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.swap_horiz,
                size: 20,
                color: isEnabled
                    ? theme.colorScheme.primary
                    : theme.disabledColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                protocols.isEmpty ? s.connectSelectProtocol : displayLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: protocols.isEmpty ? theme.hintColor : null),
              ),
            ),
            if (protocols.length > 1)
              Icon(Icons.keyboard_arrow_down,
                  color: isEnabled ? null : theme.disabledColor),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});
  final VpnStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      VpnStatus.connected => (Colors.green, Icons.shield),
      VpnStatus.connecting || VpnStatus.disconnecting => (
          Colors.orange,
          Icons.sync
        ),
      VpnStatus.error => (Colors.red, Icons.error_outline),
      _ => (Colors.grey, Icons.shield_outlined),
    };

    final strings = AppStrings.of(context);
    final locale = strings.locale;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 12),
        Text(
          status.label(locale),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// 首页下方服务页面卡片（service_url）
class _ServiceUrlCard extends StatelessWidget {
  const _ServiceUrlCard({required this.url, required this.authUrl});
  final String url;
  final String authUrl;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InternalBrowserPage(url: authUrl),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.language_rounded,
                  size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.serviceWebEntry,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// 首页内嵌服务页面 WebView
class _ServiceWebView extends StatefulWidget {
  const _ServiceWebView({required this.authUrl});
  final String authUrl;

  @override
  State<_ServiceWebView> createState() => _ServiceWebViewState();
}

class _ServiceWebViewState extends State<_ServiceWebView> {
  final _controller = PlatformWebViewController();
  bool _ready = false;
  bool _error = false;
  String? _errorMsg;
  double _height = 320;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _controller.onPageFinished = _measureHeight;
      await _controller.initialize();
      await _controller.loadUrl(widget.authUrl);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() { _error = true; _errorMsg = e.toString(); });
    }
  }

  Future<void> _measureHeight() async {
    try {
      final result = await _controller
          .executeScript('document.documentElement.scrollHeight.toString()');
      final parsed = double.tryParse(result.replaceAll('"', ''));
      if (parsed != null && parsed > 0 && mounted) {
        setState(() => _height = parsed.clamp(100, 2000));
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant _ServiceWebView old) {
    super.didUpdateWidget(old);
    if (old.authUrl != widget.authUrl && _ready) {
      _controller.loadUrl(widget.authUrl);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    if (_error) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.cloud_off, size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text(s.serviceWebError,
                  style: TextStyle(color: theme.colorScheme.outline)),
              const SizedBox(height: 4),
              Text(widget.authUrl,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outlineVariant),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(s.retryLabel),
                    onPressed: () {
                      setState(() { _error = false; _ready = false; _errorMsg = null; });
                      _init();
                    },
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_browser, size: 16),
                    label: Text(s.messagesOpen),
                    onPressed: () {
                      Navigator.push(context,
                        MaterialPageRoute(
                          builder: (_) => InternalBrowserPage(
                            url: widget.authUrl,
                            title: s.serviceWebTitle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (!_ready) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _controller.buildWidget(),
      ),
    );
  }
}
