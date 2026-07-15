import 'dart:async';
import 'dart:io' show Platform, exit;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'core/i18n/app_strings.dart';
import 'core/i18n/locale_controller.dart';
import 'core/models/auth_models.dart';
import 'core/models/vpn_status.dart';
import 'core/state/app_controller.dart';
import 'core/state/app_dependencies.dart';
import 'features/connect/connect_page.dart';
import 'features/flink/flink_page.dart';
import 'features/onboarding/add_service_page.dart';
import 'features/settings/settings_page.dart';

class VpnApp extends StatefulWidget {
  const VpnApp({super.key});

  @override
  State<VpnApp> createState() => _VpnAppState();
}

class _VpnAppState extends State<VpnApp> with WindowListener {
  final _navigatorKey = GlobalKey<NavigatorState>();
  AppDependencies? _dependencies;
  AppController? _controller;
  late final LocaleController _localeController;
  StreamSubscription<Uri>? _linkSub;
  int _index = 0;

  /// 是否显示首次引导（新手教程）
  bool _showTutorial = false;
  int _tutorialStep = 0;

  /// 是否处于"新增服务"模式（从节点下拉的"添加新服务"触发）
  bool _addingService = false;

  /// 是否需要显示外部控制提示
  bool _showExternalControlPrompt = false;

  @override
  void initState() {
    super.initState();
    _localeController = LocaleController();
    _initAsync();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
  }

  Future<void> _initAsync() async {
    _dependencies = await AppDependencies.build();
    _controller = AppController(
      vpnService: _dependencies!.vpnService,
      backendRepository: _dependencies!.backendRepository,
    );
    _localeController.addListener(_syncLocale);
    _initDeepLinks();

    // 检查是否首次启动
    final prefs = await SharedPreferences.getInstance();
    final tutorialSeen = prefs.getBool('tutorial_seen') ?? false;
    if (!tutorialSeen) {
      _showTutorial = true;
    }

    // 客户端首次启动提示是否开启外部控制
    await _checkExternalControlPrompt();

    if (mounted) setState(() {});

    // 登录成功后自动检查更新
    _controller!.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (_controller!.loggedIn && !_controller!.versionChecked) {
      _controller!.checkVersion('0.1.0');
    }
  }

