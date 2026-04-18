# 记账本 Flutter 应用 - 账单功能说明

## 📱 功能概述

本项目已实现完整的记账本核心功能，包括用户认证和账单管理。

## ✨ 主要功能

### 1. 用户认证
- ✅ 用户注册（支持邮箱、手机号）
- ✅ 用户登录（Token自动保存）
- ✅ 自动登录（下次打开应用时）
- ✅ 密码强度验证

### 2. 账单管理
- ✅ 查询账单明细列表
- ✅ 按日期分组展示
- ✅ 滚动加载更多历史数据
- ✅ 月份切换查看不同月份
- ✅ 删除账单记录
- ✅ 查看账单详情
- ✅ 收支分类展示

## 📁 项目结构

```
lib/
├── models/
│   └── auth_models.dart          # 数据模型（包含账单相关模型）
├── screens/
│   ├── login_screen.dart         # 登录页面
│   ├── register_screen.dart      # 注册页面
│   └── home_page.dart            # 主页（账单列表）⭐新增
├── services/
│   └── api_service.dart          # API服务（包含账单API）
├── utils/
│   └── validator.dart            # 表单验证工具
└── main.dart                      # 应用入口
```

## 🔧 API配置

### 当前配置
- **Android模拟器**: `http://10.0.2.2:8080`
- **iOS模拟器**: `http://localhost:8080`
- **真机设备**: 需要修改为电脑局域网IP

### 修改方法
在 `lib/services/api_service.dart` 中修改 `baseUrl`:
```dart
static const String baseUrl = 'http://YOUR_IP:8080';
```

## 🚀 运行应用

### 1. 安装依赖
```bash
flutter pub get
```

### 2. 运行应用
```bash
flutter run
```

### 3. 构建发布版本
```bash
flutter build apk          # Android
flutter build ios          # iOS
flutter build web          # Web
```

## 📊 账单功能详解

### 主页特性

#### 1. 默认展示
- 登录后自动进入主页
- 默认显示**当天**的账单明细
- 如果当天没有数据，会显示"暂无账单记录"

#### 2. 滚动加载
- 向下滚动自动加载更多天的数据
- 每次加载一天的账单
- 最多加载到**本月1号**
- 到达边界后显示"已加载全部数据"

#### 3. 月份切换
- 点击AppBar左侧箭头：切换到上个月
- 点击AppBar右侧箭头：切换到下个月
- 最多可查询**近5年**的数据
- 超过5年会提示"最多只能查询近5年的数据"

#### 4. 账单展示
每条账单显示：
- 📌 分类图标（如 🍜 餐饮、🚗 交通）
- 📌 分类名称
- 📌 金额（支出红色 `-¥100.00`，收入绿色 `+¥5000.00`）
- 📌 备注信息

#### 5. 每日汇总
每个日期头部显示：
- 📅 日期（格式：yyyy-MM-dd）
- 💰 当日总支出（红色）
- 💵 当日总收入（绿色）

#### 6. 交互操作
- **点击账单项**: 查看详情对话框
- **长按账单项**: 弹出删除确认对话框
- **下拉刷新**: 点击AppBar刷新按钮重新加载

### 数据限制

1. **时间范围**: 最多查询近5年数据
2. **滚动限制**: 每个月份最多滚动到该月1号
3. **分页方式**: 按天加载，每天一次请求

## 🔐 Token管理

### Token存储
使用 `shared_preferences` 本地存储：
- `access_token`: 访问令牌
- `refresh_token`: 刷新令牌
- `expires_time`: 过期时间戳

### 自动携带
所有账单API请求自动在Header中携带：
```
Authorization: Bearer {access_token}
```

### 登出功能
调用以下方法清除Token：
```dart
await ApiService.clearTokens();
```

## 📝 API接口说明

### 统一响应格式
所有接口返回统一格式：
```json
{
  "code": 200,
  "message": "成功",
  "data": { ... }
}
```

**重要**: 实际业务数据都在 `data` 字段中！

### 账单相关接口

#### 1. 查询账单明细
- **URL**: `POST /bill/queryBillDetails`
- **参数**:
  ```json
  {
    "categoryId": "可选",
    "type": 1,  // 1-支出, 2-收入
    "startTime": "2024-01-01",
    "endTime": "2024-01-01",
    "sortType": 1
  }
  ```

#### 2. 新增账单
- **URL**: `POST /bill/addBillDetails`
- **参数**:
  ```json
  {
    "categoryId": "必填",
    "amount": 100.50,
    "recordTime": "2024-01-15",
    "remark": "可选"
  }
  ```

#### 3. 删除账单
- **URL**: `DELETE /bill/deleteBillDetails?detailsId=xxx`

#### 4. 更新账单
- **URL**: `POST /bill/updateBillDetails`
- **参数**:
  ```json
  {
    "billDetailsId": "必填",
    "categoryId": "可选",
    "amount": 可选,
    "recordTime": "可选",
    "remark": "可选"
  }
  ```

#### 5. 查询分类
- **URL**: `GET /bill/queryBillCategory?type=1`
- **参数**: `type=1`(支出) 或 `type=2`(收入)

## 🎨 UI设计

### 配色方案
- **主色调**: Indigo (#6366F1)
- **支出颜色**: Red (红色)
- **收入颜色**: Green (绿色)
- **背景渐变**: Indigo → Purple → Pink

### 组件特点
- 圆角卡片设计
- 阴影效果
- 渐变色背景
- Material Design 3风格

## 📦 静态资源

### 图片存放位置
```
assets/images/
```

### 使用方法
1. 将图片放入 `assets/images/` 目录
2. 在代码中使用：
   ```dart
   Image.asset('assets/images/logo.png')
   ```
3. 修改 `pubspec.yaml` 后需重新运行应用

## ⚠️ 注意事项

### Android配置
确保 `android/app/src/main/AndroidManifest.xml` 包含：
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<application
    android:usesCleartextTraffic="true"  <!-- 如果使用HTTP -->
    ...>
```

### 网络调试
- **Android模拟器**: 使用 `10.0.2.2` 访问宿主机
- **iOS模拟器**: 使用 `localhost`
- **真机调试**: 使用局域网IP，确保防火墙允许

### 开发建议
1. 添加账单功能待实现（TODO标记）
2. 编辑账单功能待实现（TODO标记）
3. 可以添加图表统计功能
4. 可以添加数据导出功能

## 🐛 常见问题

### 1. 无法连接到服务器
- 检查API服务是否启动
- 检查baseUrl配置是否正确
- 检查网络连接
- 检查防火墙设置

### 2. Token失效
- 清除缓存重新登录
- 检查后端Token有效期配置

### 3. 图片不显示
- 检查路径是否正确（区分大小写）
- 确认已在pubspec.yaml中声明
- 重新运行应用（热重载无效）

## 📞 技术支持

如有问题，请检查：
1. 控制台日志输出
2. 网络请求是否正常
3. API返回数据格式是否正确
4. Token是否有效

---

**版本**: 1.0.0  
**最后更新**: 2026-04-13
