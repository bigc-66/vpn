/// 应用文本资源 —— 中英双语。
/// 通过 [AppStrings.of(context)] 获取当前语言的字符串集。
library;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────
// 语言枚举
// ─────────────────────────────────────────────────────────────────

enum AppLocale { zh, en }

extension AppLocaleLabel on AppLocale {
  String get displayName => switch (this) {
        AppLocale.zh => '中文',
        AppLocale.en => 'English',
      };

  Locale get locale => switch (this) {
        AppLocale.zh => const Locale('zh'),
        AppLocale.en => const Locale('en'),
      };
}

// ─────────────────────────────────────────────────────────────────
// 字符串表
// ─────────────────────────────────────────────────────────────────

class AppStrings {
  const AppStrings._({required this.locale, required Map<String, String> map})
      : _map = map;

  final AppLocale locale;
  final Map<String, String> _map;

  String operator [](String key) => _map[key] ?? key;

  // ── 便捷取值 ───────────────────────────────────────────────────

  // 通用
  String get appTitle => this['app_title'];
  String get ok => this['ok'];
  String get cancel => this['cancel'];
  String get confirm => this['confirm'];
  String get retryLabel => this['retry'];
  String get loading => this['loading'];
  String get errorPrefix => this['error_prefix'];

  // 导航
  String get navConnect => this['nav_connect'];
  String get navFlink => this['nav_flink'];
  String get navMessages => this['nav_messages'];
  String get navSettings => this['nav_settings'];

  // 登录页
  String get loginTitle => this['login_title'];
  String get loginLiUrl => this['login_li_url'];
  String get loginUsername => this['login_username'];
  String get loginPassword => this['login_password'];
  String get loginButton => this['login_button'];
  String get loginBusy => this['login_busy'];

  // 连接页
  String get connectTitle => this['connect_title'];
  String get connectButtonConnect => this['connect_btn_connect'];
  String get connectButtonDisconnect => this['connect_btn_disconnect'];
  String get connectSelectNode => this['connect_select_node'];
  String get connectSelectProtocol => this['connect_select_protocol'];
  String get connectDownloadingRoute => this['connect_downloading_route'];
  String get connectStatusIdle => this['connect_status_idle'];

  // 消息页
  String get messagesTitle => this['messages_title'];
  String get messagesEmpty => this['messages_empty'];

  // 设置页
  String get settingsTitle => this['settings_title'];
  String get settingsCustomService => this['settings_custom_service'];
  String get settingsSplitRouting => this['settings_split_routing'];
  String get settingsSplitRoutingRules => this['settings_split_routing_rules'];
  String get settingsServiceCount => this['settings_service_count'];
  String get settingsDns => this['settings_dns'];
  String get settingsRouteCount => this['settings_route_count'];
  String get settingsVpnStatus => this['settings_vpn_status'];
  String get settingsSessionId => this['settings_session_id'];
  String get settingsCurrentNode => this['settings_current_node'];
  String get settingsCheckUpdate => this['settings_check_update'];
  String get settingsNewVersion => this['settings_new_version'];
  String get settingsUpToDate => this['settings_up_to_date'];
  String get settingsRunMode => this['settings_run_mode'];
  String get settingsLanguage => this['settings_language'];
  String get settingsLogUpload => this['settings_log_upload'];
  String get settingsLogUploading => this['settings_log_uploading'];
  String get settingsLogUploadSuccess => this['settings_log_upload_success'];
  String get settingsLogUploadFail => this['settings_log_upload_fail'];
  String get settingsAccount => this['settings_account'];
  String get settingsLogout => this['settings_logout'];

  // 分流页
  String get splitTitle => this['split_title'];
  String get splitHint => this['split_hint'];
  String get splitAdd => this['split_add'];
  String get splitEmpty => this['split_empty'];

  // 区域标题
  String get sectionExtendedService => this['section_extended_service'];
  String get sectionNetwork => this['section_network'];
  String get sectionConnectionStatus => this['section_connection_status'];
  String get sectionAbout => this['section_about'];
  String get sectionAccount => this['section_account'];

  // 消息页
  String get messagesOpen => this['messages_open'];
  String get messagesCannotOpen => this['messages_cannot_open'];

  // 连接页补充
  String get connectUser => this['connect_user'];
  String get connectSubscription => this['connect_subscription'];
  String get connectExpiry => this['connect_expiry'];
  String get connectAuto => this['connect_auto'];
  String get connectLogout => this['connect_logout'];

  // 登录页补充
  String get loginAppTitle => this['login_app_title'];
  String get loginLiHint => this['login_li_hint'];