  Future<void> _checkExternalControlPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final prompted = prefs.getBool('external_control_prompted') ?? false;
    if (!prompted && mounted) {
      setState(() => _showExternalControlPrompt = true);
      await prefs.setBool('external_control_prompted', true);
    }
  }

  void _syncLocale() {
    _controller?.setLocale(_localeController.appLocale);
  }

  void _initDeepLinks() {
    final appLinks = AppLinks();
    appLinks.getInitialLink().then(_handleLink);
    _linkSub = appLinks.uriLinkStream.listen(_handleLink, onError: (_) {});
  }

  void _handleLink(Uri? uri) {
    if (uri == null) return;
    if (uri.scheme != 'unifyvpn' || uri.host != 'import') return;

    final liUrl = uri.queryParameters['li_url'] ?? '';
    final username = uri.queryParameters['username'] ?? '';
    final password = uri.queryParameters['password'] ?? '';

    if (liUrl.isEmpty) return;
    if (_controller == null || _controller!.loggedIn) return;

    if (username.isNotEmpty && password.isNotEmpty) {
      _controller!.login(
        liUrlInput: liUrl,
        usernameInput: username,
        password: password,
      );
    } else {
      _controller!.setPendingLiUrl(liUrl);
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _localeController.removeListener(_syncLocale);
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _dependencies?.dispose();
    _localeController.dispose();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  void _dismissTutorial() async {
    setState(() => _showTutorial = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_seen', true);
  }

  void _showAddService() {
    setState(() => _addingService = true);
  }

  /// 退出前手动释放关键资源，避免 destroy→exit 期间定时器/Stream 触发异常。
  void _cleanupBeforeExit() {
    _linkSub?.cancel();
    _linkSub = null;
    _controller?.dispose();
    _dependencies?.dispose();
  }

  @override
  void onWindowClose() async {
    final isConnected = _controller?.vpnStatus == VpnStatus.connected;
    if (!isConnected) {
      // 未连接时直接关闭
      await windowManager.setPreventClose(false);
      _cleanupBeforeExit();
      await windowManager.destroy();
      exit(0);
    }
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) {
      _cleanupBeforeExit();
      await windowManager.destroy();
      exit(0);
    }
    final s = AppStrings.of(ctx);
    final result = await showDialog<String>(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(s.closeWindowTitle)),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).pop('cancel'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: Text(s.closeWindowMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('exit'),
            child: Text(s.closeDisconnectAndExit),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('minimize'),
            child: Text(s.closeMinimizeToTray),
          ),
        ],
      ),
    );
    if (result == 'exit') {
      await _controller?.disconnect();
      _cleanupBeforeExit();
      await windowManager.destroy();
      exit(0);
    } else if (result == 'minimize') {
      await windowManager.minimize();
    }
    // 'cancel' 或 null：保持窗口不做处理
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _localeController,
      builder: (_, __) {
        final strings = AppStrings.forLocale(_localeController.appLocale);
        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: strings.appTitle,
          locale: _localeController.locale,
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF42A5F5),
              brightness: Brightness.dark,
              surface: const Color(0xFF0D1B2A),
              onSurface: const Color(0xFFE0E0E0),
            ),
            scaffoldBackgroundColor: const Color(0xFF0D1B2A),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0D1B2A),
              foregroundColor: Color(0xFFE0E0E0),
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF152238),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: const Color(0xFF0A1525),
              indicatorColor: const Color(0xFF1E88E5).withValues(alpha: 0.25),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: Color(0xFF42A5F5));
                }
                return const IconThemeData(color: Color(0xFF8899AA));
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                      color: Color(0xFF42A5F5), fontSize: 12);
                }
                return const TextStyle(
                    color: Color(0xFF8899AA), fontSize: 12);
              }),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF42A5F5),
                side: const BorderSide(color: Color(0xFF42A5F5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            dividerTheme: const DividerThemeData(
              color: Color(0xFF1E3048),
            ),
            listTileTheme: const ListTileThemeData(
              iconColor: Color(0xFF42A5F5),
              textColor: Color(0xFFE0E0E0),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF42A5F5);
                }
                return const Color(0xFF8899AA);
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF1E88E5).withValues(alpha: 0.4);
                }
                return const Color(0xFF1E3048);
              }),
            ),
            popupMenuTheme: PopupMenuThemeData(
              color: const Color(0xFF152238),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF152238),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF152238),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF152238),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1E3048)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1E3048)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF42A5F5)),
              ),
            ),
            useMaterial3: true,
          ),
          home: _controller == null
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()))
              : _buildHome(strings),
        );
      },
    );
  }

  /// 试用到期日（已解除限制）
  static final DateTime _trialExpiry = DateTime(2099, 12, 31, 23, 59, 59);

  bool get _isExpired => DateTime.now().isAfter(_trialExpiry);

  Widget _buildHome(AppStrings strings) {
    // ── 试用到期拦截 ──
    if (_isExpired) {
      return _TrialExpiredPage(expiry: _trialExpiry);
    }

    // 新手教程覆盖一切
    if (_showTutorial) {
      return _TutorialOverlay(
        step: _tutorialStep,
        onNext: () {
          if (_tutorialStep < 2) {
            setState(() => _tutorialStep++);
          } else {
            _dismissTutorial();
          }
        },
        onSkip: _dismissTutorial,
      );
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) {
        // 首次启动提示外部控制（登录前后都可触发）
        _maybeShowExternalControlDialog(context);

        // 未登录 → 添加服务引导页
        if (!_controller!.loggedIn) {
          return AddServicePage(
            controller: _controller!,
            onComplete: () => setState(() => _addingService = false),
          );
        }

        // 从连接页节点下拉触发"添加新服务"
        if (_addingService) {
          return AddServicePage(
            controller: _controller!,
            onComplete: () => setState(() => _addingService = false),
          );
        }

        // 登录后显示更新弹窗（一次性）
        _maybeShowUpdateDialog(context);

        final unreadCount = _controller!.messages.length;

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              ConnectPage(
                controller: _controller!,
                onAddService: _showAddService,
              ),
              FLinkPage(controller: _controller!),
              SettingsPage(
                controller: _controller!,
                localeController: _localeController,
                unreadMessages: unreadCount,
                onAddService: _showAddService,
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (v) => setState(() => _index = v),
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.vpn_lock),
                  label: strings.navConnect),
              NavigationDestination(
                  icon: const Icon(Icons.web_outlined),
                  label: strings.navFlink),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.settings),
                ),
                label: strings.navSettings,
              ),
            ],
          ),
        );
      },
    );
  }

  bool _updateDialogShown = false;

  void _maybeShowUpdateDialog(BuildContext context) {
    if (_updateDialogShown) return;
    final v = _controller!.latestVersion;
    if (v == null) return;
    _updateDialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: !v.isRequired,
        builder: (ctx) => _UpdateDialog(info: v),
      );
    });
  }

  void _maybeShowExternalControlDialog(BuildContext context) {
    if (!_showExternalControlPrompt) return;
    _showExternalControlPrompt = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final strings = AppStrings.of(context);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(strings.externalControl),
          content: Text(strings.externalControlPrompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () {
                _controller!.setExternalControlEnabled(true);
                Navigator.pop(ctx);
              },
              child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────
// 新手教程覆盖
// ─────────────────────────────────────────────────────────────────

class _TutorialOverlay extends StatelessWidget {
  const _TutorialOverlay({
    required this.step,
    required this.onNext,
    required this.onSkip,
  });
  final int step;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final titles = [s.tutorialStep1, s.tutorialStep2, s.tutorialStep3];
    final icons = [Icons.add_circle_outline, Icons.link, Icons.alt_route];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(icons[step], size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 32),
              Text(s.tutorialWelcome,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(titles[step],
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              // 进度指示
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Container(
                    width: i == step ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i == step
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  );
                }),
              ),
              const Spacer(flex: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: onSkip, child: Text(s.tutorialSkip)),
                  FilledButton(
                    onPressed: onNext,
                    child:
                        Text(step < 2 ? s.tutorialNext : s.tutorialDone),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// 更新弹窗
// ─────────────────────────────────────────────────────────────────

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.info});
  final VersionInfo info;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update, color: Colors.orange),
          const SizedBox(width: 8),
          Text(s.updateDialogTitle),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.updateDialogContent
              .replaceAll('{version}', info.version)),
          if (info.description != null && info.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(info.description!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (info.isRequired) ...[
            const SizedBox(height: 8),
            Text(s.updateDialogRequired,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold)),
          ],
        ],
      ),
      actions: [
        if (!info.isRequired)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.updateDialogLater),
          ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _launchUpdate(context);
          },
          child: Text(s.updateDialogDownload),
        ),
      ],
    );
  }

  Future<void> _launchUpdate(BuildContext context) async {
    final uri = Uri.tryParse(info.downloadUrl);
    if (uri == null) return;
    // 使用 url_launcher
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// 试用到期页面
// ─────────────────────────────────────────────────────────────────

class _TrialExpiredPage extends StatelessWidget {
  const _TrialExpiredPage({required this.expiry});
  final DateTime expiry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock,
                  size: 80, color: theme.colorScheme.error),
              const SizedBox(height: 24),
              Text(
                '试用期已结束',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '本测试版本已于 $dateStr 到期，无法继续使用。\n请联系开发方获取新版本。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app),
                label: const Text('退出应用'),
                onPressed: () => SystemNavigator.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
