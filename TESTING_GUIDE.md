# 记账本应用 - 快速测试指南

## 🧪 测试步骤

### 1️⃣ 准备工作

#### 启动后端服务
确保你的Spring Boot后端服务已启动在 `http://localhost:8080`

#### 检查配置
```dart
// lib/services/api_service.dart
static const String baseUrl = 'http://10.0.2.2:8080'; // Android模拟器
```

### 2️⃣ 运行应用

```bash
# 安装依赖
flutter pub get

# 运行应用（选择Android模拟器）
flutter run
```

### 3️⃣ 功能测试流程

#### 测试1: 用户注册
1. 点击"立即注册"
2. 填写注册信息：
   - 用户ID: test001
   - 用户名: 测试用户
   - 密码: Test@123456
   - 确认密码: Test@123456
   - 邮箱: test@example.com（可选）
3. 点击"注册"按钮
4. ✅ 预期：注册成功提示，自动跳转到登录页

#### 测试2: 用户登录
1. 输入用户ID: test001
2. 输入密码: Test@123456
3. 点击"登录"按钮
4. ✅ 预期：登录成功，自动进入主页

#### 测试3: 查看账单列表

**场景A: 有数据**
1. 登录后进入主页
2. ✅ 预期：显示今天的账单列表
3. ✅ 预期：每个日期头部显示收支汇总
4. ✅ 预期：支出显示红色，收入显示绿色

**场景B: 无数据**
1. 如果今天没有账单
2. ✅ 预期：显示"暂无账单记录"

#### 测试4: 滚动加载更多
1. 向下滚动列表
2. ✅ 预期：自动加载昨天的账单
3. ✅ 预期：继续滚动加载前天的账单
4. ✅ 预期：到达本月1号后停止加载
5. ✅ 预期：显示"已加载全部数据"

#### 测试5: 月份切换
1. 点击AppBar左侧箭头 ⬅️
2. ✅ 预期：切换到上个月，重新加载数据
3. 点击AppBar右侧箭头 ➡️
4. ✅ 预期：切换到下个月
5. 尝试切换到5年前的月份
6. ✅ 预期：提示"最多只能查询近5年的数据"

#### 测试6: 删除账单
1. 长按任意账单项
2. ✅ 预期：弹出删除确认对话框
3. 点击"删除"
4. ✅ 预期：删除成功提示，列表刷新

#### 测试7: 查看详情
1. 点击任意账单项
2. ✅ 预期：弹出详情对话框
3. ✅ 预期：显示金额、日期、备注、分类

#### 测试8: 刷新数据
1. 点击AppBar刷新图标 🔄
2. ✅ 预期：重新加载当前月份数据

#### 测试9: 自动登录
1. 关闭应用
2. 重新打开应用
3. ✅ 预期：直接进入主页，无需再次登录

#### 测试10: 登出功能（待实现）
```dart
// 可以在主页添加登出按钮测试
await ApiService.clearTokens();
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => const LoginScreen()),
);
```

### 4️⃣ API测试验证

#### 使用Postman/curl测试后端接口

**测试登录接口:**
```bash
curl -X POST http://localhost:8080/user/login \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test001",
    "password": "Test@123456"
  }'
```

**预期响应:**
```json
{
  "code": 200,
  "message": "成功",
  "data": {
    "accessToken": "xxx",
    "refreshToken": "xxx",
    "expiresTime": 1234567890
  }
}
```

**测试查询账单接口:**
```bash
curl -X POST http://localhost:8080/bill/queryBillDetails \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "startTime": "2024-01-15",
    "endTime": "2024-01-15",
    "sortType": 1
  }'
```

**预期响应:**
```json
{
  "code": 200,
  "message": "成功",
  "data": [
    {
      "detailsId": "uuid-1",
      "categoryId": "category-uuid",
      "amount": 100.50,
      "type": 1,
      "remark": "午餐",
      "recordTime": "2024-01-15",
      "name": "餐饮",
      "icon": "🍜"
    }
  ]
}
```

