import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/state/app_controller.dart';

// ═══════════════════════════════════════════════════════════════════
// 第 1 级 —— 本地分流 主页
// ═══════════════════════════════════════════════════════════════════

class SplitRoutingPage extends StatefulWidget {
  const SplitRoutingPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SplitRoutingPage> createState() => _SplitRoutingPageState();
}

class _SplitRoutingPageState extends State<SplitRoutingPage> {
  bool _showAbout = false;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.localSplitRouting)),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (_, __) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 关于本地分流 ──
                _AboutSection(
                  title: s.aboutLocalSplit,
                  description: s.aboutLocalSplitDesc,
                  expanded: _showAbout,
                  onToggle: () =>
                      setState(() => _showAbout = !_showAbout),
                ),
                const SizedBox(height: 16),

                // ── 分流开关 ──
                Card(
                  child: SwitchListTile(
                    title: Text(s.splitToggle),
                    subtitle: Text(s.splitToggleDesc),
                    value: widget.controller.splitRoutingEnabled,
                    onChanged: (v) =>
                        widget.controller.setSplitRoutingEnabled(v),
                  ),
                ),
                const SizedBox(height: 8),

                // ── 自定义分流列表 入口 ──
                Card(
                  child: ListTile(
                    title: Text(s.customRouteList),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _CustomRouteListPage(
                            controller: widget.controller),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 第 2 级 —— 自定义分流列表
// ═══════════════════════════════════════════════════════════════════

class _CustomRouteListPage extends StatefulWidget {
  const _CustomRouteListPage({required this.controller});
  final AppController controller;

  @override
  State<_CustomRouteListPage> createState() => _CustomRouteListPageState();
}

class _CustomRouteListPageState extends State<_CustomRouteListPage> {
  bool _showAbout = false;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.customRouteList)),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (_, __) {
          final routes = widget.controller.splitRoutes;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  // ── 关于自定义分流 ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _AboutSection(
                      title: s.aboutCustomSplit,
                      description: s.aboutCustomSplitDesc,
                      expanded: _showAbout,
                      onToggle: () =>
                          setState(() => _showAbout = !_showAbout),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── 路由列表 ──
                  Expanded(
                    child: routes.isEmpty
                        ? Center(
                            child: Text(s.splitEmpty,
                                style: TextStyle(
                                    color: theme.colorScheme.outline)))
                        : ListView.separated(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: routes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (_, i) {
                              final r = routes[i];
                              final label = r.name.isNotEmpty
                                  ? '${r.name}  ${r.target}'
                                  : r.target;
                              return Card(
                                child: ListTile(
                                  title: Text(label),
                                  trailing: TextButton(
                                    onPressed: () => widget.controller
                                        .removeSplitRoute(r.target),
                                    child: Text(s.splitDelete,
                                        style: TextStyle(
                                            color:
                                                theme.colorScheme.error)),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // ── 底部：添加自定义分流 ──
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _AddCustomRoutePage(
                                controller: widget.controller),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.addCustomRoute,
                                style: theme.textTheme.titleSmall),
                            const SizedBox(width: 6),
                            Icon(Icons.add_circle_outline,
                                size: 20,
                                color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 第 3 级 —— 添加自定义分流
// ═══════════════════════════════════════════════════════════════════

class _AddCustomRoutePage extends StatefulWidget {
  const _AddCustomRoutePage({required this.controller});
  final AppController controller;

  @override
  State<_AddCustomRoutePage> createState() => _AddCustomRoutePageState();
}

class _AddCustomRoutePageState extends State<_AddCustomRoutePage> {
  final _nameCtl = TextEditingController();
  final _ipCtl = TextEditingController();
  bool _showAbout = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _ipCtl.dispose();
    super.dispose();
  }

  void _add() {
    final ip = _ipCtl.text.trim();
    final name = _nameCtl.text.trim();
    final err = widget.controller.addSplitRoute(ip, name: name);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.addCustomRoute)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 关于添加分流 ──
              _AboutSection(
                title: s.aboutAddRoute,
                description: s.aboutAddRouteDesc,
                expanded: _showAbout,
                onToggle: () =>
                    setState(() => _showAbout = !_showAbout),
              ),
              const SizedBox(height: 24),

              // ── 名称输入（可选） ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _nameCtl,
                    decoration: InputDecoration(
                      labelText: s.splitRouteName,
                      hintText: s.splitRouteNameHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── IP 地址输入 ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _ipCtl,
                    decoration: InputDecoration(
                      labelText: s.splitIpLabel,
                      hintText: s.splitHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── 添加按钮 ──
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _add,
                  child: Text(s.splitAdd),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 共享组件 —— 可折叠的「关于…」说明区域
// ═══════════════════════════════════════════════════════════════════

class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.title,
    required this.description,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final String description;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
            TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact),
              child: Text(expanded ? s.aboutCollapse : s.aboutExpand),
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
              child: Text(description,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ),
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