  // 设置页补充
  String get settingsRouteUnit => this['settings_route_unit'];
  String get settingsCannotOpen => this['settings_cannot_open'];
  String get settingsLogoutConfirm => this['settings_logout_confirm'];

  // 分流页补充
  String get splitDescription => this['split_description'];
  String get splitModeTunnel => this['split_mode_tunnel'];
  String get splitModeBypass => this['split_mode_bypass'];

  // 分流三级页面
  String get aboutLocalSplit => this['about_local_split'];
  String get aboutLocalSplitDesc => this['about_local_split_desc'];
  String get customRouteList => this['custom_route_list'];
  String get aboutCustomSplit => this['about_custom_split'];
  String get aboutCustomSplitDesc => this['about_custom_split_desc'];
  String get addCustomRoute => this['add_custom_route'];
  String get aboutAddRoute => this['about_add_route'];
  String get aboutAddRouteDesc => this['about_add_route_desc'];
  String get splitRouteName => this['split_route_name'];
  String get splitRouteNameHint => this['split_route_name_hint'];
  String get splitIpLabel => this['split_ip_label'];
  String get splitDelete => this['split_delete'];
  String get aboutCollapse => this['about_collapse'];
  String get aboutExpand => this['about_expand'];

  // VPN 状态标签
  String get statusDisconnected => this['status_disconnected'];
  String get statusConnecting => this['status_connecting'];
  String get statusConnected => this['status_connected'];
  String get statusDisconnecting => this['status_disconnecting'];
  String get statusError => this['status_error'];

  // 测速
  String get speedTestTitle => this['speed_test_title'];
  String get speedTestStart => this['speed_test_start'];
  String get speedTestPing => this['speed_test_ping'];
  String get speedTestDownload => this['speed_test_download'];
  String get speedTestUpload => this['speed_test_upload'];
  String get speedTestTesting => this['speed_test_testing'];

  // 添加服务页
  String get addServiceTitle => this['add_service_title'];
  String get addServiceHint => this['add_service_hint'];
  String get addServiceDescription => this['add_service_description'];
  String get addServiceButton => this['add_service_button'];
  String get addServiceWelcome => this['add_service_welcome'];
  String get addNewService => this['add_new_service'];
  String get addServiceVerifying => this['add_service_verifying'];
  String get addServiceVerifyingDesc => this['add_service_verifying_desc'];
  String get addServiceAddress => this['add_service_address'];
  String get addServiceUsername => this['add_service_username'];
  String get addServicePassword => this['add_service_password'];

  // 验证阶段
  String get verifyStepServer => this['verify_step_server'];
  String get verifyStepAuth => this['verify_step_auth'];
  String get verifyStepConfig => this['verify_step_config'];
  String get verifyStepDone => this['verify_step_done'];
  String get verifyResolving => this['verify_resolving'];
  String get verifyAuthenticating => this['verify_authenticating'];
  String get verifyDownloading => this['verify_downloading'];
  String get verifySuccess => this['verify_success'];

  // 站点/节点下拉
  String get siteDropdownLabel => this['site_dropdown_label'];
  String get nodeDropdownLabel => this['node_dropdown_label'];
  String get protocolLabel => this['protocol_label'];

  // 服务 web 页
  String get serviceWebTitle => this['service_web_title'];
  String get serviceWebLoading => this['service_web_loading'];
  String get serviceWebError => this['service_web_error'];

  // 路由表
  String get routeTableTitle => this['route_table_title'];
  String get routeTableServer => this['route_table_server'];
  String get routeTableCustom => this['route_table_custom'];
  String get routeTableEmpty => this['route_table_empty'];

  // 更新弹窗
  String get updateDialogTitle => this['update_dialog_title'];
  String get updateDialogContent => this['update_dialog_content'];
  String get updateDialogDownload => this['update_dialog_download'];
  String get updateDialogLater => this['update_dialog_later'];
  String get updateDialogRequired => this['update_dialog_required'];

  // 新手教程
  String get tutorialWelcome => this['tutorial_welcome'];
  String get tutorialStep1 => this['tutorial_step1'];
  String get tutorialStep2 => this['tutorial_step2'];
  String get tutorialStep3 => this['tutorial_step3'];
  String get tutorialDone => this['tutorial_done'];
  String get tutorialSkip => this['tutorial_skip'];
  String get tutorialNext => this['tutorial_next'];

  // 导航（扩展）
  String get navService => this['nav_service'];

