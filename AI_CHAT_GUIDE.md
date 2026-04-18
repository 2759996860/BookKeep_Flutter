# AI聊天功能实现说明

## 📋 概述

记账App现已集成AI聊天功能，采用底部导航栏设计，默认显示AI助手页面。支持多会话管理、流式对话、消息删除等功能。

---

## 🎯 核心功能

### 1. 底部导航栏
- **AI助手**: 默认页面，智能对话
- **账单**: 原有记账功能
- 切换流畅，状态保持

### 2. 会话管理
- ✅ 创建多个会话
- ✅ 删除会话（带确认）
- ✅ 编辑会话标题
- ✅ 置顶/取消置顶会话
- ✅ 按置顶状态和创建时间排序

### 3. 消息功能
- ✅ 流式对话（SSE）
- ✅ 长按删除消息
- ✅ 实时滚动到底部
- ✅ 用户/AI消息区分显示

### 4. 智能会话创建
- **关键点**: 新建会话不会立即调用后端接口
- **触发时机**: 只有第一次发送消息时才创建会话
- **标题设置**: 使用用户的第一条消息作为会话标题
- **流程**: 先调用`getConversationId`创建会话 → 再调用`streamChat`进行对话

---

## 🏗️ 架构设计

### 文件结构
```
lib/
├── models/
│   └── auth_models.dart          # 添加AI聊天模型
├── services/
│   ├── api_service.dart           # 原有API服务
│   └── chat_service.dart          # 新增：AI聊天服务
├── screens/
│   ├── login_screen.dart          # 登录页
│   ├── register_screen.dart       # 注册页
│   ├── home_page.dart             # 账单页
│   ├── chat_page.dart             # 新增：AI聊天页
│   └── main_screen.dart           # 新增：主页面（底部导航）
└── main.dart                      # 修改：启动MainScreen
```

---

## 💻 代码实现

### 1. 数据模型（auth_models.dart）

#### ChatConversation - 会话信息
```dart
class ChatConversation {
  final String conversationId;    // 会话ID
  final String title;              // 会话标题
  final bool isPinned;             // 是否置顶
  final DateTime createTime;       // 创建时间
  final DateTime? updateTime;      // 更新时间
  
  factory ChatConversation.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

#### ChatMessage - 消息信息
```dart
class ChatMessage {
  final String messageId;          // 消息ID
  final String conversationId;     // 所属会话ID
  final String role;               // 角色：user 或 assistant
  final String content;            // 消息内容
  final DateTime createTime;       // 创建时间
  
