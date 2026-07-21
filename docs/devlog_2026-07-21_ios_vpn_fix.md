# 寮€鍙戞棩蹇楋細iOS VPN 鍔熻兘淇

> 鏃ユ湡锛?026-07-15 ~ 2026-07-21  
> 鍒嗘敮锛歮aster  
> 鐗堟湰锛?.1.1+11

---

## 鑳屾櫙

姝ゅ墠涓鸿В鍐?CocoaPods pod install 澶辫触锛宍ios/Runner.xcodeproj/project.pbxproj` 琚浛鎹负 `flutter create` 鐢熸垚鐨?621 琛屽共鍑€鐗堬紝瀵艰嚧 VPNTunnel App Extension 鐩爣琚Щ闄ゃ€傚悓鏃?`AppDelegate.swift` 浠呬繚鐣?12 琛岀┖澹筹紝鏃犱换浣?VPN 鐩稿叧浠ｇ爜銆傜敤鎴峰湪 iPhone 瀹夎 IPA 鍚庣偣鍑昏繛鎺ユ棤浠讳綍鍙嶅簲銆?

---

## 璇婃柇缁撹

| # | 闂 | 涓ラ噸绋嬪害 |
|---|------|----------|
| 1 | `AppDelegate.swift` 鏄┖澹?鈥?鏃?MethodChannel / EventChannel / NetworkExtension 浠ｇ爜 | 馃敶 鑷村懡 |
| 2 | `project.pbxproj` 涓嶅惈 VPNTunnel 鐩爣 鈥?PacketTunnelProvider 鏈弬涓庣紪璇?| 馃敶 鑷村懡 |
| 3 | Bundle ID 涓嶄竴鑷?鈥?IPA 浣跨敤 `com.unifyflow.vpnClient`锛屼唬鐮佹湡鏈?`com.netsignory.app` | 馃煛 涓瓑 |
| 4 | 鍏嶈垂 Apple ID 鏃犳硶绛惧悕 Network Extension 鏉冮檺 | 馃敶 纭檺鍒?|

---

## 淇鍐呭

### 1. `ios/Runner/AppDelegate.swift` 鈥?瀹屾暣閲嶅啓

**鍙樻洿鍓?*锛?2 琛岀┖澹筹紙`FlutterImplicitEngineDelegate` 妯″紡锛屾棤 VPN 浠ｇ爜锛?

**鍙樻洿鍚?*锛?00+ 琛屽畬鏁?VPN 闆嗘垚

```swift
import Flutter
import UIKit
import NetworkExtension      // 鈫?鏂板
import SystemConfiguration    // 鈫?鏂板
```

| 鍔熻兘 | 瀹炵幇 |
|------|------|
| MethodChannel `com.vpnclient/vpn` | `connect` / `disconnect` / `getStatus` / `getTunnelStats` / `pingGateway` / `generateKeyPair` / `applyNetworkConfig` / `applyDefaultRoute` |
| EventChannel `com.vpnclient/vpn_status` | 瀹炴椂鎺ㄩ€?`NEVPNStatus` 鍙樺寲 (invalid 鈫?disconnected 鈫?connecting 鈫?connected 鈫?disconnecting 鈫?reconnecting) |
| VPN 閰嶇疆绠＄悊 | `NETunnelProviderManager` 鍒涘缓/淇濆瓨/鍔犺浇锛宍ensureVpnManager()` 鎳掑垵濮嬪寲 |
| 闅ч亾閫氫俊 | `NETunnelProviderSession.sendProviderMessage()` 鑾峰彇缁熻 (tx/rx bytes) |
| 缃戠粶妫€娴?| `SCNetworkReachability` ping 缃戝叧 |
| 瀵嗛挜鐢熸垚 | `SecKeyCreateRandomKey` EC P-256 WireGuard 瀵嗛挜瀵?|
| 鐘舵€佺洃鍚?| `NEVPNStatusDidChange` 閫氱煡 鈫?EventChannel 鈫?Flutter UI 瀹炴椂鏇存柊 |

鎻掍欢娉ㄥ唽妯″紡鍥為€€涓轰紶缁?`GeneratedPluginRegistrant.register(with: self)`锛圴PN 搴旂敤闇€鍦?Flutter Engine 鍒濆鍖栧墠瀹屾垚 Channel 娉ㄥ唽锛夈€?

### 2. `ios/Runner.xcodeproj/project.pbxproj` 鈥?鎭㈠ VPNTunnel 鐩爣

**鍙樻洿鍓?*锛?21 琛岋紙浠?Runner 鐩爣锛宖lutter create 骞插噣鐗堬級

**鍙樻洿鍚?*锛?98 琛?

鏂板鍐呭锛?

| 椤圭洰 | 鍊?|
|------|-----|
| VPNTunnel Target | `PBXNativeTarget`锛宍com.apple.product-type.app-extension` |
| Bundle ID | `com.netsignory.app.VPNTunnel` |
| 涓诲簲鐢?Bundle ID | `com.netsignory.app` |
| Embed App Extensions | Runner 鈫?VPNTunnel.appex锛坄RemoveHeadersOnCopy`锛?|
| 妗嗘灦渚濊禆 | `NetworkExtension.framework` |
| 鎺堟潈鏂囦欢 | `VPNTunnel/VPNTunnel.entitlements` |
| Info.plist | `VPNTunnel/Info.plist` |
| 閮ㄧ讲鐩爣 | iOS 13.0 |

