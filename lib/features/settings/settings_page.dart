import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/state/app_controller.dart';
import '../browser/internal_browser_page.dart';
import '../split_routing/split_routing_page.dart';
import 'log_management_page.dart';
import 'service_management_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.localeController,
    this.unreadMessages = 0,
    this.onAddService,
  });

  final AppController controller;
  final LocaleController? localeController;
  final int unreadMessages;
  final VoidCallback? onAddService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [controller, if (localeController != null) localeController!]),
      builder: (ctx, __) {
        final strings = localeController != null
            ? AppStrings.forLocale(localeController!.appLocale)
            : AppStrings.forLocale(AppLocale.zh);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // —— 本地分流 ——
              _SettingsEntry(
                icon: Icons.route,
                label: strings.localSplitRouting,
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => SplitRoutingPage(controller: controller),
                  ),
                ),
              ),

              // —— 服务管理 ——
              _SettingsEntry(
                icon: Icons.dns_outlined,
                label: strings.serviceManagement,
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => ServiceManagementPage(
                      controller: controller,
                      onAddService: onAddService,
                    ),
                  ),
                ),
              ),

              // —— 客户端外部控制 ——
              _SettingsEntry(
                icon: Icons.settings_remote,
                label: strings.externalControl,
                onTap: () => _showExternalControlSheet(ctx, strings),
              ),

              // —— 日志 ——
              _SettingsEntry(
                icon: Icons.article_outlined,
                label: strings.logManagement,
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) =>
                        LogManagementPage(controller: controller),
                  ),
                ),
              ),

              // —— 关于 F-Link ——
              _SettingsEntry(
                icon: Icons.flag_outlined,
                label: strings.aboutFlink,
                onTap: () => _showAboutFlink(ctx, strings),
              ),
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  void _showExternalControlSheet(BuildContext context, AppStrings strings) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.externalControl,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(strings.externalControlDesc,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(strings.externalControl),
                value: controller.externalControlEnabled,
                onChanged: (v) {
                  controller.setExternalControlEnabled(v);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutFlink(BuildContext context, AppStrings strings) {
    final li = controller.liInfo;
    final desc = li?.aboutDescription ?? strings.aboutFlinkDesc;
    final team = li?.aboutTeam ?? strings.aboutFlinkTeam;
    final email = li?.aboutEmail ?? strings.aboutFlinkEmail;
    final website = li?.aboutWebsite ?? 'https://www.netsignory.com';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.vpn_lock_rounded,
                      size: 32, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(strings.aboutFlink,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(desc,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Text(team,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              // 联络方式
              Row(
                children: [
                  Icon(Icons.email_outlined,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(strings.aboutFlinkContact,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: SelectableText(
                  email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.language),
                  label: Text(strings.visitFlinkWebsite),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InternalBrowserPage(url: website),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────
// 设置项卡片
// ─────────────────────────────────────────────────────────────────

class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.onSurface),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label,
                      style: theme.textTheme.bodyLarge),
                ),
                Icon(Icons.arrow_forward,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
