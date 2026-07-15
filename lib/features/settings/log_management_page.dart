import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/state/app_controller.dart';

// ═══════════════════════════════════════════════════════════════════
// 日志 —— 一级页面：查看日志 + 清空 + 进入上传
// ═══════════════════════════════════════════════════════════════════

class LogManagementPage extends StatelessWidget {
  const LogManagementPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.logManagement)),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final logContent = controller.collectLogContentPublic();
          final hasLog = logContent.trim().isNotEmpty;

          return Column(
            children: [
              // ── 日志内容 ──
              Expanded(
                child: hasLog
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          logContent,
                          style: const TextStyle(
                              fontSize: 12, fontFamily: 'monospace', height: 1.5),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.article_outlined,
                                size: 48,
                                color: theme.colorScheme.outlineVariant),
                            const SizedBox(height: 12),
                            Text(s.logEmpty,
                                style: TextStyle(
                                    color: theme.colorScheme.outline)),
                          ],
                        ),
                      ),
              ),

              // ── 底部按钮栏 ──
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // 清空按钮
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hasLog
                              ? () => _confirmClear(context, s)
                              : null,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(s.logClear),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 上传按钮
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  LogUploadPage(controller: controller),
                            ),
                          ),
                          icon: const Icon(Icons.upload, size: 18),
                          label: Text(s.settingsLogUpload),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmClear(BuildContext context, AppStrings s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.logClear),
        content: Text(s.logClearConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.clearLog();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(s.logCleared)));
            },
            child: Text(s.confirm),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 上传日志至服务商 —— 二级页面
// ═══════════════════════════════════════════════════════════════════

class LogUploadPage extends StatefulWidget {
  const LogUploadPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<LogUploadPage> createState() => _LogUploadPageState();
}

class _LogUploadPageState extends State<LogUploadPage> {
  String? _selectedServiceId;
  bool _showAbout = true;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.logUploadResult = null;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // 默认选择当前活跃的服务
        if (_selectedServiceId == null && controller.services.isNotEmpty) {
          final active = controller.services
              .where((svc) => svc.isActive)
              .toList();
          _selectedServiceId =
              active.isNotEmpty ? active.first.id : controller.services.first.id;
        }

        final hasLog = controller.collectLogContentPublic().trim().isNotEmpty;

        return Scaffold(
          appBar: AppBar(title: Text(s.settingsLogUpload)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── 关于上传日志的说明 ──
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(s.logUploadAbout,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.primary)),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _showAbout = !_showAbout),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        child: Text(_showAbout ? s.aboutCollapse : s.aboutExpand),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.logUploadAboutDesc,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    crossFadeState: _showAbout
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),

                  const SizedBox(height: 24),

                  // ── 选择需要上传的服务商 ──
                  Text(s.logSelectService,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),

                  // 服务商选项列表
                  ...controller.services.map((svc) {
                    final label = svc.serverName.isNotEmpty
                        ? '${svc.serverName} (${svc.username})'
                        : '${svc.liUrl} (${svc.username})';
                    final selected = _selectedServiceId == svc.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: selected
                              ? BorderSide(
                                  color: theme.colorScheme.primary, width: 1.5)
                              : BorderSide.none,
                        ),
                        child: RadioListTile<String>(
                          value: svc.id,
                          groupValue: _selectedServiceId,
                          onChanged: (v) =>
                              setState(() => _selectedServiceId = v),
                          title: Text(label),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // ── 上传按钮 ──
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: controller.isLogUploading ||
                              controller.token.isEmpty ||
                              !hasLog
                          ? null
                          : () {
                              final svc = controller.services
                                  .where((s) => s.id == _selectedServiceId)
                                  .toList();
                              final targetLiUrl = svc.isNotEmpty
                                  ? svc.first.liUrl
                                  : null;
                              controller.uploadLog(
                                  targetLiUrl: targetLiUrl);
                            },
                      icon: controller.isLogUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload, size: 20),
                      label: Text(controller.isLogUploading
                          ? s.settingsLogUploading
                          : s.settingsLogUpload),
                    ),
                  ),

                  // 上传结果提示
                  if (controller.logUploadResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            controller.logUploadResult == 'success'
                                ? Icons.check_circle
                                : Icons.error_outline,
                            size: 16,
                            color: controller.logUploadResult == 'success'
                                ? Colors.green
                                : theme.colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            controller.logUploadResult == 'success'
                                ? s.settingsLogUploadSuccess
                                : s.settingsLogUploadFail,
                            style: TextStyle(
                              fontSize: 13,
                              color: controller.logUploadResult == 'success'
                                  ? Colors.green
                                  : theme.colorScheme.error,
                            ),
                          ),
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
}