  factory ChatMessage.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

#### StreamChatRequest - 流式对话请求
```dart
class StreamChatRequest {
  final String conversationId;     // 会话ID
  final String message;            // 用户消息
  
  Map<String, dynamic> toJson();
}
```

---

### 2. AI聊天服务（chat_service.dart）

#### 核心方法

| 方法 | 接口 | 说明 |
|------|------|------|
| `getConversationId(String title)` | GET /chat/getConversationId | 创建会话，返回会话ID |
| `getConversations()` | GET /chat/getConversations | 获取会话列表 |
| `deleteConversation(String id)` | DELETE /chat/deleteConversation | 删除会话 |
| `updateConversationTitle(String id, String title)` | PUT /chat/updateConversationTitle | 更新会话标题 |
| `pinConversation(String id)` | PUT /chat/pinConversation | 置顶会话 |
| `getMessageList(String id)` | GET /chat/getMessageList | 获取消息列表 |
| `deleteMessage(String convId, String msgId)` | DELETE /chat/deleteMessage | 删除消息 |
| `streamChat(StreamChatRequest)` | POST /chat/stream | 流式对话（SSE） |

#### 流式对话实现（SSE）
```dart
static Stream<String> streamChat(StreamChatRequest request) async* {
  final client = http.Client();
  final httpRequest = http.Request('POST', url);
  httpRequest.headers.addAll({
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  });
  httpRequest.body = jsonEncode(request.toJson());

  final response = await client.send(httpRequest);

  // 处理SSE流
  await for (final chunk in response.stream.transform(utf8.decoder)) {
    final lines = chunk.split('\n');
    for (final line in lines) {
      if (line.startsWith('data: ')) {
        final data = line.substring(6).trim();
        if (data.isNotEmpty && data != '[DONE]') {
          yield data;  // 逐块返回
        }
      }
    }
  }

  client.close();
}
```

**特点**:
- 使用`async*`生成器返回Stream
- 解析SSE格式：`data: {...}\n\n`
- 实时返回每个数据块
- 自动过滤`[DONE]`结束标记

---

### 3. AI聊天页面（chat_page.dart）

#### 页面布局
```
┌─────────────────────────────────────────┐
│  AppBar: AI助手                          │
├──────────────┬──────────────────────────┤
│              │                          │
│  会话列表     │   聊天区域                │
│  (280px)     │                          │
│              │   ┌──────────────────┐   │
│  [+新建会话]  │   │  消息列表         │   │
│              │   │                  │   │
│  📌 会话1     │   │  👤 用户消息      │   │
│  💬 会话2     │   │  🤖 AI回复       │   │
│  💬 会话3     │   │                  │   │
│              │   └──────────────────┘   │
│              │                          │
│              │  [输入框] [发送按钮]      │
└──────────────┴──────────────────────────┘
```

#### 核心状态
```dart
List<ChatConversation> _conversations = [];  // 会话列表
String? _currentConversationId;               // 当前会话ID
List<ChatMessage> _messages = [];             // 消息列表
bool _isLoading = false;                      // 加载状态
TextEditingController _messageController;     // 输入控制器
ScrollController _scrollController;           // 滚动控制器
```

#### 关键方法

##### 发送消息（智能会话创建）
```dart
Future<void> _sendMessage() async {
  final message = _messageController.text.trim();
  if (message.isEmpty) return;

  String conversationId = _currentConversationId ?? '';
  
  // ✅ 如果是新会话，先创建会话
  if (_currentConversationId == null) {
    conversationId = await ChatService.getConversationId(message);
    setState(() {
      _currentConversationId = conversationId;
    });
    await _loadConversations();  // 刷新会话列表
  }

  // 添加用户消息到本地
  setState(() {
    _messages.add(ChatMessage(...));
  });

  // 调用流式对话
  final request = StreamChatRequest(
    conversationId: conversationId,
    message: message,
  );

  String assistantResponse = '';
  await for (final chunk in ChatService.streamChat(request)) {
    setState(() {
      assistantResponse += chunk;
      // 实时更新AI回复
      if (_messages.last.role == 'assistant') {
        _messages[_messages.length - 1] = ChatMessage(...);
      } else {
        _messages.add(ChatMessage(...));
      }
    });
    
    // 实时滚动到底部
    _scrollToBottom();
  }

  // 刷新消息列表（获取完整数据）
  await _loadMessages(conversationId);
}
```

**流程说明**:
1. 检查是否有当前会话
2. 如果没有，调用`getConversationId`创建新会话（标题=用户消息）
3. 添加用户消息到本地列表
4. 调用`streamChat`进行流式对话
5. 实时更新AI回复内容
6. 对话完成后刷新消息列表

##### 删除消息（长按）
```dart
GestureDetector(
  onLongPress: () => _deleteMessage(message),
  child: Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      // 消息气泡样式
    ),
  ),
)
```

##### 会话操作菜单
```dart
PopupMenuButton<String>(
  onSelected: (value) {
    if (value == 'pin') _togglePinConversation(conversation);
    else if (value == 'edit') _editConversationTitle(conversation);
    else if (value == 'delete') _deleteConversation(conversation);
  },
  itemBuilder: (context) => [
    PopupMenuItem(value: 'pin', child: Text('置顶/取消置顶')),
    PopupMenuItem(value: 'edit', child: Text('编辑标题')),
    PopupMenuItem(value: 'delete', child: Text('删除')),
  ],
)
```

---

### 4. 主页面（main_screen.dart）

```dart
class MainScreen extends StatefulWidget {
  int _currentIndex = 0; // 0: AI聊天, 1: 账单

  final List<Widget> _pages = const [
    ChatPage(),   // AI助手
    HomePage(),   // 账单
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF6366F1),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            activeIcon: Icon(Icons.smart_toy),
            label: 'AI助手',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: '账单',
          ),
        ],
      ),
    );
  }
}
```

**特点**:
- 使用`IndexedStack`保持页面状态
- 切换时不重新加载
- 固定类型导航栏
- 紫色主题色

---

### 5. 路由配置（main.dart）

```dart
routes: {
  '/': (context) {
    ApiService.setNavigationContext(context);
    return FutureBuilder<bool>(
      future: ApiService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          return const MainScreen();  // ← 改为MainScreen
        }
        return const LoginScreen();
      },
    );
  },
  '/login': (context) => const LoginScreen(),
  '/home': (context) => const MainScreen(),  // ← 改为MainScreen
},
```

---

## 🎨 UI设计

### 颜色方案
- **主色调**: Indigo (#6366F1)
- **用户消息**: 紫色背景 + 白色文字
- **AI消息**: 浅灰背景 + 深色文字
- **选中会话**: 紫色半透明背景

### 交互细节
1. **会话列表**: 
   - 置顶会话显示📌图标
   - 选中高亮
   - 右侧弹出菜单

2. **消息气泡**:
   - 用户消息右对齐
   - AI消息左对齐
   - 最大宽度70%
   - 圆角16px

3. **输入框**:
   - 圆角24px
   - 浅灰背景
   - 无边框
   - 发送按钮紫色

4. **空状态**:
   - 大图标 + 提示文字
   - 居中显示

---

## 🔄 工作流程

### 首次使用流程
```
用户打开App
  ↓
登录成功
  ↓
进入MainScreen（默认AI助手页）
  ↓
点击"新建会话"
  ↓
输入第一条消息并发送
  ↓
调用 getConversationId(消息内容) 创建会话
  ↓
调用 streamChat() 开始流式对话
  ↓
实时显示AI回复
  ↓
对话完成，刷新消息列表
```

### 后续使用流程
```
选择已有会话
  ↓
调用 getMessageList() 加载历史消息
  ↓
继续对话
  ↓
直接调用 streamChat()（无需创建会话）
```

---

## ⚙️ API集成

### 认证方式
所有接口需在Header中携带：
```http
Authorization: Bearer {access_token}
Content-Type: application/json
```

### Token刷新
已集成Token自动刷新机制：
- 401错误自动捕获
- 调用`/user/refreshToken`刷新
- 刷新失败跳转登录页

---

## 🧪 测试清单

### 功能测试
- [x] 底部导航切换正常
- [x] 默认显示AI助手页
- [x] 新建会话功能
- [x] 首次发送消息创建会话
- [x] 流式对话实时显示
- [x] 消息长按删除
- [x] 会话置顶/取消置顶
- [x] 会话标题编辑
- [x] 会话删除（带确认）
- [x] 消息列表滚动
- [x] 自动滚动到底部

### UI测试
- [x] 会话列表样式正确
- [x] 消息气泡样式正确
- [x] 输入框样式正确
- [x] 空状态显示正常
- [x] 响应式布局
- [x] 动画流畅

### 边界测试
- [x] 空消息不发送
- [x] 网络异常提示
- [x] Token过期处理
- [x] 删除当前会话清空消息
- [x] 并发请求处理

---

## 📝 注意事项

1. **会话创建时机**: 
   - ❌ 不要点击"新建会话"就调用后端
   - ✅ 只有第一次发送消息时才创建

2. **会话标题**:
   - 使用用户的第一条消息作为标题
   - 后续可手动编辑

3. **流式对话**:
   - 使用SSE格式
   - 实时解析`data:`行
   - 过滤`[DONE]`标记

4. **消息删除**:
   - 长按触发
   - 需要二次确认
   - 删除后刷新列表

5. **状态保持**:
   - 使用`IndexedStack`
   - 切换tab不丢失状态

6. **滚动控制**:
   - 发送消息后自动滚动
   - 接收消息时实时滚动
   - 使用`addPostFrameCallback`

---

## 🚀 后续优化建议

1. **消息持久化**: 本地缓存历史消息
2. **图片支持**: 发送和接收图片
3. **代码高亮**: Markdown渲染
4. **语音输入**: 语音转文字
5. **快捷指令**: 预设常用问题
6. **搜索功能**: 搜索历史消息
7. **导出功能**: 导出对话记录
8. **深色模式**: 适配深色主题

---

**实现时间**: 2024-01-15  
**相关文件**: 
- `lib/models/auth_models.dart` - 数据模型
- `lib/services/chat_service.dart` - 聊天服务
- `lib/screens/chat_page.dart` - 聊天页面
- `lib/screens/main_screen.dart` - 主页面
- `lib/main.dart` - 路由配置