**测试查询分类接口:**
```bash
curl -X GET "http://localhost:8080/bill/queryBillCategory?type=1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### 5️⃣ 边界情况测试

#### 测试1: 网络异常
1. 断开网络连接
2. 尝试登录或加载账单
3. ✅ 预期：显示友好的错误提示

#### 测试2: Token过期
1. 等待Token过期（或手动修改过期时间）
2. 尝试查询账单
3. ✅ 预期：返回401错误或提示重新登录

#### 测试3: 空数据处理
1. 查询没有账单的日期
2. ✅ 预期：正常显示，不报错

#### 测试4: 大数据量
1. 某天的账单超过50条
2. ✅ 预期：列表流畅滚动，性能良好

#### 测试5: 特殊字符
1. 备注包含emoji或特殊字符
2. ✅ 预期：正常显示，不乱码

### 6️⃣ UI/UX测试

#### 视觉检查
- [ ] 渐变色背景正常显示
- [ ] 卡片阴影效果美观
- [ ] 颜色搭配协调
- [ ] 字体大小合适
- [ ] 间距合理

#### 交互检查
- [ ] 按钮点击有反馈
- [ ] 加载状态有指示器
- [ ] 滚动流畅无卡顿
- [ ] 对话框弹出动画自然
- [ ] 触摸区域足够大

#### 响应式检查
- [ ] 不同屏幕尺寸显示正常
- [ ] 横竖屏切换正常
- [ ] 文字不会溢出

### 7️⃣ 性能测试

#### 启动时间
```bash
flutter run --profile
```
- ✅ 冷启动时间 < 3秒
- ✅ 热启动时间 < 1秒

#### 内存使用
- 打开Flutter DevTools
- 监控内存使用情况
- ✅ 无明显内存泄漏

#### 滚动性能
- 快速滚动列表
- ✅ FPS保持在60左右
- ✅ 无卡顿现象

### 8️⃣ 调试技巧

#### 查看日志
```bash
flutter run -v  # 详细日志
```

#### 查看网络请求
在 `api_service.dart` 中已有print语句：
```dart
print('正在请求登录接口: $url');
print('响应状态码: ${response.statusCode}');
print('响应内容: ${response.body}');
```

#### 使用DevTools
```bash
flutter pub global activate devtools
flutter pub global run devtools
```

### 9️⃣ 常见问题排查

#### 问题1: 无法连接服务器
**症状**: 显示"无法连接到服务器"
**解决**:
1. 检查后端是否启动: `curl http://localhost:8080`
2. 检查baseUrl配置
3. Android模拟器使用 `10.0.2.2`
4. 检查防火墙设置

#### 问题2: Token无效
**症状**: 查询账单返回401
**解决**:
1. 清除缓存: `flutter clean`
2. 重新登录
3. 检查后端Token验证逻辑

#### 问题3: 图片不显示
**症状**: Image.asset报错
**解决**:
1. 检查pubspec.yaml配置
2. 确认文件路径正确
3. 重新运行应用

#### 问题4: 日期格式错误
**症状**: 账单时间显示异常
**解决**:
1. 检查intl包版本
2. 确认DateFormat格式字符串
3. 检查后端返回的时间格式

### 🔟 测试清单

完成以下检查确保功能正常：

**基础功能**
- [ ] 注册成功
- [ ] 登录成功
- [ ] 自动登录
- [ ] Token保存

**账单功能**
- [ ] 查询账单列表
- [ ] 按日期分组
- [ ] 滚动加载更多
- [ ] 月份切换
- [ ] 删除账单
- [ ] 查看详情
- [ ] 每日汇总显示

**UI/UX**
- [ ] 界面美观
- [ ] 交互流畅
- [ ] 错误提示友好
- [ ] 加载状态清晰

**性能**
- [ ] 启动速度快
- [ ] 滚动流畅
- [ ] 无内存泄漏
- [ ] 网络请求合理

**边界情况**
- [ ] 网络异常处理
- [ ] 空数据处理
- [ ] Token过期处理
- [ ] 5年限制检查

---

## 📊 测试报告模板

```markdown
测试日期: 2024-01-15
测试人员: XXX
测试环境: Android模拟器 / iOS模拟器 / 真机

✅ 通过的功能:
- 用户注册
- 用户登录
- ...

❌ 未通过的功能:
- XXX功能存在问题: ...

🐛 发现的Bug:
1. Bug描述: ...
   复现步骤: ...
   严重程度: 高/中/低

💡 改进建议:
- ...
```

---

**祝测试顺利！** 🎉
