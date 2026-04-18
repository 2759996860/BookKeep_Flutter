# API基础URL统一配置说明

## 📋 概述

为确保项目中所有后端API调用使用统一的基础URL，创建了集中配置文件 `AppConfig`，所有服务类都从该配置中获取API地址。

---

## 🎯 配置内容

### 文件位置
`lib/config/app_config.dart`

### 配置项
```dart
class AppConfig {
  /// API基础URL
  /// Android模拟器: http://10.0.2.2:8080
  /// iOS模拟器/真机: http://localhost:8080
  static const String apiBaseUrl = 'http://10.0.2.2:8080';
  
  /// 用户相关接口前缀
  static const String userApiPrefix = '$apiBaseUrl/user';
  
  /// 账单相关接口前缀
  static const String billApiPrefix = '$apiBaseUrl/bill';
  
  /// AI聊天相关接口前缀
  static const String chatApiPrefix = '$apiBaseUrl/chat';
}
```

---

## 💻 使用方式

### 1. ApiService（用户和账单接口）
```dart
import '../config/app_config.dart';

class ApiService {
  static const String baseUrl = AppConfig.apiBaseUrl;
  
  // 使用示例
  final url = '$baseUrl/user/login';           // http://10.0.2.2:8080/user/login
  final url = '$baseUrl/bill/queryBillDetails'; // http://10.0.2.2:8080/bill/queryBillDetails
}
```

### 2. ChatService（AI聊天接口）
```dart
import '../config/app_config.dart';

class ChatService {
  static const String baseUrl = AppConfig.chatApiPrefix;
  
  // 使用示例
  final url = '$baseUrl/getConversations';      // http://10.0.2.2:8080/chat/getConversations
  final url = '$baseUrl/stream';                // http://10.0.2.2:8080/chat/stream
}
```

---

## 🔄 修改记录

### 修改的文件

| 文件 | 修改内容 |
|------|---------|
| `lib/config/app_config.dart` | ✅ 新建：统一配置文件 |
| `lib/services/api_service.dart` | ✅ 导入AppConfig，使用 `AppConfig.apiBaseUrl` |
| `lib/services/chat_service.dart` | ✅ 导入AppConfig，使用 `AppConfig.chatApiPrefix` |

### 之前的配置
```dart
// api_service.dart
static const String baseUrl = 'http://10.0.2.2:8080';

// chat_service.dart
static const String baseUrl = 'http://localhost:8080/chat';  // ❌ 不一致
```

### 现在的配置
```dart
// app_config.dart
static const String apiBaseUrl = 'http://10.0.2.2:8080';
static const String chatApiPrefix = '$apiBaseUrl/chat';

// api_service.dart
static const String baseUrl = AppConfig.apiBaseUrl;  // ✅ 统一

// chat_service.dart
static const String baseUrl = AppConfig.chatApiPrefix;  // ✅ 统一
```

---

## 🌐 环境适配

### Android模拟器
```dart
static const String apiBaseUrl = 'http://10.0.2.2:8080';
```
**说明**: `10.0.2.2` 是Android模拟器访问宿主机的特殊地址

### iOS模拟器
```dart
static const String apiBaseUrl = 'http://localhost:8080';
```
**说明**: iOS模拟器可以直接访问localhost

### 真机设备
```dart
static const String apiBaseUrl = 'http://192.168.1.100:8080';
```
**说明**: 使用电脑的局域网IP地址

---

## 📝 切换环境

如需切换不同的运行环境，只需修改 `AppConfig.apiBaseUrl`：

```dart
// 开发环境（Android模拟器）
static const String apiBaseUrl = 'http://10.0.2.2:8080';

// 开发环境（iOS模拟器）
// static const String apiBaseUrl = 'http://localhost:8080';

// 测试环境
// static const String apiBaseUrl = 'http://test.example.com:8080';

// 生产环境
// static const String apiBaseUrl = 'https://api.example.com';
```

**注意**: 修改后需要重新编译运行应用。

---

## ✨ 优势

1. **统一管理**: 所有API地址集中在一处配置
2. **易于维护**: 修改地址只需改一个地方
3. **类型安全**: 使用常量，编译时检查
4. **清晰分类**: 不同模块有独立的前缀常量
5. **环境切换**: 方便在不同环境间切换

---

## 🧪 验证方法

### 1. 检查日志
运行应用后，查看控制台输出的API请求URL：
```
正在请求登录接口: http://10.0.2.2:8080/user/login
创建会话: http://10.0.2.2:8080/chat/getConversationId?title=xxx
```

### 2. 网络抓包
使用Charles或Fiddler抓包，确认所有请求都发送到 `http://10.0.2.2:8080`

### 3. 代码审查
搜索项目中是否还有硬编码的URL：
```bash
grep -r "localhost:8080" lib/
grep -r "10.0.2.2" lib/
```

应该只在 `app_config.dart` 中找到。

---

## ⚠️ 注意事项

1. **不要硬编码URL**: 所有新的服务类都应该从 `AppConfig` 获取URL
2. **保持一致性**: 确保所有接口使用相同的基础URL
3. **注释说明**: 在配置文件中注明不同环境的适用场景
4. **版本控制**: `app_config.dart` 应该纳入版本控制
5. **敏感信息**: 如果生产环境需要保密，考虑使用环境变量

---

## 📚 相关文件

- 配置文件: [`lib/config/app_config.dart`](file://d:\project\bookkeep_flutter\flutter_application_1\lib\config\app_config.dart)
- API服务: [`lib/services/api_service.dart`](file://d:\project\bookkeep_flutter\flutter_application_1\lib\services\api_service.dart)
- 聊天服务: [`lib/services/chat_service.dart`](file://d:\project\bookkeep_flutter\flutter_application_1\lib\services\chat_service.dart)

---

**更新时间**: 2024-01-15  
**当前配置**: `http://10.0.2.2:8080` (Android模拟器)
