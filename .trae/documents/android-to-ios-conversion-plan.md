# Android 心率浮窗应用转 iOS IPA 计划

## 一、项目分析

### 1.1 原始应用功能

| 功能模块 | Android 实现 | iOS 可行性 |
|---------|-------------|-----------|
| BLE 蓝牙连接 | BluetoothGatt API | ✅ 可用 CoreBluetooth |
| 心率数据读取 | 标准心率服务 (180d) | ✅ 完全支持 |
| **悬浮窗显示** | WindowManager + TYPE_APPLICATION_OVERLAY | ❌ **iOS 不支持** |
| HTTP 服务器 | NanoHTTPD | ✅ 可用 Swifter |
| 设置界面 | SharedPreferences | ✅ UserDefaults |
| 字体管理 | Typeface + 自定义字体 | ✅ UIFont |

### 1.2 iOS 平台限制

**关键限制：iOS 不支持真正的悬浮窗！**

- Android 的 `WindowManager` 可以在任意应用之上显示窗口
- iOS 出于安全和隐私考虑，**完全禁止**应用在其他应用之上显示内容
- 这是 iOS 的系统级限制，无法绕过

### 1.3 替代方案

| 原功能 | iOS 替代方案 |
|-------|-------------|
| 悬浮窗 | App 内显示 + Widget 小组件 + Live Activity |
| 后台心率监测 | 后台蓝牙任务 + 推送通知 |
| 实时心率显示 | 锁屏小组件 (iOS 16.1+) / 灵动岛 (iPhone 14 Pro+) |

---

## 二、转换策略

### 2.1 可实现的功能

1. **BLE 蓝牙连接** - 连接小米手环，读取心率数据
2. **App 内心率显示** - 在应用内显示实时心率
3. **HTTP 服务器** - 提供 `/heartbeat`、`/heartbeat.json`、`/live` 接口
4. **设置管理** - 颜色、字体大小等设置
5. **后台心率监测** - 使用后台蓝牙模式

### 2.2 无法实现的功能

1. **全局悬浮窗** - iOS 系统限制，无法实现
2. **在其他应用之上显示** - 完全不可能

### 2.3 建议的 iOS 版本功能

1. **主界面** - 显示心率、连接状态、日志
2. **设置页面** - 自定义显示样式
3. **HTTP 服务器** - 与 Android 版本相同
4. **Widget 小组件** - 在桌面显示心率（需要额外配置）
5. **后台运行** - 保持蓝牙连接

---

## 三、项目结构

```
ios/
├── HeartFloat/
│   ├── project.yml              # XcodeGen 配置
│   ├── Sources/
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   ├── Controllers/
│   │   │   ├── MainViewController.swift
│   │   │   └── SettingsViewController.swift
│   │   ├── Services/
│   │   │   ├── BleService.swift
│   │   │   ├── HttpServerManager.swift
│   │   │   └── SettingsManager.swift
│   │   ├── Views/
│   │   │   ├── HeartRateView.swift
│   │   │   └── LogView.swift
│   │   ├── Models/
│   │   │   └── HeartRateData.swift
│   │   └── Utils/
│   │       └── Extensions.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── LaunchScreen.storyboard
│       └── Info.plist
└── .github/
    └── workflows/
        └── ios-build.yml        # GitHub Actions 工作流
```

---

## 四、实施步骤

### 阶段一：项目初始化

1. 创建 iOS 文件夹结构
2. 创建 XcodeGen 配置文件 (project.yml)
3. 创建 GitHub Actions 工作流

### 阶段二：核心服务实现

1. **BleService.swift** - 蓝牙服务
   - 扫描小米手环设备
   - 连接设备
   - 订阅心率特征
   - 后台蓝牙模式

2. **HttpServerManager.swift** - HTTP 服务器
   - 使用 Swifter 库
   - 实现 `/heartbeat` 接口
   - 实现 `/heartbeat.json` 接口
   - 实现 `/live` 直播页面

3. **SettingsManager.swift** - 设置管理
   - UserDefaults 存储
   - 颜色、字体大小设置

### 阶段三：UI 实现

1. **MainViewController** - 主界面
   - 心率显示
   - 连接状态
   - 日志显示
   - 连接/断开按钮

2. **SettingsViewController** - 设置界面
   - 颜色选择
   - 字体大小调整
   - HTTP 服务器开关

### 阶段四：配置文件

1. **Info.plist** - 权限配置
   - 蓝牙权限
   - 后台模式
   - 网络权限

2. **Assets.xcassets** - 应用图标

### 阶段五：打包配置

1. GitHub Actions 工作流
2. 签名配置（免签名模式）

---

## 五、技术细节

### 5.1 BLE 服务 UUID

```swift
let HEART_RATE_SERVICE_UUID = CBUUID(string: "180D")
let HEART_RATE_MEASUREMENT_UUID = CBUUID(string: "2A37")
```

### 5.2 后台模式配置

Info.plist 需要配置：
- `UIBackgroundModes`: `bluetooth-central`
- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`

### 5.3 HTTP 服务器

使用 Swifter 库：
```swift
import Swifter

let server = HttpServer()
server["/heartbeat"] = { request in
    return .ok(.text("\(currentHeartRate)"))
}
try server.start(8080)
```

---

## 六、依赖库

| 库名 | 用途 | 版本 |
|-----|------|------|
| Swifter | HTTP 服务器 | 1.5.0 |

---

## 七、注意事项

### 7.1 重要限制

⚠️ **iOS 版本无法实现悬浮窗功能**

这是 iOS 系统的根本限制，不是技术问题。如果用户需要类似功能，建议：
1. 使用 Widget 小组件（iOS 14+）
2. 使用 Live Activity（iOS 16.1+）
3. 使用灵动岛（iPhone 14 Pro+）

### 7.2 后台运行限制

iOS 后台蓝牙任务有时间限制，需要正确配置后台模式才能长时间运行。

### 7.3 蓝牙权限

需要在 Info.plist 中声明蓝牙权限描述。

---

## 八、预期成果

完成后的 iOS 应用将具备：

1. ✅ 蓝牙连接小米手环
2. ✅ 实时读取心率数据
3. ✅ App 内显示心率
4. ✅ HTTP API 接口
5. ✅ 自定义设置
6. ❌ 悬浮窗（iOS 不支持）

---

*计划版本：v1.0*
*创建时间：2026-03-28*
