# Token自动刷新机制实现说明

## 📋 功能概述

实现了**无感知的Token自动刷新机制**，当API请求因AccessToken过期返回401错误时：
1. ✅ 自动使用RefreshToken获取新的AccessToken
2. ✅ 用户无需任何操作，体验流畅
3. ✅ Token刷新成功后自动重试原请求
4. ✅ 如果RefreshToken也失效，自动跳转到登录页

## 🔧 技术实现

### 1. 核心组件

#### ApiService 新增方法

```dart
// 设置导航上下文（在应用启动时调用）
static void setNavigationContext(BuildContext context)

// 刷新Token（无感知刷新）
static Future<bool> refreshToken()

// 处理401错误，尝试刷新Token
static Future<bool> handleUnauthorized()

// 跳转到登录页面
static void _navigateToLogin()

// 执行带认证的HTTP请求（自动处理Token刷新）
static Future<http.Response> _executeWithAuthRetry(
  Future<http.Response> Function() requestFunc,
)
```

### 2. 工作流程

```
┌─────────────┐
│  发起API请求  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ 收到响应     │
└──────┬──────┘
       │
       ▼
  状态码是401？
   ╱        ╲
  否         是
  │          │
  │          ▼
  │    ┌──────────────────┐
  │    │ 检查是否正在刷新  │
  │    └────┬─────────┬───┘
  │         │         │
  │        是         否
  │         │         │
  │         ▼         ▼
  │    ┌────────┐ ┌──────────────┐
  │    │等待刷新│ │调用refreshToken│
  │    │完成    │ └──────┬───────┘
  │    └────┬───┘        │
  │         │            ▼
  │         │      刷新成功？
  │         │       ╱      ╲
  │         │      是        否
  │         │      │         │
  │         ▼      ▼         ▼
  │    ┌────────┐ ┌──────┐ ┌──────────┐
  │    │重试请求│ │保存  │ │清除Token  │
  │    └────────┘ │新Token│ │跳转登录页│
  │               └──┬───┘ └──────────┘
  │                  │
  │                  ▼
  │            ┌────────┐
  │            │重试请求│
  │            └────────┘
  ▼
返回结果
```

### 3. 并发控制机制

使用 `_isRefreshing` 标志位防止多个请求同时刷新Token：

```dart
static bool _isRefreshing = false;

// 如果正在刷新，等待最多10秒
if (_isRefreshing) {
  for (int i = 0; i < 20; i++) {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_isRefreshing) break;
  }
  return true;
}
```

### 4. 已集成的API

所有需要认证的账单相关API都已集成自动刷新机制：

- ✅ `queryBillDetails()` - 查询账单明细
- ✅ `addBillDetails()` - 新增账单
- ✅ `deleteBillDetails()` - 删除账单
- ✅ `updateBillDetails()` - 更新账单
- ✅ `queryBillCategory()` - 查询分类

### 5. 使用方法

#### 初始化导航上下文

在 `main.dart` 中已配置：

```dart
routes: {
  '/': (context) {
    ApiService.setNavigationContext(context); // 初始化
    // ...
  },
  '/login': (context) {
    ApiService.setNavigationContext(context);
    return const LoginScreen();
  },
  '/home': (context) {
    ApiService.setNavigationContext(context);
    return const HomePage();
  },
},
```

#### API调用（无需额外代码）

```dart
// 正常使用，自动处理Token刷新
final bills = await ApiService.queryBillDetails(request);
```

## 🔍 关键代码位置

| 功能 | 文件路径 | 方法名 |
|------|---------|--------|
| Token刷新 | `lib/services/api_service.dart` | `refreshToken()` |
| 401处理 | `lib/services/api_service.dart` | `handleUnauthorized()` |
| 自动重试 | `lib/services/api_service.dart` | `_executeWithAuthRetry()` |
| 跳转登录 | `lib/services/api_service.dart` | `_navigateToLogin()` |
| 路由配置 | `lib/main.dart` | `routes` |

## 📝 RefreshToken接口规范

**接口地址**: `POST /user/refreshToken`

**请求参数**:
```json
{
  "refreshToken": "your_refresh_token_here"
}
```

**响应格式**:
```json
{
  "code": 200,
  "message": "成功",
  "data": {
    "accessToken": "new_access_token",
    "refreshToken": "new_refresh_token",
    "expiresTime": 1234567890
  }
}
```

## ⚠️ 注意事项

1. **必须初始化导航上下文**: 确保在应用启动时调用 `ApiService.setNavigationContext(context)`

2. **超时时间**: Token刷新等待超时为10秒

3. **错误提示**: Token失效时显示 "登录已过期，请重新登录"

4. **日志输出**: 所有Token刷新过程都有详细的日志输出，方便调试

5. **并发安全**: 同一时间只允许一个Token刷新请求，其他请求会等待

## 🧪 测试场景

### 场景1: AccessToken过期
1. 等待AccessToken过期
2. 发起任意API请求
3. **预期结果**: 自动刷新Token并重试，用户无感知

### 场景2: RefreshToken也过期
1. 等待RefreshToken也过期
2. 发起任意API请求
3. **预期结果**: 清除Token并跳转到登录页

### 场景3: 并发请求
1. 同时发起多个API请求
2. AccessToken过期
3. **预期结果**: 只刷新一次Token，所有请求都重试成功

## 🎯 优势

1. **用户体验好**: 完全无感知，不需要用户手动刷新或重新登录
2. **代码简洁**: 业务代码无需关心Token刷新逻辑
3. **安全可靠**: 并发控制避免重复刷新，失败自动跳转登录
4. **易于维护**: 统一的刷新机制，便于后续扩展
