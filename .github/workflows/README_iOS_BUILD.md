# iOS 云端打包说明

本工作流(`ios-build.yml`)用 GitHub Actions 的 macOS runner(`macos-26` + Xcode 26.5)自动完成 iOS 编译、签名和 TestFlight 上传,**绕开"必须有 Mac"的限制**。

---

## 1. 三种构建模式

| 模式 | 输出 | 需要签名 Secret | 能否装到手机 | 能否上架 |
|---|---|---|---|---|
| `unsigned`(默认) | `.app`(未签名) | ❌ 不需要 | ❌ 不能 | ❌ 不能 |
| `adhoc` | `.ipa`(Ad-Hoc) | ✅ 需要 6 个基础 Secret | ✅ 只能装到注册 UDID 的设备 | ❌ |
| `appstore` | `.ipa`(Distribution) | ✅ 需要 6 个基础 Secret;TestFlight 自动上传另需 3 个 API Secret | ✅ TestFlight / 上架 | ✅ |

**第一次跑必选 `unsigned`** — 验证代码能在 CI 上编译,不消耗任何签名资源。

---

## 2. 触发方式

### 自动触发(仅 `unsigned` 模式)
- push 到 `main` / `master` 分支
- push 一个 `v*` 形式的 tag(例如 `v0.1.0`)
- 对 `main` / `master` 发 PR

### 手动触发(选任意模式)
1. GitHub 仓库 → **Actions** 标签
2. 左侧选 **iOS Build & Deploy** → 右上 **Run workflow**
3. 在 **Build mode** 下拉里选模式 → **Run workflow**
4. 约 15-25 分钟后,该次运行页面底部下载 artifact **`Netsignory-ipa`**

---

## 3. 启用签名打包(`adhoc` / `appstore`)

在仓库 **Settings → Secrets and variables → Actions** 添加以下 Secret。

### 3.1 基础签名 Secret(6 个,`adhoc` / `appstore` 都需要)

| Secret 名称 | 内容 | 如何获取 |
|---|---|---|
| `BUILD_CERTIFICATE_BASE64` | 分发证书 `.p12` 的 base64 | Apple Developer → Certificates → Apple Distribution → 导出 `.p12` 后:<br>Mac: `base64 -i cert.p12 \| pbcopy`<br>Win PS: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12")) \| Set-Clipboard` |
| `P12_PASSWORD` | 导出 `.p12` 时您设置的密码 | 您自己设定 |
| `KEYCHAIN_PASSWORD` | CI 临时 keychain 密码 | 任意强随机字符串,例如 `openssl rand -hex 16` 输出 |
| `APP_PROFILE_BASE64` | 主应用 `.mobileprovision` 的 base64 | Apple Developer → Profiles → App Store → App ID `com.netsignory.app` → 下载后 base64 |
| `EXT_PROFILE_BASE64` | VPNTunnel 扩展 `.mobileprovision` 的 base64 | 同上,App ID 为 `com.netsignory.app.VPNTunnel` |
| `IOS_TEAM_ID` | 10 位 Team ID | Apple Developer → 右上头像 → Membership Details |

### 3.2 TestFlight 自动上传 Secret(3 个,可选,仅 `appstore` 模式生效)

配置齐后,`appstore` 构建成功会自动上传到 TestFlight;未配置则跳过上传(不影响构建产物)。

| Secret 名称 | 内容 | 如何获取 |
|---|---|---|
| `APPSTORE_API_KEY_ID` | 10 位 Key ID | App Store Connect → Users and Access → Keys → 创建 API Key |
| `APPSTORE_ISSUER_ID` | UUID(36 位) | 同上页面顶部 "Issuer ID" |
| `APPSTORE_API_PRIVATE_KEY_BASE64` **(推荐)** | `.p8` 私钥的 base64 | 创建 Key 后立即下载 `AuthKey_XXXX.p8`(只能下载一次!) → `[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXX.p8"))` |

> `APPSTORE_API_PRIVATE_KEY`(原始纯文本 PEM)也支持,但 base64 版本更稳(避免换行 / DECODER 错误)。

### 3.3 可选 Variables

| 变量名 | 用途 | 默认值 |
|---|---|---|
| `API_BASE_URL` | 后端 API 域名(通过 `--dart-define` 注入) | `https://api.netsignory.com` |

---

## 4. 关键准备事项

### 4.1 Bundle ID(工程已配置好,创建 App ID 时必须完全一致)

```
主应用:        com.netsignory.app
VPNTunnel 扩展: com.netsignory.app.VPNTunnel
```

### 4.2 NetworkExtension 权限(VPN 应用专属)

在 Apple Developer Portal 创建 App ID 时:

1. 主 App ID 勾选 **Network Extensions** capability
2. 扩展 App ID(`xxx.VPNTunnel`)同样勾选 Network Extensions
3. App Store 提审时,Apple 会**额外人工审核 VPN 使用场景**(通常 1-3 个工作日回信,请如实说明用途)

### 4.3 Provisioning Profile 检查清单