### 3. `ios/Runner/SceneDelegate.swift` 鈥?娓呯悊娉ㄩ噴

娣诲姞璇存槑娉ㄩ噴锛氬綋鍓嶆湭鍚敤 `UIApplicationSceneManifest`锛孉ppDelegate 閫氳繃 `window?.rootViewController` 鐩存帴绠＄悊 FlutterVC銆?

### 4. CI Workflow (`.github/workflows/ios-ci.yml`)

缁忓巻澶氳疆杩唬淇锛?

| 杩唬 | 闂 | 瑙ｅ喅 |
|------|------|------|
| V1 | `xcodebuild -exportArchive` 澶辫触锛堟棤璇佷功锛?| 鏀圭敤鎵嬪姩 Payload 鈫?zip 鈫?IPA |
| V2 | `cd` 璺緞娣蜂贡锛宍ls` 鎵句笉鍒?IPA | IPA 鏀惧湪宸ヤ綔鍖烘牴鐩綍 |
| V3 | YAML 璇硶閿欒锛坋cho XML inline锛?| 鏀圭敤 `PlistBuddy` |
| V4 | GitHub 缂撳瓨鏃?workflow | 鏂板缓 `ios-ci.yml` 鏇夸唬 `ios-build.yml` |

鏈€缁堟柟妗堬細

```bash
flutter build ipa --release --no-codesign
mkdir -p Payload
cp -R build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app Payload/
zip -r Netsignory_unsigned.ipa Payload/
rm -rf Payload
ls -lh Netsignory_unsigned.ipa
```

---

## 鍏抽敭鏋舵瀯鍐崇瓥

### 涓轰粈涔堜笉浣跨敤 `FlutterImplicitEngineDelegate`锛?

浼犵粺 `FlutterAppDelegate` 妯″紡鍦?`didFinishLaunchingWithOptions` 涓彲浠ュ悓姝ヨ幏鍙?`FlutterViewController` 骞跺垱寤?MethodChannel銆傝€?`FlutterImplicitEngineDelegate` 妯″紡涓?Channel 娉ㄥ唽鏃舵満杈冩櫄锛孷PN Manager 鍒濆鍖栧彲鑳藉欢杩燂紝瀵艰嚧棣栨杩炴帴鍝嶅簲鎱€?

### 涓轰粈涔?Bundle ID 鐢?`com.netsignory.app`锛?

- 涓?Dart 灞?`PlatformVpnService` 涓€鑷?
- Keychain Access Group `$(AppIdentifierPrefix)com.netsignory.app` 宸插湪 entitlements 涓瀹?
- VPNTunnel 鎵╁睍鑷姩鑾峰緱 `com.netsignory.app.VPNTunnel`
- `AppDelegate` 閫氳繃 `Bundle.main.bundleIdentifier + ".VPNTunnel"` 鍔ㄦ€佽幏鍙栨墿灞?ID

---

## 鏂囦欢鍙樻洿娓呭崟

```
ios/Runner/AppDelegate.swift          鈫?閲嶅啓 (12鈫?00+ 琛?
ios/Runner/SceneDelegate.swift        鈫?娓呯悊
ios/Runner.xcodeproj/project.pbxproj  鈫?鎭㈠ VPNTunnel 鐩爣 (621鈫?98 琛?
.github/workflows/ios-ci.yml          鈫?澶氳疆淇
```

---

## 宸茬煡闄愬埗

**iOS Network Extension 蹇呴』浣跨敤 Apple Developer 浠樿垂璐﹀彿锛?99/骞达級绛惧悕銆?*

鍏嶈垂 Apple ID 绛惧悕鐨?IPA 鏃犳硶鍚姩 Packet Tunnel Provider 鎵╁睍銆傚鏋滀娇鐢ㄤ粯璐硅处鍙凤紝闇€鍦?GitHub Secrets 閰嶇疆浠ヤ笅鍙橀噺浠ュ惎鐢?`adhoc` 绛惧悕妯″紡锛?

| Secret | 璇存槑 |
|--------|------|
| `BUILD_CERTIFICATE_BASE64` | 鍙戝竷璇佷功 `.p12` Base64 |
| `P12_PASSWORD` | `.p12` 瀵嗙爜 |
| `IOS_TEAM_ID` | Apple Developer Team ID |
| `APP_PROFILE_BASE64` | Runner 鎻忚堪鏂囦欢 `.mobileprovision` Base64 |
| `EXT_PROFILE_BASE64` | VPNTunnel 鎻忚堪鏂囦欢 `.mobileprovision` Base64 |
| `KEYCHAIN_PASSWORD` | 涓存椂 Keychain 瀵嗙爜 |

---

## 鏋勫缓楠岃瘉

```
flutter build ipa --release --no-codesign
鉁?Built build/ios/archive/Runner.xcarchive (168.7MB)
    Version: 0.1.1 (11)
    Deployment Target: 13.0
    Bundle Identifier: com.netsignory.app
```
