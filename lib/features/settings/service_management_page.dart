import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/models/auth_models.dart';
import '../../core/models/vpn_status.dart';
import '../../core/state/app_controller.dart';

/// 服务管理独立页面 —— 查看服务列表、切换、删除、修改用户信息。
class ServiceManagementPage extends StatelessWidget {
  const ServiceManagementPage({
    super.key,
    required this.controller,
    this.onAddService,
  });

  final AppController controller;
  final VoidCallback? onAddService;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(s.serviceManagement),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: s.addNewService,
                onPressed: () {
                  Navigator.pop(context); // 先返回设置页
                  onAddService?.call();   // 再触发添加服务流程
                },
              ),
            ],
          ),
          body: controller.services.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_outlined,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant),
                      const SizedBox(height: 12),
                      Text(s.noServices,
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.outline)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onAddService?.call();
                        },
                        icon: const Icon(Icons.add),
                        label: Text(s.addServiceEntry),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: controller.services.length,
                  itemBuilder: (context, i) {
                    final svc = controller.services[i];
                    final isCurrent = svc.liUrl == controller.liUrl &&
                        svc.username == controller.username;
                    final isConnected = isCurrent &&
                        controller.vpnStatus == VpnStatus.connected;
                    return _ServiceCard(
                      service: svc,
                      isCurrentService: isCurrent,
                      isConnected: isConnected,
                      onSwitch: () => controller.switchService(svc.id),
                      onDelete: () =>
                          _onDeleteService(context, svc, s),
                      onModify: () =>
                          _onModifyUser(context, svc, s),
                    );
                  },
                ),
        );
      },
    );
  }

  void _onDeleteService(
      BuildContext context, ServiceEntry svc, AppStrings s) {
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

  void _onModifyUser(
      BuildContext context, ServiceEntry svc, AppStrings s) {
    final userCtl = TextEditingController(text: svc.username);
    final pwdCtl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.modifyUserInfo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtl,
              decoration: InputDecoration(
                labelText: s.loginUsername,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdCtl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: s.loginPassword,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel)),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (userCtl.text.trim().isNotEmpty) {
                controller.updateServiceUsername(
                    svc.id, userCtl.text.trim());
              }
            },
            child: Text(s.confirm),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.isCurrentService,
    required this.isConnected,
    required this.onSwitch,
    required this.onDelete,
    required this.onModify,
  });

  final ServiceEntry service;
  final bool isCurrentService;
  final bool isConnected;
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
      child: Column(
        children: [
          // 标题行
          ListTile(
            leading: Icon(
              isCurrentService ? Icons.check_circle : Icons.cloud_outlined,
              color: isCurrentService
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            title: Text(
              service.serverName.isNotEmpty
                  ? service.serverName
                  : service.liUrl,
              style: theme.textTheme.titleSmall,
            ),
            trailing: isCurrentService
                ? Chip(
                    label: Text(s.statusSelected,
                        style: const TextStyle(fontSize: 11)),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  )
                : null,
          ),
          const Divider(height: 1),
          // 服务器地址
          ListTile(
            dense: true,
            leading: const Icon(Icons.dns_outlined, size: 20),
            title: Text(s.serverAddress),
            subtitle: Text(service.liUrl),
          ),
          // 用户名
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline, size: 20),
            title: Text(s.loginUsername),
            subtitle: Text(service.username),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onModify,
              tooltip: s.modifyUserInfo,
            ),
          ),
          const Divider(height: 1),
          // 操作按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isCurrentService)
                  TextButton(
                      onPressed: onSwitch,
                      child: Text(s.switchService)),
                if (!isConnected)
                  TextButton(
                    onPressed: onDelete,
                    child: Text(s.deleteService,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
