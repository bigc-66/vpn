import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/state/app_controller.dart';

/// 首次启动 / 添加新服务的引导页面。
/// 流程：输入服务地址、用户账号、用户密码 → 点击"添加" → 验证中 → 成功跳转/失败报错。
class AddServicePage extends StatefulWidget {
  const AddServicePage({
    super.key,
    required this.controller,
    this.onComplete,
  });

  final AppController controller;
  final VoidCallback? onComplete;

  @override
  State<AddServicePage> createState() => _AddServicePageState();
}

enum _WizardStep { inputForm, verifying, done, error }

class _AddServicePageState extends State<AddServicePage> {
  final _liUrlCtl = TextEditingController();
  final _userCtl = TextEditingController();
  final _pwdCtl = TextEditingController();
  bool _obscurePwd = true;
  _WizardStep _step = _WizardStep.inputForm;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _applyPendingLiUrl();
  }

  void _onControllerChanged() => _applyPendingLiUrl();

  void _applyPendingLiUrl() {
    final pending = widget.controller.pendingLiUrl;
    if (pending.isNotEmpty && _liUrlCtl.text.isEmpty) {
      _liUrlCtl.text = pending;
      _autoFillForUrl(pending);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _liUrlCtl.dispose();
    _userCtl.dispose();
    _pwdCtl.dispose();
    super.dispose();
  }

  bool get _isBusy => _step == _WizardStep.verifying;

  /// 根据 URL 自动填充已保存的用户名和密码。
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

  /// 提交：验证服务地址 → 验证用户名密码 → 完成
  Future<void> _submit() async {
    final s = AppStrings.of(context);
    if (_liUrlCtl.text.trim().isEmpty ||
        _userCtl.text.trim().isEmpty ||
        _pwdCtl.text.isEmpty) {
      setState(() {
        _error = s.errFieldEmpty;
        _step = _WizardStep.error;
      });
      return;
    }
    setState(() {
      _step = _WizardStep.verifying;
      _error = null;
    });

    // Step 1: 验证服务地址
    final addrErr = await widget.controller.resolveServiceAddress(_liUrlCtl.text.trim());
    if (!mounted) return;
    if (addrErr != null) {
      setState(() {
        _step = _WizardStep.error;
        _error = addrErr;
      });
      return;
    }

    // Step 2: 验证用户名密码
    widget.controller.lastError = null;
    await widget.controller.login(
      liUrlInput: _liUrlCtl.text.trim(),
      usernameInput: _userCtl.text.trim(),
      password: _pwdCtl.text,
    );
    if (!mounted) return;

    if (widget.controller.loggedIn) {
      setState(() => _step = _WizardStep.done);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      widget.onComplete?.call();
    } else {
      setState(() {
        _step = _WizardStep.error;
        _error = widget.controller.lastError ?? s.errCredentialsWrong;
      });
    }
  }

  void _backToForm() {
    setState(() {
      _step = _WizardStep.inputForm;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    // 验证中页面
    if (_step == _WizardStep.verifying) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(s.addServiceVerifying),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text(s.addServiceVerifyingDesc,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    // 错误页面
    if (_step == _WizardStep.error) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _backToForm),
          title: Text(s.addServiceTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(_error ?? s.errLoginFailed,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _backToForm,
                  child: Text(s.retryLabel),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 输入表单页面（首页 / 主页面）
    return Scaffold(
      appBar: AppBar(
        leading: widget.controller.loggedIn
            ? BackButton(onPressed: () => widget.onComplete?.call())
            : null,
        automaticallyImplyLeading: false,
        title: Text(s.addServiceWelcome),
        actions: [
          TextButton(
            onPressed: _isBusy ? null : _submit,
            child: Text(s.addServiceButton),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Icon(Icons.vpn_lock_rounded,
                        size: 64, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.addServiceDescription,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // 服务地址
                  TextField(
                    controller: _liUrlCtl,
                    decoration: InputDecoration(
                      labelText: s.addServiceAddress,
                      hintText: s.addStep1Hint,
                      prefixIcon: const Icon(Icons.dns_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 14),

                  // 用户账号
                  TextField(
                    controller: _userCtl,
                    decoration: InputDecoration(
                      labelText: s.addServiceUsername,
                      hintText: s.addStep2HintUser,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 用户密码
                  TextField(
                    controller: _pwdCtl,
                    obscureText: _obscurePwd,
                    decoration: InputDecoration(
                      labelText: s.addServicePassword,
                      hintText: s.addStep2HintPwd,
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
                  const SizedBox(height: 32),

                  // 添加按钮
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _submit,
                      child: Text(s.addServiceButton),
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