  // 两步添加服务
  String get addStep1Title => this['add_step1_title'];
  String get addStep1Hint => this['add_step1_hint'];
  String get addStep1Button => this['add_step1_button'];
  String get addStep2Title => this['add_step2_title'];
  String get addStep2HintUser => this['add_step2_hint_user'];
  String get addStep2HintPwd => this['add_step2_hint_pwd'];
  String get addStep2Button => this['add_step2_button'];
  String get addStepVerifyingAddr => this['add_step_verifying_addr'];
  String get addStepVerifyingCred => this['add_step_verifying_cred'];
  String get addStepDone => this['add_step_done'];
  String get errServiceNotFound => this['err_service_not_found'];
  String get errServiceDisabled => this['err_service_disabled'];
  String get errCredentialsWrong => this['err_credentials_wrong'];
  String get errNetworkUnavailable => this['err_network_unavailable'];

  // 多服务管理
  String get myServices => this['my_services'];
  String get serviceManagement => this['service_management'];
  String get deleteService => this['delete_service'];
  String get modifyUserInfo => this['modify_user_info'];
  String get switchService => this['switch_service'];
  String get defaultNode => this['default_node'];
  String get addServiceEntry => this['add_service_entry'];
  String get serverAddress => this['server_address'];
  String get noServices => this['no_services'];
  String get deleteServiceConfirm => this['delete_service_confirm'];
  String get statusSelected => this['status_selected'];

  // 分流开关
  String get splitToggle => this['split_toggle'];
  String get splitToggleDesc => this['split_toggle_desc'];

  // 外部控制
  String get externalControl => this['external_control'];
  String get externalControlDesc => this['external_control_desc'];
  String get externalControlPrompt => this['external_control_prompt'];

  // 关于 F-Link
  String get aboutFlink => this['about_flink'];
  String get aboutFlinkDesc => this['about_flink_desc'];
  String get aboutFlinkTeam => this['about_flink_team'];
  String get visitFlinkWebsite => this['visit_flink_website'];

  // 日志管理
  String get logSelectService => this['log_select_service'];
  String get logSelectHint => this['log_select_hint'];
  String get logClear => this['log_clear'];
  String get logClearConfirm => this['log_clear_confirm'];
  String get logCleared => this['log_cleared'];

  // 用户行
  String get userLabel => this['user_label'];
  String get changeUser => this['change_user'];

  // 快速服务
  String get quickService => this['quick_service'];

  // 服务公告
  String get serviceAnnouncement => this['service_announcement'];
  String get customerTips => this['customer_tips'];
  String get claimBenefits => this['claim_benefits'];

  // 新增字段 URL
  String get fLinkWebPage => this['f_link_web_page'];
  String get serviceWebEntry => this['service_web_entry'];

  // 关于邮箱
  String get aboutFlinkEmail => this['about_flink_email'];
  String get aboutFlinkContact => this['about_flink_contact'];

  // 日志管理页
  String get logManagement => this['log_management'];
  String get logManagementDesc => this['log_management_desc'];
  String get logViewTitle => this['log_view_title'];
  String get logUploadAbout => this['log_upload_about'];
  String get logUploadAboutDesc => this['log_upload_about_desc'];
  String get logEmpty => this['log_empty'];

  // 服务管理（设置中）
  String get sectionServiceManagement => this['section_service_management'];
  String get messagesSection => this['messages_section'];

  // 连接页
  String get connectModeSelect => this['connect_mode_select'];
  String get localSplitRouting => this['local_split_routing'];

  // 关闭窗口提示
  String get closeWindowTitle => this['close_window_title'];
  String get closeWindowMessage => this['close_window_message'];
  String get closeDisconnectAndExit => this['close_disconnect_and_exit'];
  String get closeMinimizeToTray => this['close_minimize_to_tray'];

  // 错误文案
  String get errFieldEmpty => this['err_field_empty'];
  String get errLoginFailed => this['err_login_failed'];
  String get errConnectFailed => this['err_connect_failed'];
  String get errNoNode => this['err_no_node'];
  String get errKeyBlocked => this['err_key_blocked'];
  String get errHeartbeatReconnect => this['err_heartbeat_reconnect'];
  String get errForceDisconnect => this['err_force_disconnect'];
  String get errComplianceFailed => this['err_compliance_failed'];
  String get errComplianceUnreachable => this['err_compliance_unreachable'];
  String get errSplitInvalid => this['err_split_invalid'];
  String get errSplitDuplicate => this['err_split_duplicate'];

  // ── 工厂 ──────────────────────────────────────────────────────

  static AppStrings of(BuildContext context) {
    Locale locale;
    try {
      locale = Localizations.localeOf(context);
    } catch (_) {
      return _zh;
    }
    return forLocale(
        locale.languageCode.startsWith('zh') ? AppLocale.zh : AppLocale.en);
  }

