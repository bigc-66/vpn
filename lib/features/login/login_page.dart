import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/state/app_controller.dart';

enum _LoginStage { idle, resolvingServer, authenticating, downloadingConfig, done, error }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _liUrlCtl = TextEditingController();
  final TextEditingController _userCtl = TextEditingController();
  final TextEditingController _pwdCtl = TextEditingController();
  bool _obscurePwd = true;
  _LoginStage _stage = _LoginStage.idle;
  String? _stageError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _applyPendingLiUrl();
    _autoFillSavedCredentials();
  }

  void _onControllerChanged() => _applyPendingLiUrl();

  void _applyPendingLiUrl() {
    final pending = widget.controller.pendingLiUrl;
    if (pending.isNotEmpty && _liUrlCtl.text.isEmpty) {
      _liUrlCtl.text = pending;
      // 如果地址预填后有匹配的已保存服务，自动填充用户名和密码
      _autoFillForUrl(pending);
    }
  }

  /// 自动从已保存服务中填充用户名和密码。
  Future<void> _autoFillSavedCredentials() async {
    // 如果 controller 带有 liUrl（从切换服务回退到登录页），优先使用
    final url = widget.controller.liUrl.isNotEmpty
        ? widget.controller.liUrl
        : _liUrlCtl.text.trim();
    if (url.isEmpty) {
      // 无预填地址时，使用最近活跃的服务
      final active = widget.controller.services
          .where((s) => s.isActive)
          .toList();
      if (active.isNotEmpty) {
        final svc = active.first;
        if (_liUrlCtl.text.isEmpty) _liUrlCtl.text = svc.liUrl;
        if (_userCtl.text.isEmpty) _userCtl.text = svc.username;
        final pwd = await widget.controller.getSavedPassword(svc.id);
        if (pwd != null && pwd.isNotEmpty && _pwdCtl.text.isEmpty) {
          _pwdCtl.text = pwd;
        }
        if (mounted) setState(() {});
      }
      return;
    }
    await _autoFillForUrl(url);
  }

  Future<void> _autoFillForUrl(String url) async {
    final svc = widget.controller.findServiceByUrl(url);
    if (svc == null) return;
    if (_userCtl.text.isEmpty) _userCtl.text = svc.username;
    final pwd = await widget.controller.getSavedPassword(svc.id);
    if (pwd != null && pwd.isNotEmpty && _pwdCtl.text.isEmpty) {
      _pwdCtl.text = pwd;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _liUrlCtl.dispose();
    _userCtl.dispose();
    _pwdCtl.dispose();
    super.dispose();
  }

  int get _stepIndex => switch (_stage) {
        _LoginStage.idle => 0,
        _LoginStage.resolvingServer => 0,
        _LoginStage.authenticating => 1,
        _LoginStage.downloadingConfig => 2,
        _LoginStage.done => 3,
        _LoginStage.error => -1,
      };

  Future<void> _startLogin() async {
    final s = AppStrings.of(context);
    if (_liUrlCtl.text.trim().isEmpty ||
        _userCtl.text.trim().isEmpty ||
        _pwdCtl.text.isEmpty) {
      setState(() {
        _stageError = s.errFieldEmpty;
        _stage = _LoginStage.error;
      });
      return;
    }

    setState(() {
      _stage = _LoginStage.resolvingServer;
      _stageError = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _stage = _LoginStage.authenticating);

    widget.controller.lastError = null;
    await widget.controller.login(
      liUrlInput: _liUrlCtl.text.trim(),
      usernameInput: _userCtl.text.trim(),
      password: _pwdCtl.text,
    );

    if (!mounted) return;

    if (widget.controller.loggedIn) {
      setState(() => _stage = _LoginStage.downloadingConfig);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _stage = _LoginStage.done);
    } else {
      setState(() {
        _stage = _LoginStage.error;
        _stageError = widget.controller.lastError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final inProgress = _stage != _LoginStage.idle &&
        _stage != _LoginStage.done &&
        _stage != _LoginStage.error;

    return Scaffold(
      appBar: AppBar(title: Text(strings.loginAppTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 阶段指示器
                  if (_stage != _LoginStage.idle) ...[
                    _LoginStepIndicator(
                      currentStep: _stepIndex,
                      isError: _stage == _LoginStage.error,
                      labels: [
                        strings.verifyStepServer,
                        strings.verifyStepAuth,
                        strings.verifyStepConfig,
                        strings.verifyStepDone,
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (inProgress)
                      Text(
                        switch (_stage) {
                          _LoginStage.resolvingServer => strings.verifyResolving,
                          _LoginStage.authenticating => strings.verifyAuthenticating,
                          _LoginStage.downloadingConfig => strings.verifyDownloading,
                          _ => '',
                        },
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    if (_stage == _LoginStage.done)
                      Text(strings.verifySuccess,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.green)),
                    if (_stageError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_stageError!,
                            style: TextStyle(
                                color: theme.colorScheme.error, fontSize: 13),
                            textAlign: TextAlign.center),
                      ),
                    const SizedBox(height: 20),
                  ],

                  TextField(
                    controller: _liUrlCtl,
                    enabled: !inProgress,
                    decoration: InputDecoration(
                      labelText: strings.loginLiUrl,
                      hintText: strings.loginLiHint,
                      prefixIcon: const Icon(Icons.dns_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _userCtl,
                    enabled: !inProgress,
                    decoration: InputDecoration(
                      labelText: strings.loginUsername,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pwdCtl,
                    enabled: !inProgress,
                    obscureText: _obscurePwd,
                    decoration: InputDecoration(
                      labelText: strings.loginPassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePwd
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePwd = !_obscurePwd),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: inProgress || _stage == _LoginStage.done
                          ? null
                          : _startLogin,
                      child: inProgress
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _stage == _LoginStage.error
                                  ? strings.retryLabel
                                  : strings.loginButton,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 线性阶段指示器
class _LoginStepIndicator extends StatelessWidget {
  const _LoginStepIndicator({
    required this.currentStep,
    required this.labels,
    this.isError = false,
  });
  final int currentStep;
  final List<String> labels;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIdx = i ~/ 2;
          final active = stepIdx < currentStep;
          return Expanded(
            child: Container(
                height: 2,
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant),
          );
        }
        final stepIdx = i ~/ 2;
        final completed = stepIdx < currentStep;
        final current = stepIdx == currentStep && !isError;
        final errored = stepIdx == currentStep && isError;

        final Color circleColor;
        final Widget child;
        if (completed) {
          circleColor = theme.colorScheme.primary;
          child = const Icon(Icons.check, size: 14, color: Colors.white);
        } else if (errored) {
          circleColor = theme.colorScheme.error;
          child = const Icon(Icons.close, size: 14, color: Colors.white);
        } else if (current) {
          circleColor = theme.colorScheme.primary;
          child = SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: theme.colorScheme.onPrimary));
        } else {
          circleColor = theme.colorScheme.outlineVariant;
          child = Text('${stepIdx + 1}',
              style: const TextStyle(fontSize: 11, color: Colors.white));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: circleColor),
              alignment: Alignment.center,
              child: child,
            ),
            const SizedBox(height: 4),
            Text(labels[stepIdx],
                style: theme.textTheme.labelSmall?.copyWith(
                    color: completed || current
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant)),
          ],
        );
      }),
    );
  }
}
