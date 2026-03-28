# GitHub Secrets 配置指南

## 概述

本项目使用 GitHub Actions 自动构建 iOS 应用。为了成功构建，你需要配置以下 GitHub Secrets。

## 方法一：App Store Connect API Key（推荐 ✅）

这是最推荐的签名方式，不需要处理证书。

### 创建 App Store Connect API Key

1. 登录 [App Store Connect](https://appstoreconnect.apple.com/)
2. 进入 **用户和访问** → **密钥**
3. 点击 **+** 创建新密钥
4. 选择 **App Store Connect API** 类型
5. 下载生成的 `.p8` 密钥文件
6. 记录 **Key ID** 和 **Issuer ID**

### 需要配置的 Secrets

| Secret Name | 说明 | 示例值 |
|------------|------|--------|
| `APP_STORE_CONNECT_API_KEY_ID` | 密钥 ID | `XXXXXXXXXX` |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | 发布者 ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | 密钥内容（base64 编码的 .p8 文件） | `MIGTA...` |

### 将 .p8 文件转换为 base64

**macOS/Linux:**
```bash
base64 -i AuthKey_XXXXXXXXXX.p8
```

**Windows (PowerShell):**
```powershell
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes("C:\path\to\AuthKey_XXXXXXXXXX.p8"))
```

### 配置步骤

1. 进入 GitHub 仓库 → **Settings** → **Secrets and variables** → **Actions**
2. 点击 **New repository secret**
3. 添加上述三个 Secrets

---

## 方法二：P12 证书 + Provisioning Profile

如果你的团队使用传统证书方式。

### 创建 P12 证书

1. 在 Mac 上打开 **钥匙串访问**
2. 请求证书 → **从证书颁发机构请求证书**
3. 保存 `.certSigningRequest` 文件
4. 在 Apple Developer Portal 创建 iOS Distribution 证书
5. 下载并安装证书
6. 导出为 P12 文件（记得设置密码）

### 创建 Provisioning Profile

1. 进入 [Apple Developer Portal](https://developer.apple.com/)
2. **Certificates, Identifiers & Profiles** → **Profiles**
3. 创建 **App Store** 或 **Ad Hoc** 类型 Profile
4. 选择你的 App ID 和证书
5. 下载 `.mobileprovision` 文件

### 需要配置的 Secrets

| Secret Name | 说明 |
|------------|------|
| `P12_CERTIFICATE` | Base64 编码的 P12 证书文件 |
| `P12_PASSWORD` | 导出 P12 时设置的密码 |
| `PROVISIONING_PROFILE` | Base64 编码的 .mobileprovision 文件 |

### 将文件转换为 base64

**P12 证书:**
```bash
base64 -i certificate.p12
```

**Provisioning Profile:**
```bash
base64 -i Profile.mobileprovision
```

---

## 方法三：仅构建（不签名）

如果你只是想验证代码能否编译通过，可以不配置任何 Secrets。

工作流会使用 `CODE_SIGN_IDENTITY="-"` 构建不签名的版本。

**限制：**
- 构建产物不能安装到真机
- 只能用于模拟器测试或验证构建流程

---

## GitHub Variables（可选）

在 **Settings** → **Variables** → **Actions** 中配置：

| Variable Name | 说明 | 示例值 |
|-------------|------|--------|
| `BUNDLE_ID` | 应用 Bundle ID | `com.poopblock.russian` |
| `CODE_SIGN_STYLE` | 签名方式 | `Automatic` |
| `CODE_SIGN_IDENTITY` | 签名身份 | `-`（不签名）或 `Apple Distribution` |
| `DEVELOPMENT_TEAM` | 开发团队 ID | `XXXXXXXXXX` |

---

## 完整配置示例

### 使用 App Store Connect API Key

```bash
# 1. 转换密钥文件
base64 -i AuthKey_XXXXXXXXXX.p8
# 输出: MIGTAI44GHJK....

# 2. 在 GitHub Secrets 中添加:
APP_STORE_CONNECT_API_KEY_ID = XXXXXXXXXX
APP_STORE_CONNECT_API_KEY_ISSUER_ID = xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
APP_STORE_CONNECT_API_KEY_CONTENT = MIGTAI44GHJK....
```

### 使用 P12 证书

```bash
# 1. 转换证书文件
base64 -i certificate.p12
# 输出: MIISQwYJKoZIhvc...

# 2. 转换 Provisioning Profile
base64 -i Profile.mobileprovision
# 输出: MIIPlgYJKoZIhvc...

# 3. 在 GitHub Secrets 中添加:
P12_CERTIFICATE = MIISQwYJKoZIhvc...
P12_PASSWORD = your_p12_password
PROVISIONING_PROFILE = MIIPlgYJKoZIhvc...
```

---

## 验证配置

配置完成后，推送代码到 main 分支，GitHub Actions 会自动触发构建。

查看构建结果：
1. 进入 **Actions** 页面
2. 点击最新的 workflow run
3. 查看 **Build iOS App** job
4. 在 **Artifacts** 部分下载构建产物

---

## 常见问题

### Q: 构建失败 "No matching provisioning profile found"

**A:** 确保：
1. Provisioning Profile 与 Bundle ID 匹配
2. 证书未过期
3. 在 GitHub Secrets 中正确配置了 `PROVISIONING_PROFILE`

### Q: 构建失败 "No codesign identity found"

**A:** 确保：
1. 使用正确的签名身份名称（如 `Apple Distribution: Your Name (TEAMID)`）
2. 或者设置为 `-` 进行不签名构建

### Q: App Store Connect API Key 无效

**A:** 确保：
1. 密钥有 App Store Connect API 权限
2. 密钥未过期或被撤销
3. base64 编码正确（密钥内容是原始 .p8 文件，不是解压后的）

---

## 参考链接

- [GitHub Actions 文档](https://docs.github.com/cn/actions)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [XcodeGen 文档](https://github.com/yonaskolb/XcodeGen)