  static AppStrings forLocale(AppLocale locale) => switch (locale) {
        AppLocale.zh => _zh,
        AppLocale.en => _en,
      };

  // ──────────────────────────────────────────────────────────────
  // 中文
  // ──────────────────────────────────────────────────────────────

  static const _zh = AppStrings._(locale: AppLocale.zh, map: {
    'app_title': 'Netsignory client',
    'ok': '确定',
    'cancel': '取消',
    'confirm': '确认',
    'retry': '重试',
    'loading': '加载中...',
    'error_prefix': '错误',

    'nav_connect': '连接',
    'nav_flink': 'Netsignory',
    'nav_messages': '消息',
    'nav_settings': '设置',

    'login_title': '登录',
    'login_li_url': '服务地址',
    'login_username': '用户名',
    'login_password': '密码',
    'login_button': '登录',
    'login_busy': '登录中...',

    'connect_title': 'SD-WAN 连接',
    'connect_btn_connect': '立即连接',
    'connect_btn_disconnect': '断开连接',
    'connect_select_node': '选择节点',
    'connect_select_protocol': '选择协议',
    'connect_downloading_route': '正在下载路由表',
    'connect_status_idle': '未连接',

    'messages_title': '推送消息',
    'messages_empty': '暂无消息',

    'settings_title': '设置',
    'settings_custom_service': '自定义服务',
    'settings_split_routing': '自定义分流',
    'settings_split_routing_rules': '条规则',
    'settings_service_count': '个服务',
    'settings_dns': 'DNS 服务器',
    'settings_route_count': '路由条目数',
    'settings_vpn_status': 'VPN 状态',
    'settings_session_id': '会话 ID',
    'settings_current_node': '当前节点',
    'settings_check_update': '检查更新',
    'settings_new_version': '发现新版本',
    'settings_up_to_date': '当前已是最新版本',
    'settings_run_mode': '运行模式',
    'settings_language': '语言',
    'settings_log_upload': '上传日志',
    'settings_log_uploading': '上传中...',
    'settings_log_upload_success': '日志上传成功',
    'settings_log_upload_fail': '日志上传失败',
    'settings_account': '账号',
    'settings_logout': '退出登录',

    'split_title': '自定义分流',
    'split_hint': '192.168.1.0  或  10.0.0.*',
    'split_add': '添加',
    'split_empty': '暂无分流规则',

    'section_extended_service': '扩展服务',
    'section_network': '网络',
    'section_connection_status': '连接状态',
    'section_about': '关于',
    'section_account': '账号',

    'messages_open': '打开',
    'messages_cannot_open': '无法打开链接',

    'connect_user': '用户',
    'connect_subscription': '订阅',
    'connect_expiry': '到期',
    'connect_auto': '自动',
    'connect_logout': '退出',

    'login_app_title': 'Netsignory client',
    'login_li_hint': 'example.sdwan.com',

    'settings_route_unit': '条',
    'settings_cannot_open': '无法打开',
    'settings_logout_confirm': '确定要退出登录吗？',

    'split_description': '添加自定义分流规则，控制特定目标走 VPN 或直连。\n录入格式：单 IP (x.x.x.x)、C 段 (x.x.x.*)、域名 (example.com)。\n绕行：不走 VPN 直连 | 隧道：强制走 VPN',
    'split_mode_tunnel': '走通道',
    'split_mode_bypass': '不走通道',

    // 分流三级页面
    'about_local_split': '关于本地分流',
    'about_local_split_desc': '您可以选择或指定您的某些访问目标是否通过服务进行中转，如不通过服务，则这些访问请求会通过您设备的本地网络发出。',
    'custom_route_list': '自定义分流列表',
    'about_custom_split': '关于自定义分流',
    'about_custom_split_desc': '当您设置自定义分流时，不论是否开启分流开关，您指定的访问目标都会通过设备本地网络发出。',
    'add_custom_route': '添加自定义分流',
    'about_add_route': '关于添加分流',
    'about_add_route_desc': '您可以输入完整的 IP 地址，或在最后一个 IP 地址段输入 *（包含 0–255），设定通过设备本地网络访问此段 IP 地址。',
    'split_route_name': '名称（可选）',
    'split_route_name_hint': '如：公司内网',
    'split_ip_label': 'IP 地址',
    'split_delete': '删除',
    'about_collapse': '收起',
    'about_expand': '展开',

    'status_disconnected': '未连接',
    'status_connecting': '连接中',
    'status_connected': '已连接',
    'status_disconnecting': '断开中',
    'status_error': '异常',

    'err_field_empty': '服务地址、用户名、密码不能为空',
    'err_login_failed': '登录失败',
    'err_connect_failed': '连接失败',
    'err_no_node': '请先选择接入节点',
    'err_key_blocked': '该 Li 的密钥已被标记为不合规，拒绝连接',
    'err_heartbeat_reconnect': '心跳连续失败，正在尝试重连',
    'err_force_disconnect': '服务端要求断开连接',
    'err_compliance_failed': 'Netsignory 密钥验证失败，连接已断开',
    'err_compliance_unreachable': '无法验证密钥合规性，连接已断开',
    'err_split_invalid': '格式无效，请输入 x.x.x.x 或 x.x.x.*',
    'err_split_duplicate': '已存在相同规则',

    'speed_test_title': '网络测速',
    'speed_test_start': '开始测速',
    'speed_test_ping': '延迟',
    'speed_test_download': '下载',
    'speed_test_upload': '上传',
    'speed_test_testing': '测试中...',

    'add_service_title': '添加服务',
    'add_service_hint': '请输入服务地址',
    'add_service_description': '输入服务地址开始添加 SD-WAN 服务，完成验证后即可使用。',
    'add_service_button': '添加',
    'add_service_welcome': '添加 Netsignory 网域服务',
    'add_service_verifying': '正在验证服务信息',
    'add_service_verifying_desc': '请稍候，正在验证您输入的服务信息...',
    'add_service_address': '服务地址',
    'add_service_username': '用户账号',
    'add_service_password': '用户密码',
    'add_new_service': '添加新服务',

    'verify_step_server': '验证服务器',
    'verify_step_auth': '用户认证',
    'verify_step_config': '下载配置',
    'verify_step_done': '完成',
    'verify_resolving': '正在验证服务器信息...',
    'verify_authenticating': '正在进行用户认证...',
    'verify_downloading': '正在下载网络配置...',
    'verify_success': '服务添加成功！',

    'site_dropdown_label': '服务地址',
    'node_dropdown_label': '选择接入节点',
    'protocol_label': '连接协议',

    'service_web_title': '服务信息',
    'service_web_loading': '加载中...',
    'service_web_error': '页面加载失败',

    'route_table_title': '路由表',
    'route_table_server': '服务端下发',
    'route_table_custom': '自定义分流',
    'route_table_empty': '暂无路由条目',

    'update_dialog_title': '发现新版本',
    'update_dialog_content': '版本 {version} 已发布',
    'update_dialog_download': '立即更新',
    'update_dialog_later': '稍后再说',
    'update_dialog_required': '此更新为必要更新，请立即安装。',

    'tutorial_welcome': '欢迎使用 Netsignory 网域',
    'tutorial_step1': '第一步：添加一个 Netsignory 网域服务，输入服务器地址进行验证。',
    'tutorial_step2': '第二步：选择节点和协议，一键连接。',
    'tutorial_step3': '第三步：查看消息推送，管理自定义分流。',
    'tutorial_done': '开始使用',
    'tutorial_skip': '跳过',
    'tutorial_next': '下一步',

    'nav_service': '服务',

    // 两步添加服务
    'add_step1_title': '输入服务地址',
    'add_step1_hint': '请输入 Netsignory 网域服务地址',
    'add_step1_button': '验证服务地址',
    'add_step2_title': '输入用户密码',
    'add_step2_hint_user': '请输入用户名',
    'add_step2_hint_pwd': '请输入密码',
    'add_step2_button': '验证用户名密码',
    'add_step_verifying_addr': '正在验证服务地址...',
    'add_step_verifying_cred': '正在验证用户名密码...',
    'add_step_done': '服务已添加',
    'err_service_not_found': '服务地址不存在，请再次检查您输入的服务信息是否正确',
    'err_service_disabled': '目标服务已经被禁用',
    'err_credentials_wrong': '用户名密码错误',
    'err_network_unavailable': '当前设备网络不可用',

    // 多服务管理
    'my_services': '我的服务',
    'service_management': '服务管理',
    'delete_service': '删除服务',
    'modify_user_info': '修改用户信息',
    'switch_service': '切换为默认',
    'default_node': '默认节点',
    'add_service_entry': '添加服务',
    'server_address': '服务器地址',
    'no_services': '暂无服务，请先添加',
    'delete_service_confirm': '确定要删除此服务吗？',
    'status_selected': '当前默认',

    // 分流开关
    'split_toggle': '分流开关',
    'split_toggle_desc': '关闭后所有访问通过服务',

    // 外部控制
    'external_control': '客户端外部控制',
    'external_control_desc': '允许外部调起本 App',
    'external_control_prompt': '开启外部控制后，您可以通过扫码等方式，快速添加服务而无需手动输入信息，是否开启？',

    // 关于 Netsignory 网域
    'about_flink': '关于 Netsignory 网域',
    'about_flink_desc': 'Netsignory 网域，是一个基于 SSL VPN 模式的 SD-WAN 接入系统。Netsignory 网域定义为免费接入工具，提供 UI 接口、User 接口、WEB 拓展服务接口和建立方式。面向各类专用网络服务商提供第三方客户端服务。客户端自身不提供任何专用网络（VPN）服务。',
    'about_flink_team': 'Netsignory 网域 团队敬上',
    'visit_flink_website': '访问 Netsignory 网域官网',
    'about_flink_email': 'f-link@gmail.com',
    'about_flink_contact': '与我们联络',

    // 日志管理
    'log_select_service': '选择需要上传的服务商',
    'log_select_hint': '如果您使用了多个服务，您可以选择需要上传的服务商',
    'log_clear': '清空日志',
    'log_clear_confirm': '确定要清空日志吗？',
    'log_cleared': '日志已清空',
    'log_management': '日志管理',
    'log_management_desc': '查看、上传或清空日志',
    'log_view_title': '查看日志内容',
    'log_upload_about': '关于上传日志的说明',
    'log_upload_about_desc': '如果您在服务使用过程中产生问题或故障，您可以根据服务上的要求，将日志上传至服务商以便于其解决您的问题。\n\n如果您使用了多个服务，您可以选择需要上传的服务商，与此服务商无关的日志将不被上传。',
    'log_empty': '暂无日志',

    // 用户行
    'user_label': '用户',
    'change_user': '更换',

    // 快速服务
    'quick_service': '快速服务',

    // 服务公告
    'service_announcement': '服务公告',
    'customer_tips': '客户提示',
    'claim_benefits': '领取客户福利',

    // 新增字段 URL
    'f_link_web_page': 'Netsignory 服务页面',
    'service_web_entry': '服务页面',

    // 服务管理
    'section_service_management': '服务管理',
    'messages_section': '消息通知',

    // 连接页
    'connect_mode_select': '连接模式选择',
    'local_split_routing': '本地分流',

    // 关闭窗口提示
    'close_window_title': '当前处于连接状态',
    'close_window_message': '您当前已经连接服务，请选择操作：',
    'close_disconnect_and_exit': '断开连接并关闭软件',
    'close_minimize_to_tray': '保持连接并最小化窗口',
  });

