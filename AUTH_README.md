# 记账本 - 认证系统

## 功能特性

### 1. 用户注册 (POST /user/register)
- **接口地址**: `/user/register`
- **请求方法**: POST
- **请求参数**:
  - `userId`: 用户ID (必填, 2-20字符, 字母数字特殊字符)
  - `userName`: 用户名 (必填, 2-20字符)
  - `password`: 密码 (必填, 8-20字符, 必须包含字母和数字)
  - `email`: 邮箱 (可选, 邮箱格式)
  - `phone`: 手机号 (可选, 手机号格式)

- **响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": null
}
```

### 2. 用户登录 (POST /user/login)
- **接口地址**: `/user/login`
- **请求方法**: POST
- **请求参数**:
  - `userId`: 用户ID (必填, 2-20字符)
  - `password`: 密码 (必填, 8-20字符, 字母数字特殊字符)

- **响应示例**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "accessToken": "eyJ...",
    "refreshToken": "eyJ...",
    "expiresTime": 1712345678000
  }
}
```

## 实现的功能

### ✅ 已完成
1. **美观的登录页面**
   - 渐变背景设计
   - 现代化的卡片式布局
   - 密码可见性切换
   - 表单验证
   - 加载状态显示

2. **美观的注册页面**
   - 渐变背景设计
   - 现代化的卡片式布局
   - 密码确认输入（两次密码输入）
   - 密码可见性切换
   - 完整的表单验证
   - 加载状态显示

3. **Token 管理**
   - 使用 `shared_preferences` 本地存储 Token
   - 自动保存 accessToken、refreshToken 和 expiresTime
   - 提供 Token 读取和清除方法
   - 登录状态检查

4. **表单验证**
   - 用户ID：2-20字符，支持字母、数字和特殊字符
   - 用户名：2-20字符
   - 密码：8-20字符，必须包含字母和数字
   - 确认密码：必须与密码一致
   - 邮箱：标准邮箱格式（可选）
   - 手机号：中国大陆手机号格式（可选）

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── models/
│   └── auth_models.dart        # 认证相关数据模型
├── services/
│   └── api_service.dart        # API 服务层
├── screens/
│   ├── login_screen.dart       # 登录页面
│   └── register_screen.dart    # 注册页面
└── utils/
    └── validator.dart          # 表单验证工具
```

## 配置说明

### 修改 API 基础 URL

在 `lib/services/api_service.dart` 文件中，修改 `baseUrl` 为你的实际 API 地址：

```dart
static const String baseUrl = 'http://your-api-domain.com';
```

例如：
```dart
static const String baseUrl = 'http://192.168.1.100:8080';
// 或
static const String baseUrl = 'https://api.yourdomain.com';
```

## 使用方法

### 运行项目
```bash
flutter pub get
flutter run
```

### 测试流程
1. 启动应用后进入登录页面
2. 点击"立即注册"跳转到注册页面
3. 填写注册信息（密码需要输入两次）
4. 注册成功后自动返回登录页面
5. 使用注册的账号登录
6. Token 会自动保存到本地

## Token 管理

### 获取 Token
```dart
// 检查是否已登录
bool isLoggedIn = await ApiService.isLoggedIn();

// 获取 Access Token
String? accessToken = await ApiService.getAccessToken();

// 获取 Refresh Token
String? refreshToken = await ApiService.getRefreshToken();
```

### 清除 Token（登出）
```dart
await ApiService.clearTokens();
```

## UI 特点

- 🎨 渐变色背景（紫色到粉色）
- 💎 现代化卡片设计
- ✨ 圆角边框和阴影效果
- 🔒 密码可见性切换
- ⏳ 加载状态动画
- 📱 响应式设计
- ✅ 实时表单验证
- 🎯 友好的错误提示

## 下一步建议

1. **添加主页**: 创建记账本的主界面
2. **Token 刷新**: 实现 refreshToken 自动刷新机制
3. **拦截器**: 添加 HTTP 拦截器自动携带 Token
4. **生物识别**: 添加指纹/面容登录
5. **记住密码**: 实现记住密码功能
6. **忘记密码**: 添加密码找回功能

## 依赖包

- `http`: ^1.2.0 - HTTP 请求
- `shared_preferences`: ^2.2.2 - 本地存储
- `flutter`: SDK - Flutter 框架

## 注意事项

1. 请确保 API 服务正常运行并可访问
2. 修改 `baseUrl` 为实际的 API 地址
3. 建议使用 HTTPS 以保证数据传输安全
4. Token 存储在本地，注意安全性
5. 生产环境建议添加加密存储
