# 🔧 网络错误排查指南

## ❌ 常见网络错误原因

### 1. API 地址配置错误（最常见）

当前配置：`http://localhost:8080`

**问题**: `localhost` 在不同环境下指向不同：
- 在 Android 模拟器中，`localhost` 指向模拟器本身，不是你的电脑
- 在真机上，`localhost` 指向手机本身
- 只有在 iOS 模拟器中，`localhost` 才指向你的电脑

### ✅ 正确的 API 地址配置

根据你的运行环境修改 `lib/services/api_service.dart` 中的 `baseUrl`：

#### **情况1: Android 模拟器**
```dart
static const String baseUrl = 'http://10.0.2.2:8080';
```
> `10.0.2.2` 是 Android 模拟器访问宿主机的特殊地址

#### **情况2: iOS 模拟器**
```dart
static const String baseUrl = 'http://localhost:8080';
```

#### **情况3: 真机设备（Android/iOS）**
```dart
// 先查看你电脑的 IP 地址
// Windows: 打开命令提示符，输入 ipconfig
// Mac/Linux: 打开终端，输入 ifconfig 或 ip addr

static const String baseUrl = 'http://192.168.1.100:8080';  // 替换为你的实际IP
```

#### **情况4: API 部署在服务器上**
```dart
static const String baseUrl = 'https://api.yourdomain.com';
```

---

## 🔍 如何获取电脑 IP 地址

### Windows:
1. 按 `Win + R`
2. 输入 `cmd` 回车
3. 输入 `ipconfig`
4. 找到 `IPv4 地址`，通常是 `192.168.x.x` 或 `10.x.x.x`

### Mac:
1. 打开终端
2. 输入 `ifconfig | grep "inet "`
3. 找到类似 `192.168.1.100` 的地址

### Linux:
1. 打开终端
2. 输入 `ip addr show` 或 `ifconfig`
3. 找到你的网络接口的 IP 地址

---

## 📝 完整排查步骤

### 步骤 1: 确认 API 服务正在运行

在浏览器中访问：
```
http://localhost:8080/user/register
```

如果能看到响应（即使是错误），说明服务在运行。

### 步骤 2: 检查防火墙

确保防火墙允许 8080 端口的连接：

**Windows:**
1. 打开"Windows Defender 防火墙"
2. 点击"高级设置"
3. 添加入站规则，允许 8080 端口

**Mac:**
1. 系统偏好设置 > 安全性与隐私 > 防火墙
2. 允许 Java/你的API服务通过

### 步骤 3: 测试网络连接

在你的电脑上打开命令提示符/终端：

```bash
# 测试 API 是否可访问
curl -X POST http://localhost:8080/user/register \
  -H "Content-Type: application/json" \
  -d '{"userId":"test","userName":"测试","password":"Test@1234"}'
```

### 步骤 4: 修改 Flutter 代码

编辑 `lib/services/api_service.dart`：

```dart
// 根据你的环境选择正确的地址
static const String baseUrl = 'http://10.0.2.2:8080';  // Android 模拟器
// static const String baseUrl = 'http://localhost:8080';  // iOS 模拟器
// static const String baseUrl = 'http://192.168.1.100:8080';  // 真机（替换IP）
```

### 步骤 5: 重新运行应用

```bash
flutter clean
flutter pub get
flutter run
```

### 步骤 6: 查看详细日志

现在代码已经改进，会在控制台输出详细的请求和响应信息：
- 请求的完整 URL
- 发送的请求数据
- 响应状态码
- 响应内容
- 具体的错误信息

---

## 🐛 常见错误及解决方案

### 错误 1: "Connection refused"
**原因**: API 服务未启动或端口错误
**解决**: 
1. 确认 API 服务正在运行
2. 检查端口号是否正确（8080）
3. 尝试在浏览器访问 `http://localhost:8080`

### 错误 2: "Failed host lookup"
**原因**: DNS 解析失败或地址错误
**解决**:
1. 检查 API 地址是否正确
2. 如果使用 IP 地址，确认 IP 是否正确
3. 确认设备和电脑在同一网络

### 错误 3: "Connection timed out"
**原因**: 防火墙阻止或网络不通
**解决**:
1. 检查防火墙设置
2. 确认设备和电脑在同一局域网
3. 尝试 ping 目标地址

### 错误 4: "Cleartext HTTP traffic not permitted"
**原因**: Android 默认不允许 HTTP（只允许 HTTPS）
**解决**: 已在 AndroidManifest.xml 中添加 `android:usesCleartextTraffic="true"`

---

## 📱 快速测试方案

### 方案 A: 使用 ngrok（推荐用于真机测试）

1. 下载 ngrok: https://ngrok.com/
2. 运行命令:
   ```bash
   ngrok http 8080
   ```
3. 复制生成的 URL（如 `https://abc123.ngrok.io`）
4. 修改代码:
   ```dart
   static const String baseUrl = 'https://abc123.ngrok.io';
   ```

### 方案 B: 使用 Android 模拟器

最简单的方式，只需修改为：
```dart
static const String baseUrl = 'http://10.0.2.2:8080';
```

### 方案 C: 使用 iOS 模拟器

```dart
static const String baseUrl = 'http://localhost:8080';
```

---

## ✅ 验证配置是否成功

1. 运行应用
2. 打开注册页面
3. 填写表单并提交
4. 查看控制台输出：
   - 如果看到 "正在请求注册接口: ..." 和响应信息，说明配置正确
   - 如果看到详细错误信息，根据提示排查

---

## 🎯 推荐配置

**开发阶段（本地测试）:**
- Android 模拟器: `http://10.0.2.2:8080`
- iOS 模拟器: `http://localhost:8080`

**真机测试:**
- 使用 ngrok 或
- 使用电脑局域网 IP: `http://192.168.x.x:8080`

**生产环境:**
- 使用域名: `https://api.yourdomain.com`

---

## 📞 仍然有问题？

请提供以下信息：
1. 你使用的设备类型（Android 模拟器 / iOS 模拟器 / 真机）
2. 控制台的完整错误信息
3. API 服务是否正常响应（浏览器测试结果）
4. 你当前的 `baseUrl` 配置