生成 `.mobileprovision` 前,确保 Profile **包含**:
- ✅ `com.apple.developer.networking.networkextension` entitlement
- ✅ App ID 后缀匹配(主 App + Extension 各生成一份)
- ✅ 选择 **App Store** 类型(不要选 Development)
- ✅ 关联的证书是当前 workflow 用的 `BUILD_CERTIFICATE_BASE64` 里那张

---

## 5. 推荐首次运行流程

```
Step 1. 代码 push 到 GitHub 仓库(可 Private)
Step 2. Actions → iOS Build & Deploy → Run workflow → build_mode = unsigned
Step 3. 等约 20 分钟
        ├─ 通过 → 代码可编译,工程配置完整 ✅
        └─ 失败 → 看日志,通常是 pubspec / Podfile 问题

Step 4. 甲方获取 Apple Developer 证书 + 2 个 Profile
Step 5. 配置 3.1 中 6 个基础 Secret(暂不配 3.2)
Step 6. Run workflow → build_mode = adhoc
        └─ 通过 → 下载 .ipa,用蒲公英 / Apple Configurator 分发验证功能

Step 7. 功能验证 OK 后,配置 3.2 中 3 个 API Secret
Step 8. Run workflow → build_mode = appstore
        └─ 通过 → IPA 自动上传 TestFlight,登录 App Store Connect 提审
```

---

## 6. 常见踩坑

| 错误 | 原因 | 解决 |
|---|---|---|
| `No signing certificate "Apple Distribution" found` | 证书未导入 / P12 密码错 | 检查 `BUILD_CERTIFICATE_BASE64` 和 `P12_PASSWORD` |
| `Provisioning profile doesn't include ... networkextension` | Profile 没勾 NetworkExtension | 回 App ID 页给两个 ID 勾上,**重新生成 Profile**(老 Profile 不会自动更新) |
| `Cannot find provisioning profile for com.netsignory.app.VPNTunnel` | 扩展 Profile 缺失 | 检查 `EXT_PROFILE_BASE64` 是否已配置 |
| `code object is not signed at all` | 证书 / Profile 不匹配 | 生成 Profile 时必须选中 `BUILD_CERTIFICATE_BASE64` 对应的那张证书 |
| Transporter 报 **409**:`Invalid MinimumOSVersion ... in 'Runner.app/Frameworks/App.framework' is ''` | Flutter App.framework 缺 MinimumOSVersion | workflow 已自动检测和注入 13.0,不用手动改 |
| App Store 报 **90725**:`built with iOS 18.5 SDK. All iOS apps must be built with iOS 26 SDK` | Xcode 版本过旧 | workflow 已固定 macos-26 + Xcode 26.5,不会再遇 |
| App Store 报 **90717**:`large app icon ... can't be transparent or contain an alpha channel` | 图标含 alpha 通道 | 工程内所有 AppIcon PNG 已去 alpha,不用手动改 |
| TestFlight 报 `JWT expired 401` | `.p8` 上传时被 Apple 处理超时 | workflow 用 `wait-for-processing: false`,不用等 |
| TestFlight 报 `DECODER routines::unsupported` | `.p8` PEM 格式换行被 GitHub 破坏 | 用 `APPSTORE_API_PRIVATE_KEY_BASE64`,别用纯文本变体 |
| CocoaPods 报 `pod install` 解析失败 | `project.pbxproj` 结构损坏 | 工程已修复,如再遇请提交 issue |

---

## 7. 完成后回传给开发的信息

```
✅ Apple Team ID:        ____________(10 位)
✅ Team Name:            ____________
✅ App Store Connect App:  https://appstoreconnect.apple.com/apps/_________
✅ TestFlight 邀请链接:    ____________(可选)
```

**严禁回传:** `.p12` / `.mobileprovision` / `.p8` 原文件、任何密码明文。这些一旦泄露相当于身份被盗。

---

## 8. 项目已完成的修复(供故障对照)

工程内已针对以下已知问题预先修复,如遇相关报错说明 workflow 环境异常,联系开发:

| 问题 | 修复位置 |
|---|---|
| CocoaPods 无法解析 pbxproj | 修复 `PBXGroup` / `PBXResourcesBuildPhase` 结构 |
| Thin Binary / Embed Extensions 循环 | Podfile `post_install` 调整 build_phases 顺序 |
| Windows CRLF 破坏 shell 脚本 | `.gitattributes` 强制 `.sh` / `.yml` 用 LF |
| App.framework 缺 MinimumOSVersion(409) | `AppFrameworkInfo.plist` 显式补 13.0,workflow 二次校验 |
| iOS 18 SDK 被 App Store 拒绝(90725) | 固定 macos-26 + Xcode 26.5 |
| AppIcon 含 alpha 通道(90717) | 所有 PNG 已转 RGB(无 alpha) |
| Flutter 3.27 与旧 AppDelegate 不兼容 | 重写 `AppDelegate.swift` / 移除 `SceneDelegate` 依赖 |
| Bundle ID 占位符 `com.example.*` | 已统一为 `com.netsignory.app` / `com.netsignory.app.VPNTunnel` |

---

**如需重新生成一份专门发给甲方的操作手册,联系开发生成 `iOS打包-甲方操作指南.md`。**