  // ──────────────────────────────────────────────────────────────
  // 英文
  // ──────────────────────────────────────────────────────────────

  static const _en = AppStrings._(locale: AppLocale.en, map: {
    'app_title': 'Netsignory client',
    'ok': 'OK',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'retry': 'Retry',
    'loading': 'Loading...',
    'error_prefix': 'Error',

    'nav_connect': 'Connect',
    'nav_messages': 'Messages',
    'nav_settings': 'Settings',

    'login_title': 'Sign In',
    'login_li_url': 'Service Address',
    'login_username': 'Username',
    'login_password': 'Password',
    'login_button': 'Sign In',
    'login_busy': 'Signing in...',

    'connect_title': 'Connect',
    'connect_btn_connect': 'Connect',
    'connect_btn_disconnect': 'Disconnect',
    'connect_select_node': 'Select Node',
    'connect_select_protocol': 'Select Protocol',
    'connect_downloading_route': 'Downloading route table',
    'connect_status_idle': 'Not connected',

    'messages_title': 'Messages',
    'messages_empty': 'No messages',

    'settings_title': 'Settings',
    'settings_custom_service': 'Custom Service',
    'settings_split_routing': 'Split Routing',
    'settings_split_routing_rules': 'rules',
    'settings_service_count': 'services',
    'settings_dns': 'DNS Servers',
    'settings_route_count': 'Route entries',
    'settings_vpn_status': 'VPN Status',
    'settings_session_id': 'Session ID',
    'settings_current_node': 'Active Node',
    'settings_check_update': 'Check for Updates',
    'settings_new_version': 'New version available',
    'settings_up_to_date': 'You are up to date',
    'settings_run_mode': 'Backend Mode',
    'settings_language': 'Language',
    'settings_log_upload': 'Upload Logs',
    'settings_log_uploading': 'Uploading...',
    'settings_log_upload_success': 'Logs uploaded successfully',
    'settings_log_upload_fail': 'Log upload failed',
    'settings_account': 'Account',
    'settings_logout': 'Sign Out',

    'split_title': 'Split Routing',
    'split_hint': 'Enter IP or C-segment, e.g. 192.168.1.1 or 10.0.0.*',
    'split_add': 'Add',
    'split_empty': 'No routing rules',

    'section_extended_service': 'Extended Service',
    'section_network': 'Network',
    'section_connection_status': 'Connection Status',
    'section_about': 'About',
    'section_account': 'Account',

    'messages_open': 'Open',
    'messages_cannot_open': 'Cannot open link',

    'connect_user': 'User',
    'connect_subscription': 'Subscription',
    'connect_expiry': 'Expires',
    'connect_auto': 'Auto',
    'connect_logout': 'Sign Out',

    'login_app_title': 'Netsignory client Sign In',
    'login_li_hint': 'example.sdwan.com',

    'settings_route_unit': 'entries',
    'settings_cannot_open': 'Cannot open',
    'settings_logout_confirm': 'Are you sure you want to sign out?',

    'split_description': 'Add custom split routing rules to control traffic.\nFormat: single IP (x.x.x.x), C-segment (x.x.x.*), domain (example.com).\nBypass: direct connection | Tunnel: force through VPN',
    'split_mode_tunnel': 'Via tunnel',
    'split_mode_bypass': 'Bypass tunnel',

    // Split routing 3-level pages
    'about_local_split': 'About Local Split Routing',
    'about_local_split_desc': 'You can choose or specify whether certain destinations are routed through the service. If not, those requests will be sent through your device\'s local network.',
    'custom_route_list': 'Custom Split Route List',
    'about_custom_split': 'About Custom Split Routing',
    'about_custom_split_desc': 'When you set custom split routes, the specified destinations will always be sent through the device\'s local network, regardless of the split routing toggle.',
    'add_custom_route': 'Add Custom Split Route',
    'about_add_route': 'About Adding Routes',
    'about_add_route_desc': 'You can enter a full IP address, or use * in the last segment (covering 0–255) to route an entire subnet through the local network.',
    'split_route_name': 'Name (optional)',
    'split_route_name_hint': 'e.g. Office LAN',
    'split_ip_label': 'IP Address',
    'split_delete': 'Delete',
    'about_collapse': 'Collapse',
    'about_expand': 'Expand',

    'status_disconnected': 'Disconnected',
    'status_connecting': 'Connecting',
    'status_connected': 'Connected',
    'status_disconnecting': 'Disconnecting',
    'status_error': 'Error',

    'err_field_empty': 'Service address, username and password are required',
    'err_login_failed': 'Login failed',
    'err_connect_failed': 'Connection failed',
    'err_no_node': 'Please select a node first',
    'err_key_blocked': 'This Li key has been blacklisted for non-compliance',
    'err_heartbeat_reconnect': 'Heartbeat failed, reconnecting',
    'err_force_disconnect': 'Server requested disconnect',
    'err_compliance_failed': 'Netsignory key compliance verification failed, disconnected',
    'err_compliance_unreachable': 'Cannot verify key compliance, disconnected',
    'err_split_invalid': 'Invalid format. Use x.x.x.x or x.x.x.*',
    'err_split_duplicate': 'Rule already exists',

    'speed_test_title': 'Speed Test',
    'speed_test_start': 'Start Test',
    'speed_test_ping': 'Ping',
    'speed_test_download': 'Download',
    'speed_test_upload': 'Upload',
    'speed_test_testing': 'Testing...',

    'add_service_title': 'Add Service',
    'add_service_hint': 'Enter service address',
    'add_service_description': 'Enter the service address to add an SD-WAN service. You can start using it after verification.',
    'add_service_button': 'Add',
    'add_service_welcome': 'Add Netsignory Service',
    'add_service_verifying': 'Verifying Service',
    'add_service_verifying_desc': 'Please wait while we verify your service information...',
    'add_service_address': 'Service Address',
    'add_service_username': 'Username',
    'add_service_password': 'Password',
    'add_new_service': 'Add New Service',

    'verify_step_server': 'Verify Server',
    'verify_step_auth': 'Authenticate',
    'verify_step_config': 'Download Config',
    'verify_step_done': 'Done',
    'verify_resolving': 'Verifying server info...',
    'verify_authenticating': 'Authenticating user...',
    'verify_downloading': 'Downloading network config...',
    'verify_success': 'Service added successfully!',

    'site_dropdown_label': 'Service Address',
    'node_dropdown_label': 'Select Node',
    'protocol_label': 'Protocol',

    'service_web_title': 'Service Info',
    'service_web_loading': 'Loading...',
    'service_web_error': 'Failed to load page',

    'route_table_title': 'Route Table',
    'route_table_server': 'Server Routes',
    'route_table_custom': 'Custom Split',
    'route_table_empty': 'No route entries',

    'update_dialog_title': 'Update Available',
    'update_dialog_content': 'Version {version} is available',
    'update_dialog_download': 'Update Now',
    'update_dialog_later': 'Later',
    'update_dialog_required': 'This update is required. Please install now.',

    'tutorial_welcome': 'Welcome to Netsignory',
    'tutorial_step1': 'Step 1: Add a Netsignory service by entering the server address for verification.',
    'tutorial_step2': 'Step 2: Select a node and protocol, then connect with one tap.',
    'tutorial_step3': 'Step 3: View push messages and manage custom split routing.',
    'tutorial_done': 'Get Started',
    'tutorial_skip': 'Skip',
    'tutorial_next': 'Next',

    'nav_service': 'Service',
    'nav_flink': 'Netsignory',

    // 2-step add service
    'add_step1_title': 'Enter service address',
    'add_step1_hint': 'Enter Netsignory service address',
    'add_step1_button': 'Verify address',
    'add_step2_title': 'Enter credentials',
    'add_step2_hint_user': 'Enter username',
    'add_step2_hint_pwd': 'Enter password',
    'add_step2_button': 'Verify credentials',
    'add_step_verifying_addr': 'Verifying service address...',
    'add_step_verifying_cred': 'Verifying credentials...',
    'add_step_done': 'Service added',
    'err_service_not_found': 'Service address not found. Please check the service info and try again',
    'err_service_disabled': 'Service has been disabled',
    'err_credentials_wrong': 'Invalid username or password',
    'err_network_unavailable': 'Network unavailable',

    // Multi-service
    'my_services': 'My Services',
    'service_management': 'Service Management',
    'delete_service': 'Delete Service',
    'modify_user_info': 'Modify User Info',
    'switch_service': 'Set as Default',
    'default_node': 'Default Node',
    'add_service_entry': 'Add Service',
    'server_address': 'Server Address',
    'no_services': 'No services yet',
    'delete_service_confirm': 'Delete this service?',
    'status_selected': 'Default',

    // Split toggle
    'split_toggle': 'Split Routing',
    'split_toggle_desc': 'When off, all traffic goes through the service',

    // External control
    'external_control': 'External Control',
    'external_control_desc': 'Allow external apps to invoke this app',
    'external_control_prompt': 'When enabled, your app can be invoked from web pages or other apps to connect. Enable?',

    // About Netsignory
    'about_flink': 'About Netsignory',
    'about_flink_desc': 'Netsignory is an SD-WAN access system based on SSL VPN. Netsignory is defined as a free access tool, providing UI interface, User interface, WEB extension service interface and connection methods. It provides third-party client services for specialized network providers. The client itself does not provide any VPN services.',
    'about_flink_team': 'Netsignory Team',
    'visit_flink_website': 'Visit Netsignory Website',
    'about_flink_email': 'f-link@gmail.com',
    'about_flink_contact': 'Contact Us',

    // Log management
    'log_select_service': 'Select service provider',
    'log_select_hint': 'If you use multiple services, select which provider to upload logs for',
    'log_clear': 'Clear Logs',
    'log_clear_confirm': 'Clear all logs?',
    'log_cleared': 'Logs cleared',
    'log_management': 'Log Management',
    'log_management_desc': 'View, upload or clear logs',
    'log_view_title': 'View Logs',
    'log_upload_about': 'About uploading logs',
    'log_upload_about_desc': 'If you experience problems or failures during service usage, you can upload logs to your service provider to help resolve the issue.\n\nIf you use multiple services, you can select which provider to upload to. Logs unrelated to that provider will not be uploaded.',
    'log_empty': 'No logs available',

    // User row
    'user_label': 'User',
    'change_user': 'Switch',

    // Quick service
    'quick_service': 'Quick Service',

    // Service announcements
    'service_announcement': 'Announcements',
    'customer_tips': 'Tips',
    'claim_benefits': 'Claim Benefits',

    // New field URLs
    'f_link_web_page': 'Netsignory Service Page',
    'service_web_entry': 'Service Page',

    // Service management
    'section_service_management': 'Service Management',
    'messages_section': 'Notifications',

    // Connect page
    'connect_mode_select': 'Connection Mode',
    'local_split_routing': 'Local Split Routing',

    // Close window dialog
    'close_window_title': 'Currently Connected',
    'close_window_message': 'You are currently connected. Please choose an action:',
    'close_disconnect_and_exit': 'Disconnect & Exit',
    'close_minimize_to_tray': 'Keep connected & Minimize',
  });
}
