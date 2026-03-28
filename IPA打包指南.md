# iOS IPA 打包指南

## 概述

本文档介绍如何使用 **GitHub Actions** 云端打包 iOS 应用，无需 Mac 电脑。

---

## 一、工作原理

```
本地代码 (Windows)
    ↓ git push
GitHub 仓库
    ↓ GitHub Actions (macOS runner)
Xcode 编译 + IPA 打包
    ↓ upload-artifact
下载 IPA 文件
    ↓ 牛蛙助手等工具
安装到 iOS 设备
```

---

## 二、项目结构

```
russian-blocks-ios/
├── .github/
│   └── workflows/
│       └── ios-build-signed.yml    # GitHub Actions 工作流
├── ios/
│   └── RussianPoopBlock/
│       ├── project.yml              # XcodeGen 配置
│       ├── Sources/                # Swift 源代码
│       └── Resources/              # 资源文件 (图片、音效)
└── README.md
```

---

## 三、打包步骤

### 3.1 推送代码触发构建

```bash
cd e:\3dmr
git add .
git commit -m "your changes"
git push -u origin master
```

每次推送到 `master` 分支，GitHub Actions 会自动触发构建。

### 3.2 查看构建状态

1. 访问：https://github.com/maoyinshenzhihua/russian-blocks-ios/actions
2. 点击最新的 workflow 运行
3. 查看构建日志

### 3.3 下载 IPA 文件

构建成功后：

1. 在 Actions 页面点击构建任务
2. 找到 **Artifacts** 部分
3. 下载 `RussianPoopBlock-iOS-[构建号].ipa`

### 3.4 安装到 iOS 设备

使用 **牛蛙助手** 或其他 IPA 安装工具：

1. 打开牛蛙助手
2. 连接 iOS 设备
3. 导入下载的 IPA 文件
4. 点击安装
5. 在设备上信任证书（设置 → 通用 → VPN与设备管理 → 信任）

---

## 四、GitHub Actions 工作流详解

### 4.1 完整工作流配置

```yaml
name: Build iOS App (With Signing)

on:
  push:
    branches:
      - master
    paths:
      - 'ios/**'
      - '.github/workflows/ios-build-signed.yml'
  workflow_dispatch:

env:
  XCODE_VERSION: '15.0'
  IOS_DEPLOYMENT_TARGET: '13.0'
  BUNDLE_ID: com.poopblock.russian
  SCHEME: RussianPoopBlock

jobs:
  build-signed:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Setup Xcode
        run: sudo xcode-select -s /Applications/Xcode_${{ env.XCODE_VERSION }}.app

      - name: Generate Xcode project
        working-directory: ./ios/RussianPoopBlock
        run: |
          if which xcodegen >/dev/null; then
            echo "XcodeGen is already installed"
          else
            brew install xcodegen
          fi
          xcodegen generate

      - name: Fix project format
        run: |
          find . -name "*.pbxproj" -exec sed -i '' 's/77/56/g' {} \;

      - name: Build
        run: |
          xcodebuild -project RussianPoopBlock.xcodeproj \
            -scheme ${{ env.SCHEME }} \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            build

      - name: Create IPA
        run: |
          mkdir -p output
          APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "*.app" -type d 2>/dev/null | grep -v "PlugIns" | head -1)
          cp -r "$APP_PATH" ./output/
          cd ./output
          mkdir -p Payload
          cp -r *.app Payload/
          zip -r ./RussianPoopBlock-${{ github.run_number }}.ipa Payload

      - name: Upload IPA
        uses: actions/upload-artifact@v4
        with:
          name: RussianPoopBlock-iOS-${{ github.run_number }}
          path: output/RussianPoopBlock-${{ github.run_number }}.ipa
          retention-days: 30
```

### 4.2 关键参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `XCODE_VERSION` | Xcode 版本 | 15.0 |
| `IOS_DEPLOYMENT_TARGET` | 最低 iOS 版本 | 13.0 |
| `BUNDLE_ID` | 应用 Bundle ID | com.poopblock.russian |
| `SCHEME` | Xcode Scheme 名称 | RussianPoopBlock |

### 4.3 工作流程阶段

```
1. Checkout         - 拉取代码
2. Setup Xcode     - 安装 Xcode 15.0
3. Generate        - 使用 XcodeGen 生成项目
4. Fix format      - 降级项目格式版本 (77→56，兼容 Xcode 15.4)
5. Build           - Xcode 编译
6. Create IPA      - 打包为 IPA 文件
7. Upload          - 上传构建产物
```

---

## 五、本地开发（可选）

如果需要本地调试：

### 5.1 Mac 用户

```bash
cd ios/RussianPoopBlock
brew install xcodegen
xcodegen generate
open RussianPoopBlock.xcodeproj
```

### 5.2 手动打包 IPA

```bash
# 编译
xcodebuild -project RussianPoopBlock.xcodeproj \
  -scheme RussianPoopBlock \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  build

# 打包 IPA
mkdir -p output/Payload
cp -r ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Release-iphoneos/*.app output/Payload/
cd output
zip -r RussianPoopBlock.ipa Payload
```

---

## 六、常见问题

### 6.1 构建失败

**检查项**：
- 代码是否有语法错误
- 资源文件路径是否正确
- Xcode 版本是否兼容

**解决方式**：查看 GitHub Actions 日志定位错误

### 6.2 IPA 无法安装

**可能原因**：
- 证书未信任 → 在设备上信任证书
- 设备系统版本低于 `IOS_DEPLOYMENT_TARGET`
- IPA 文件损坏 → 重新下载

### 6.3 代理网络问题

推送代码时如果遇到网络错误：
```bash
# 清除代理设置
git config --global --unset http.proxy
git config --global --unset https.proxy
```

---

## 七、更新应用

每次更新代码后：

```bash
cd e:\3dmr
git add .
git commit -m "update description"
git push origin master
```

然后重新下载新的 IPA 文件安装即可。

---

*文档版本：v1.0*
*最后更新：2026-03-28*
