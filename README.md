# 心率悬浮窗 iOS 版本

<p align="center">
  <img src="HeartFloat/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="100" alt="HeartFloat Icon"/>
</p>

心率悬浮窗 iOS 版本 - 使用画中画功能实现心率悬浮显示

## 功能特性

- 🔵 **BLE 蓝牙连接** - 连接小米手环（Mi Band 9/9 Pro）获取实时心率
- 📺 **画中画悬浮窗** - 使用 iOS 原生画中画功能显示心率
- 🌐 **HTTP 推送服务** - 提供心率数据 API 接口，支持直播推流
- 🎨 **自定义样式** - 支持颜色、字体大小、背景透明度等设置

## 系统要求

- iOS 15.0+
- iPhone 设备
- 支持蓝牙 LE 的设备

## 从源码构建

### 前置条件

- Xcode 15.0 或更高版本
- CocoaPods
- XcodeGen (可选，用于生成项目)

### 构建步骤

1. 克隆仓库

```bash
git clone https://github.com/maoyinshenzhihua/heartfloat-ios.git
cd heartfloat-ios
```

2. 安装依赖

```bash
cd HeartFloat-iOS
pod install
```

3. 打开 Xcode 项目

```bash
open HeartFloat.xcworkspace
```

4. 选择目标设备并运行

## GitHub Actions 构建

每次推送到 main 分支时，GitHub Actions 会自动构建 IPA 文件。你可以在 Actions 页面下载构建产物。

## 使用方法

1. 打开应用，点击"连接手环"按钮
2. 确保手环已开启蓝牙并处于可发现状态
3. 应用会自动扫描并连接小米手环
4. 连接成功后，点击"显示悬浮窗"开启画中画显示
5. 在设置中可以自定义悬浮窗样式

## HTTP API

启用 HTTP 服务后，可以通过以下接口获取心率数据：

- `GET /heartbeat` - 返回纯文本心率值
- `GET /heartbeat.json` - 返回 JSON 格式数据
- `GET /live` - 直播专用页面

## 技术栈

- Swift 5.0
- SwiftUI
- CoreBluetooth
- AVKit (Picture in Picture)
- GCDWebServer

## 许可证

MIT License

## 作者

maoyinshenzhihua
