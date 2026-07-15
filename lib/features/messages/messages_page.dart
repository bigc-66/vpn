import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/models/auth_models.dart';
import '../../core/state/app_controller.dart';
import '../browser/internal_browser_page.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('${strings.messagesTitle} (${controller.messages.length})'),
          ),
          body: controller.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(strings.messagesEmpty, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: controller.messages.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final msg = controller.messages[index];
                    return _MessageTile(
                      message: msg,
                      onOpenUrl: (url, carryCredentials) => _openUrl(
                        ctx,
                        carryCredentials
                            ? controller.buildAuthUrl(url)
                            : url,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _openUrl(
    BuildContext context,
    String urlString,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InternalBrowserPage(url: urlString),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.onOpenUrl});

  final PushMessage message;
  final void Function(String url, bool carryCredentials) onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final timeStr = _fmt(message.receivedAt);
    final strings = AppStrings.of(context);
    return ListTile(
      leading: Icon(
        message.type == PushMessageType.textWithUrl
            ? Icons.open_in_browser
            : Icons.notifications,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(message.text),
      subtitle: Text(timeStr, style: const TextStyle(fontSize: 11)),
      trailing: message.type == PushMessageType.textWithUrl && message.url != null
          ? TextButton(
              onPressed: () =>
                  onOpenUrl(message.url!, message.carryCredentials),
              child: Text(strings.messagesOpen),
            )
          : null,
    );
  }

  String _fmt(DateTime dt) {
    final d = dt.toLocal();
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }
}
