import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/models/auth_models.dart';
import '../../core/state/app_controller.dart';
import '../browser/internal_browser_page.dart';

/// 服务管理页面 —— 我的服务列表 + 站点信息 + 自定义服务入口。
class ServiceWebPage extends StatelessWidget {
  const ServiceWebPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final liInfo = controller.liInfo;
        final customUrl = liInfo?.customServiceUrl;
        final hasCustom = customUrl != null && customUrl.isNotEmpty;
        final fLinkUrl = liInfo?.fLinkUrl;
        final hasFLink = fLinkUrl != null && fLinkUrl.isNotEmpty;

        return Scaffold(
          appBar: AppBar(title: Text(s.myServices)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── F-Link 服务页面（f_link_url）──
                  if (hasFLink) ...[
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openUrl(context, controller.buildAuthUrl(fLinkUrl)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.web_rounded,
                                  size: 32, color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.fLinkWebPage,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(fLinkUrl,
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
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── 我的服务列表 ──
                  if (controller.services.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(s.serviceManagement,
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: theme.colorScheme.primary)),
                    ),
                    const SizedBox(height: 8),
                    ...controller.services.map((svc) => _ServiceCard(
                          service: svc,
                          isCurrentService:
                              svc.liUrl == controller.liUrl &&
                              svc.username == controller.username,
                          onSwitch: () => _onSwitchService(context, svc),
                          onDelete: () => _onDeleteService(context, svc),
                          onModify: () => _onModifyUser(context, svc),
                        )),
                    const SizedBox(height: 16),
                  ],

                  // 站点信息卡
                  if (liInfo != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.cloud_done_outlined,
                                    color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(liInfo.serverName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                                label: s.siteDropdownLabel,
                                value: liInfo.primaryDomain),
                            if (controller.userConfig != null) ...[
                              _InfoRow(
                                  label: s.connectUser,
                                  value: controller.username),
                              _InfoRow(
                                  label: s.connectSubscription,
                                  value:
                                      controller.userConfig!.subscription),
                              _InfoRow(
                                  label: s.connectExpiry,
                                  value: _fmtDate(
                                      controller.userConfig!.expiryTime)),
                            ],
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 服务公告 / 客户提示 / 领取客户福利
                  if (hasCustom) ...[
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.campaign_outlined,
                            color: theme.colorScheme.primary),
                        title: Text(s.serviceAnnouncement),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openUrl(context, customUrl),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.tips_and_updates_outlined,
                            color: theme.colorScheme.primary),
                        title: Text(s.customerTips),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openUrl(context, customUrl),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: Icon(Icons.card_giftcard,
                            color: theme.colorScheme.primary),
                        title: Text(s.claimBenefits),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openUrl(context, customUrl),
                      ),
                    ),
                  ],

                  // 白名单 WEB 地址列表
                  if (liInfo != null &&
                      liInfo.webWhitelist.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(s.sectionExtendedService,
                          style: theme.textTheme.labelLarge),
                    ),
                    const SizedBox(height: 8),
                    ...liInfo.webWhitelist.map((url) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.language),
                            title: Text(url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.open_in_new, size: 18),
                            onTap: () => _openUrl(context, url),
                          ),
                        )),
                  ],

                  // 未登录或无站点
                  if (liInfo == null && controller.services.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          Icon(Icons.web_outlined,
                              size: 48, color: theme.disabledColor),
                          const SizedBox(height: 12),
                          Text(s.noServices,
                              style:
                                  TextStyle(color: theme.disabledColor)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onSwitchService(BuildContext context, ServiceEntry svc) {
    controller.switchService(svc.id);
  }

  void _onDeleteService(BuildContext context, ServiceEntry svc) {
    final s = AppStrings.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteService),
        content: Text(s.deleteServiceConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel)),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.removeService(svc.id);
            },
            child: Text(s.confirm),
          ),
        ],
      ),
    );
  }

  void _onModifyUser(BuildContext context, ServiceEntry svc) {
    final s = AppStrings.of(context);
    final userCtl = TextEditingController(text: svc.username);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.modifyUserInfo),
        content: TextField(
          controller: userCtl,
          decoration: InputDecoration(
            labelText: s.loginUsername,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel)),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (userCtl.text.trim().isNotEmpty) {
                controller.updateServiceUsername(svc.id, userCtl.text.trim());
              }
            },
            child: Text(s.confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String rawUrl) async {
    final url = controller.buildAuthUrl(rawUrl);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InternalBrowserPage(url: url),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// 单个服务卡片
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.isCurrentService,
    required this.onSwitch,
    required this.onDelete,
    required this.onModify,
  });

  final ServiceEntry service;
  final bool isCurrentService;
  final VoidCallback onSwitch;
  final VoidCallback onDelete;
  final VoidCallback onModify;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Card(
      color: isCurrentService
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCurrentService ? Icons.check_circle : Icons.cloud_outlined,
                  color: isCurrentService
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    service.serverName.isNotEmpty
                        ? service.serverName
                        : service.liUrl,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${s.connectUser}: ${service.username}',
                style: theme.textTheme.bodySmall),
            Text(service.liUrl, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isCurrentService)
                  TextButton(onPressed: onSwitch, child: Text(s.switchService)),
                TextButton(onPressed: onModify, child: Text(s.modifyUserInfo)),
                TextButton(
                  onPressed: onDelete,
                  child: Text(s.deleteService,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
              child: Text(value,
                  style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
