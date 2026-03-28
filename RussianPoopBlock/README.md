# 俄罗斯粑粑块 iOS 移植项目

## 项目概述

这是一个从 Android 原生应用移植到 iOS 的俄罗斯方块游戏，基于 Gradle 7.3.1 Android 项目手动迁移完成。

## 原 Android 项目分析

- **包名**: `com.poopblock.russian`
- **最低 SDK**: 21 (Android 5.0)
- **目标 SDK**: 33
- **游戏类型**: 俄罗斯方块

### 主要功能

1. **游戏核心**: 7种俄罗斯方块（I、O、T、L、J、S、Z），每种有独特图标
2. **计分系统**: 消行得分（一消+10，二消+30，三消+60，四消+100）
3. **游戏时长记录**: MM:SS 格式
4. **设置选项**: 动画效果、背景音乐、控制器支持、游戏音效、小屏模式
5. **游戏记录**: 本地存储，按分数降序排列
6. **控制器支持**: 支持 D-pad 和游戏手柄按钮映射

### 移植的文件映射

| Android (Java) | iOS (Swift) |
|----------------|-------------|
| `SplashActivity` | `SplashViewController` |
| `MainMenuActivity` | `MainMenuViewController` |
| `GameActivity` | `GameViewController` |
| `SettingsActivity` | `SettingsViewController` |
| `GameRecordActivity` | `GameRecordViewController` |
| `AboutActivity` | `AboutViewController` |
| `MusicService` | `MusicService` |
| `SoundManager` | `SoundManager` |
| `SharedPreferences` | `GameSettings` (UserDefaults) |
| `GameRecord` | `GameRecord` |
| `TetrisGameEngine` | `TetrisGameEngine` |

## 项目结构

```
ios/RussianPoopBlock/
├── project.yml                 # XcodeGen 配置文件
├── Resources/
│   ├── Info.plist
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/
│       ├── BlockImages/         # 需要添加方块图片
│       └── SoundFiles/         # 需要添加音效文件
└── Sources/
    ├── App/
    │   ├── AppDelegate.swift
    │   └── SceneDelegate.swift
    ├── Models/
    │   ├── GameSettings.swift
    │   └── GameRecord.swift
    ├── Services/
    │   ├── MusicService.swift
    │   └── SoundManager.swift
    ├── Utilities/
    │   └── TetrisGameEngine.swift
    └── Views/
        ├── SplashViewController.swift
        ├── MainMenuViewController.swift
        ├── GameViewController.swift
        ├── SettingsViewController.swift
        ├── AboutViewController.swift
        └── GameRecordViewController.swift
```

## 构建步骤

### 1. 安装 XcodeGen

在 macOS 上运行:

```bash
brew install xcodegen
```

### 2. 添加资源文件

需要从 Android 项目复制以下资源到 iOS 项目：

#### 图片资源 (copy to `Resources/Assets.xcassets/BlockImages/`)

| Android 资源 | 说明 |
|-------------|------|
| `egg.png` | I型方块 - 鸡蛋 |
| `cabbage.png` | O型方块 - 白菜 |
| `cigarette.png` | T型方块 - 烟头 |
| `poop_block.png` | L/J型方块 - 粑粑 |
| `stone.png` | S/Z型方块 - 石头 |
| `ic_launcher.png` | 应用图标 (1024x1024) |

#### 音频资源 (copy to `Resources/Sounds/`)

| 文件名 | 说明 |
|-------|------|
| `game_music.mp3` | 背景音乐 (循环播放) |
| `validclick.mp3` | 有效点击音效 |
| `invalidoperation.mp3` | 无效操作音效 |
| `jidan.mp3` | I型方块音效 |
| `baicai.mp3` | O型方块音效 |
| `yantou.mp3` | T型方块音效 |
| `baba.mp3` | L/J型方块音效 |
| `shitou.mp3` | S/Z型方块音效 |
| `jieshu.mp3` | 游戏结束音效 |

### 3. 生成 Xcode 项目

```bash
cd ios/RussianPoopBlock
xcodegen generate
```

### 4. 在 Xcode 中打开并构建

```bash
open RussianPoopBlock.xcodeproj
```

然后在 Xcode 中:
1. 选择目标设备或模拟器
2. 点击 Run (⌘R) 构建并运行

## 功能对照表

| 功能 | Android 实现 | iOS 实现 |
|------|------------|---------|
| 游戏网格 | `GridLayout` 10x20 | `UIImageView` 数组 10x20 |
| 方块下落 | `Handler.postDelayed()` | `Timer.scheduledTimer()` |
| 碰撞检测 | 2D 数组 + 边界检查 | 2D 数组 + 边界检查 |
| 方块旋转 | 矩阵转置算法 | 矩阵转置算法 |
| 音效播放 | `SoundPool` | `AVAudioEngine` |
| 背景音乐 | `MediaPlayer` Service | `AVAudioPlayer` |
| 设置存储 | `SharedPreferences` | `UserDefaults` |
| 转场动画 | `overridePendingTransition()` | UIView 动画 |

## 注意事项

1. **macOS required**: iOS 应用必须使用 macOS 和 Xcode 构建
2. **真机测试需要签名**: 需要配置 Apple Developer 账号和证书
3. **模拟器测试**: 可以使用 Xcode 内置模拟器无需签名
4. **资源文件命名**: iOS 资源文件名区分大小写，确保与代码中一致

## 开发者信息

- **开发者**: 小花爱瞎剪
- **原始游戏灵感**: S-Venti 制作的《俄罗斯粑粑块》鬼畜视频
