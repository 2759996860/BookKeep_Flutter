import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/auth_models.dart';
import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<ChatConversation> _conversations = [];
  String? _currentConversationId;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSidebarOpen = false; // ✅ 控制侧边栏展开/收起
  bool _isSidebarItemClicked = false; // ✅ 标记是否点击了侧边栏项目，防止误触发主内容的onTap
  bool _shouldScrollToBottom = false; // ✅ 标记是否需要滚动到底部（仅在切换对话或首次进入时）
  
  // ✅ 分页相关状态
  int _currentPage = 1; // 当前页码
  int _totalPages = 1; // 总页数
  int _totalMessages = 0; // 总消息数
  bool _isLoadingMore = false; // 是否正在加载更多
  bool _hasMoreMessages = true; // 是否还有更多消息
  bool _isPageStateInvalidated = false; // ✅ 标记分页状态是否已失效（发送新消息后）
  bool _isWaitingForAI = false; // ✅ 标记是否正在等待AI回复
  
  TextEditingController _messageController = TextEditingController();
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    
    // 加载会话列表
    _loadConversations();
  }

  /// ✅ 页面重新激活时（从其他Tab返回），如果需要则滚动到底部
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ✅ 当页面可见且有消息且标记为需要滚动时，触发滚动
    if (_shouldScrollToBottom && mounted && _currentConversationId != null && _messages.isNotEmpty) {
      print('页面激活，检测到需要滚动');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _scrollController.hasClients) {
              // ✅ 关键优化：检测内容是否超出可视区域
              final maxScroll = _scrollController.position.maxScrollExtent;
              
              if (maxScroll > 0) {
                // 内容超出屏幕，滚动到底部
                print('执行滚动到底部，maxScroll: $maxScroll');
                _scrollController.animateTo(
                  0,  // reverse: true时，0是底部
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              } else {
                // 内容未超出屏幕，强制定位到顶部
                print('ℹ️ 内容未超出屏幕，定位到顶部，maxScroll: $maxScroll');
                _scrollController.jumpTo(maxScroll);
              }
              
              setState(() {
                _shouldScrollToBottom = false;
              });
            }
          });
        }
      });
    }
  }

  /// ✅ 滚动到底部的通用方法
  void _scrollToBottom() {
    if (_currentConversationId != null && _messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          print('执行滚动控制，消息数: ${_messages.length}');
          
          // ✅ 关键优化：检测内容是否超出可视区域
          final maxScroll = _scrollController.position.maxScrollExtent;
          
          if (maxScroll > 0) {
            // 内容超出可视区域，滚动到底部（reverse: true时，0是底部）
            _scrollController.animateTo(
              0,  // reverse: true时，0是底部
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
            print('✅ 内容超出屏幕，已滚动到底部');
          } else {
            // 内容未超出屏幕，强制滚动到顶部（maxScrollExtent位置）
            // reverse: true时，maxScrollExtent是视觉顶部
            _scrollController.jumpTo(maxScroll);
            print('ℹ️ 内容未超出屏幕，已定位到顶部，maxScroll: $maxScroll');
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 加载会话列表
  Future<void> _loadConversations() async {
    print('开始加载会话列表...');
    
    // ✅ 防止重复加载
    if (_isLoading) {
      print('正在加载中，跳过重复请求');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      print('调用 ChatService.getConversations()...');
      final startTime = DateTime.now();
      
      final conversations = await ChatService.getConversations();
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('会话列表加载完成，耗时: ${duration.inMilliseconds}ms, 数量: ${conversations.length}');
      
      // ✅ 使用mounted检查，防止组件销毁后更新状态
      if (!mounted) {
        print('组件已销毁，取消更新');
        return;
      }
      
      setState(() {
        _conversations = conversations;
        _isLoading = false;

        // ✅ 自动选择更新时间最新的会话（仅在首次加载且未选择会话时）
        if (_conversations.isNotEmpty && _currentConversationId == null) {
          // 按更新时间倒序排序，取第一个
          _conversations.sort((a, b) => b.updatedTime.compareTo(a.updatedTime));
          _currentConversationId = _conversations.first.id;
          print('自动选择会话: $_currentConversationId');
        } else if (_conversations.isEmpty) {
          // ✅ 当没有会话列表时，保持在"新会话"状态（_currentConversationId 为 null）
          print('没有会话列表，显示新会话欢迎界面');
          _currentConversationId = null;
          _messages = [];
        }
      });
      
      // ✅ 在setState之后异步加载消息，避免阻塞UI
      if (_currentConversationId != null) {
        print('开始加载消息列表...');
        _loadMessages(_currentConversationId!);
      }
    } catch (e) {
      print('加载会话失败: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      _showError('加载会话失败: $e');
    }
  }

  /// 加载更多消息
  Future<void> _loadMoreMessages() async {
    if (_currentConversationId == null) return;
    
    print('\n📥 ========== 开始加载更多消息 ==========');
    print('   当前页: $_currentPage');
    print('   总页数: $_totalPages');
    print('   还有更多: $_hasMoreMessages');
    print('   正在加载: $_isLoadingMore');
    print('   当前消息数: ${_messages.length}');
    
    await _loadMessages(_currentConversationId!, isLoadMore: true);
    
    print('📥 ========== 加载更多消息完成 ==========\n');
  }

  /// 加载消息列表（支持分页）
  Future<void> _loadMessages(String conversationId, {bool isLoadMore = false}) async {
    print('开始加载消息列表，会话ID: $conversationId, 是否加载更多: $isLoadMore');
    
    // ✅ 如果是首次加载，重置分页状态
    if (!isLoadMore) {
      setState(() {
        _currentConversationId = conversationId;
        _currentPage = 1;
        _hasMoreMessages = true;
        _messages = []; // 清空旧消息
        _isPageStateInvalidated = false; // ✅ 重置分页失效标记
        print('🔄 首次加载，重置所有分页状态');
      });
    } else {
      // 加载更多时，检查是否已经在加载中或没有更多数据
      if (_isLoadingMore || !_hasMoreMessages) {
        print('⚠️ 跳过加载：正在加载中=$_isLoadingMore 或没有更多数据=$_hasMoreMessages');
        return;
      }
      
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final startTime = DateTime.now();
      
      // ✅ 关键修复：如果分页状态已失效（发送了新消息），需要重新从第1页加载
      int pageNumToRequest = _currentPage;
      
      if (isLoadMore && _isPageStateInvalidated) {
        print('⚠️ 检测到分页状态已失效，重新计算页码...');
        
        // 策略：保留本地最新的20条消息，从后端重新加载剩余的旧消息
        // 计算需要跳过多少条消息
        int localMessageCount = _messages.length;
        int skipCount = localMessageCount; // 跳过本地已有的所有消息
        
        // 计算应该请求的页码（假设每页20条）
        // 例如：本地有25条，skipCount=25，应该从第2页开始（跳过前20条）
        pageNumToRequest = (skipCount ~/ 20) + 1;
        
        print('   本地消息数: $localMessageCount');
        print('   跳过数量: $skipCount');
        print('   请求页码: $pageNumToRequest');
        
        // 重置失效标记
        _isPageStateInvalidated = false;
      }
      
      // ✅ 调用分页接口
      final result = await ChatService.getMessageList(
        conversationId: conversationId,
        pageNum: pageNumToRequest,
        pageSize: 20,
      );
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      final List<ChatMessage> newMessages = result['messages'] as List<ChatMessage>;
      final int total = result['total'] as int;
      final int current = result['current'] as int;
      final int pages = result['pages'] as int;
      
      print('消息列表加载完成，耗时: ${duration.inMilliseconds}ms, 本页数量: ${newMessages.length}, 总数: $total');
      
      if (!mounted) return;
      
      setState(() {
        if (isLoadMore) {
          // ✅ 加载更多：追加到列表前端（因为是reverse: true，所以insert到开头）
          _messages.insertAll(0, newMessages);
          
          // ✅ 关键修复：更新当前页码为实际请求的页码+1
          _currentPage = pageNumToRequest + 1;
          
          print('📥 加载更多完成 - 新消息数: ${newMessages.length}, 总消息数: ${_messages.length}');
        } else {
          // ✅ 首次加载：直接赋值
          _messages = newMessages;
          _currentPage = 2; // 下次加载更多时从第2页开始
        }
        
        // 更新分页信息
        _totalMessages = total;
        _totalPages = pages;
        _hasMoreMessages = current < pages;
        _isLoadingMore = false;
        
        // ✅ 仅在首次加载时设置滚动标记
        if (!isLoadMore) {
          _shouldScrollToBottom = true;
        }
      });

      print('分页状态 - 当前页: $_currentPage, 总页数: $_totalPages, 还有更多: $_hasMoreMessages');
      
      // ✅ 滚动逻辑已移至 build 方法中统一处理，通过 _shouldScrollToBottom 标记触发
    } catch (e) {
      print('加载消息失败: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isLoadingMore = false;
      });
      
      if (!isLoadMore) {
        _showError('加载消息失败: $e');
      } else {
        _showMessage('加载更多失败，请重试');
      }
    }
  }

  /// 发送消息
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    // ✅ 检查是否正在等待AI回复
    if (_isWaitingForAI) {
      _showMessage('请等待AI回复完成后再发送新消息');
      return;
    }

    setState(() {
      _messageController.clear();
      _isWaitingForAI = true; // ✅ 设置等待标志
    });

    try {
      String conversationId = _currentConversationId ?? '';

      // 如果是新会话，先创建会话
      if (_currentConversationId == null) {
        conversationId = await ChatService.getConversationId(message);
        setState(() {
          _currentConversationId = conversationId;
        });
        // ✅ 不立即刷新会话列表，避免清空本地消息导致页面闪烁
        // 会在流式对话完成后统一刷新
      }

      // 添加用户消息到本地
      setState(() {
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        
        // ✅ 修复：由于ListView设置了reverse: true，新消息应该插入到列表开头，这样才会显示在底部
        _messages.insert(0, ChatMessage(
          id: tempId,
          conversationId: conversationId,
          messageType: 'user',
          content: message,
          sortOrder: _messages.length,
          createdTime: DateTime.now(),
          updatedTime: DateTime.now(),
        ));
        
        print('   当前本地消息数: ${_messages.length}');
        print('   临时消息ID: $tempId');
      });

      // 滚动到底部
      _scrollToBottom();

      // 调用流式对话
      final request = StreamChatRequest(
        conversationId: conversationId,
        message: message,
      );

      print('开始流式对话，会话ID: $conversationId, 消息: $message');

      String assistantResponse = '';
      bool hasAddedAssistantMessage = false;
      String? userMessageId;
      String? assistantMessageId;
      
      try {
        await for (final event in ChatService.streamChat(request)) {
          // 处理metadata事件
          if (event.type == SseEventType.metadata) {
            try {
              final metadata = jsonDecode(event.data);
              userMessageId = metadata['userMessageId'];
              assistantMessageId = metadata['assistantMessageId'];
              print('✅ 收到消息ID - 用户: $userMessageId, AI: $assistantMessageId');
              
              // ✅ 如果AI消息已创建，立即更新其ID
              if (assistantMessageId != null && hasAddedAssistantMessage && _messages.isNotEmpty) {
                setState(() {
                  final oldId = _messages[0].id;
                  _messages[0] = ChatMessage(
                    id: assistantMessageId!,
                    conversationId: _messages[0].conversationId,
                    messageType: _messages[0].messageType,
                    content: _messages[0].content,
                    sortOrder: _messages[0].sortOrder,
                    createdTime: _messages[0].createdTime,
                    updatedTime: _messages[0].updatedTime,
                  );
                  print('✅ 更新AI消息ID: $oldId -> $assistantMessageId');
                });
              }
            } catch (e) {
              print('❌ 解析metadata失败: $e');
            }
            continue;
          }
          
          // 只处理内容事件
          if (event.type != SseEventType.content) {
            continue;
          }
          
          final content = event.data;
          
          if (content.isEmpty || content == '[DONE]') {
            continue;
          }
          
          setState(() {
            assistantResponse += content;
            
            if (!hasAddedAssistantMessage) {
              _messages.insert(0, ChatMessage(
                id: assistantMessageId ?? 'assistant_${DateTime.now().millisecondsSinceEpoch}',
                conversationId: conversationId,
                messageType: 'assistant',
                content: assistantResponse,
                sortOrder: _messages.length,
                createdTime: DateTime.now(),
                updatedTime: DateTime.now(),
              ));
              
              hasAddedAssistantMessage = true;
            } else {
              if (_messages.isNotEmpty) {
                _messages[0] = ChatMessage(
                  id: _messages[0].id,
                  conversationId: conversationId,
                  messageType: 'assistant',
                  content: assistantResponse,
                  sortOrder: _messages[0].sortOrder,
                  createdTime: _messages[0].createdTime,
                  updatedTime: DateTime.now(),
                );
              }
            }
          });

          _scrollToBottom();
        }
        
        print('流式对话完成，总长度: ${assistantResponse.length}');
        
        // ✅ 如果收到了用户消息ID，更新本地用户消息的ID
        if (userMessageId != null && _messages.isNotEmpty) {
          setState(() {
            // 查找刚发送的用户消息（第一条，因为是reverse）
            final userMsgIndex = _messages.indexWhere((m) => 
              m.messageType == 'user' && m.id.startsWith('temp_')
            );
            
            if (userMsgIndex != -1) {
              final oldId = _messages[userMsgIndex].id;
              _messages[userMsgIndex] = ChatMessage(
                id: userMessageId!,
                conversationId: _messages[userMsgIndex].conversationId,
                messageType: _messages[userMsgIndex].messageType,
                content: _messages[userMsgIndex].content,
                sortOrder: _messages[userMsgIndex].sortOrder,
                createdTime: _messages[userMsgIndex].createdTime,
                updatedTime: _messages[userMsgIndex].updatedTime,
              );
              print('✅ 更新用户消息ID: $oldId -> $userMessageId');
            }
          });
        }
      } catch (e) {
        print('流式对话异常: $e');
        _showError('AI回复失败: $e');
      } finally {
        // ✅ 关键修复：无论成功或失败，都要清除等待标志
        if (mounted) {
          setState(() {
            _isWaitingForAI = false;
          });
          print('🔄 AI回复结束，已清除等待标志');
        }
      }
      
      // ✅ 如果是新创建的会话，异步刷新会话列表以显示新会话（不阻塞UI）
      if (_conversations.isEmpty || !_conversations.any((c) => c.id == conversationId)) {
        print('检测到新会话，后台刷新会话列表...');
        _loadConversations().then((_) {
          print('会话列表已刷新');
        }).catchError((e) {
          print('刷新会话列表失败: $e');
        });
      }
    } catch (e) {
      print('❌ 发送消息异常: $e');
      _showError('发送消息失败: $e');
      
      // ✅ 外层异常也要清除标志
      if (mounted) {
        setState(() {
          _isWaitingForAI = false;
        });
      }
    }
  }

  /// 删除会话
  Future<void> _deleteConversation(ChatConversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除会话"${conversation.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ChatService.deleteConversation(conversation.id);

        if (_currentConversationId == conversation.id) {
          setState(() {
            _currentConversationId = null;
            _messages = [];
          });
        }

        _showMessage('删除成功');
        await _loadConversations();
      } catch (e) {
        _showError('删除失败: $e');
      }
    }
  }

  /// 置顶/取消置顶会话
  Future<void> _togglePinConversation(ChatConversation conversation) async {
    try {
      await ChatService.pinConversation(conversation.id);
      _showMessage(conversation.isPinned ? '已取消置顶' : '已置顶');
      await _loadConversations();
    } catch (e) {
      _showError('操作失败: $e');
    }
  }

  /// 编辑会话标题
  Future<void> _editConversationTitle(ChatConversation conversation) async {
    final controller = TextEditingController(text: conversation.title);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑标题'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '请输入新的标题'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await ChatService.updateConversationTitle(conversation.id, result);
        _showMessage('修改成功');
        await _loadConversations();
      } catch (e) {
        _showError('修改失败: $e');
      }
    }
  }

  /// ✅ 显示消息操作菜单（复制/删除）
  void _showMessageOptions(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 复制选项
            ListTile(
              leading: const Icon(Icons.copy, color: Color(0xFF80CBC4)),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(context);
                _copyMessage(message);
              },
            ),
            // 分隔线
            Divider(height: 1, color: Colors.grey.shade200),
            // 删除选项
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ 复制消息内容
  void _copyMessage(ChatMessage message) {
    // Flutter内置clipboard功能
    Clipboard.setData(ClipboardData(text: message.content));
    
    _showMessage('已复制到剪贴板');
    
    print('✅ 消息已复制，长度: ${message.content.length}');
  }

  /// 删除消息
  Future<void> _deleteMessage(ChatMessage message) async {
    // ✅ 优化：只显示消息内容的前50个字符作为预览
    final preview = message.content.length > 50 
        ? '${message.content.substring(0, 50)}...' 
        : message.content;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定要删除这条消息吗？',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"$preview"',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentConversationId != null) {
      try {
        print('🗑️ 准备删除消息 - ID: ${message.id}, 类型: ${message.messageType}');
        print('   内容预览: ${message.content.substring(0, message.content.length > 30 ? 30 : message.content.length)}...');
        
        // 调用后端删除接口
        await ChatService.deleteMessage(_currentConversationId!, message.id);
        
        // 从本地列表中移除
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
          _totalMessages--;
        });
        
        print('✅ 消息删除成功');
        _showMessage('删除成功');
      } catch (e) {
        print('❌ 删除消息失败: $e');
        print('   尝试删除的ID: ${message.id}');
        _showError('删除失败');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('ChatPage build called');

    // ✅ 仅在需要时滚动到底部（切换对话或首次进入）
    if (_shouldScrollToBottom && _currentConversationId != null && _messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && mounted) {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && _scrollController.hasClients) {
              // ✅ 关键优化：检测内容是否超出可视区域
              final maxScroll = _scrollController.position.maxScrollExtent;
              
              if (maxScroll > 0) {
                // 内容超出屏幕，滚动到底部
                print('build: 执行滚动到底部，消息数: ${_messages.length}, maxScroll: $maxScroll');
                _scrollController.animateTo(
                  0,  // reverse: true时，0是底部
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              } else {
                // 内容未超出屏幕，强制定位到顶部
                print('build: 内容未超出屏幕，定位到顶部，消息数: ${_messages.length}, maxScroll: $maxScroll');
                _scrollController.jumpTo(maxScroll);
              }
              
              // ✅ 滚动后重置标记
              setState(() {
                _shouldScrollToBottom = false;
              });
            }
          });
        }
      });
    }

    return Scaffold(
      // ✅ 添加AppBar避免与系统状态栏冲突
      appBar: AppBar(
        title: const Text(
          'AI助手',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF80CBC4),
          ),
        ),
        centerTitle: true, // ✅ 标题居中
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(
            _isSidebarOpen ? Icons.menu_open : Icons.menu,
            color: const Color(0xFF80CBC4),
          ),
          onPressed: () {
            // ✅ 点击时只切换显示/隐藏状态，不重复加载数据
            setState(() {
              _isSidebarOpen = !_isSidebarOpen;
            });
          },

          tooltip: _isSidebarOpen ? '收起会话列表' : '展开会话列表',
        ),
      ),
      body: Stack(
        children: [
          // ✅ 左侧会话列表（背景层，使用AnimatedOpacity控制显隐）
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 260,
            child: IgnorePointer(
              ignoring: !_isSidebarOpen, // ✅ 侧边栏关闭时忽略所有手势
              child: AnimatedOpacity(
                opacity: _isSidebarOpen ? 1.0 : 0.0, // ✅ 淡入淡出动画
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: Column(
                children: [
                  // ✅ 新会话按钮
                  Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF80CBC4),
                          const Color(0xFFB39DDB),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF80CBC4).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // ✅ 设置标记，防止触发主内容的onTap
                          _isSidebarItemClicked = true;
                          setState(() {
                            _currentConversationId = null;
                            _messages = [];
                            _isSidebarOpen = false;
                          });
                          // ✅ 延迟重置标记
                          Future.delayed(const Duration(milliseconds: 300), () {
                            _isSidebarItemClicked = false;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                '新会话',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 会话列表
                  Expanded(
                    child: _isLoading && _conversations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF80CBC4),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '加载中...',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _conversations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '暂无会话',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '点击顶部"新会话"按钮创建',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) {
                              final conversation = _conversations[index];
                              final isSelected =
                                  _currentConversationId == conversation.id;

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: [
                                            const Color(0xFF80CBC4).withOpacity(0.1),
                                            const Color(0xFFB39DDB).withOpacity(0.1),
                                          ],
                                        )
                                      : null,
                                  color: isSelected ? null : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF80CBC4)
                                        : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isSelected
                                            ? [
                                                const Color(0xFF80CBC4),
                                                const Color(0xFFB39DDB),
                                              ]
                                            : [
                                                Colors.grey.shade300,
                                                Colors.grey.shade400,
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.chat : Icons.chat_bubble_outline,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    conversation.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 14,
                                      color: isSelected ? const Color(0xFF80CBC4) : Colors.black87,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      DateFormat('MM-dd HH:mm').format(conversation.updatedTime.toLocal()),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? const Color(0xFF80CBC4).withOpacity(0.7)
                                            : Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      size: 18,
                                      color: isSelected ? const Color(0xFF80CBC4) : Colors.grey.shade600,
                                    ),
                                    onSelected: (value) {
                                      if (value == 'pin') {
                                        _togglePinConversation(conversation);
                                      } else if (value == 'edit') {
                                        _editConversationTitle(conversation);
                                      } else if (value == 'delete') {
                                        _deleteConversation(conversation);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'pin',
                                        child: Row(
                                          children: [
                                            Icon(
                                              conversation.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                              size: 18,
                                              color: const Color(0xFF80CBC4),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(conversation.isPinned ? '取消置顶' : '置顶'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.edit, size: 18, color: Color(0xFF80CBC4)),
                                            const SizedBox(width: 8),
                                            const Text('编辑标题'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete, size: 18, color: Colors.red),
                                            const SizedBox(width: 8),
                                            const Text('删除', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    // ✅ 设置标记，防止触发主内容的onTap
                                    _isSidebarItemClicked = true;
                                    _loadMessages(conversation.id);
                                    setState(() {
                                      _isSidebarOpen = false;
                                    });
                                    // ✅ 延迟重置标记
                                    Future.delayed(const Duration(milliseconds: 300), () {
                                      if (mounted) {
                                        _isSidebarItemClicked = false;
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ), // ✅ Container 结束
              ), // ✅ AnimatedOpacity 结束
            ), // ✅ IgnorePointer 结束
          ), // ✅ Positioned 结束

        // ✅ 右侧聊天区域（顶层，可移动）
      Positioned.fill(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          transform: Matrix4.translationValues(
            _isSidebarOpen ? 260.0 : 0.0, // ✅ 侧边栏打开时向右移动260px
            0,
            0,
          ),
          child: GestureDetector(
            // ✅ 添加左滑手势检测，关闭侧边栏
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              if (_isSidebarOpen && details.primaryVelocity! < -500) {
                setState(() {
                  _isSidebarOpen = false;
                });
              }
            },
            onTap: () {
              // ✅ 只有当侧边栏打开且点击的是主内容区域时才关闭
              if (_isSidebarOpen) {
                print('检测到点击主内容区域，关闭侧边栏');
                setState(() {
                  _isSidebarOpen = false;
                });
              }
            },
            child: Column(
              children: [
                Expanded(
                  child: _currentConversationId == null
                      ? _buildNewChatView() // ✅ 直接显示可输入的对话界面
                      : Column(
                          children: [
                            // 消息列表 - 占据更多空间
                            Expanded(
                              child: Align(
                                alignment: Alignment.topCenter, // ✅ 关键：让ListView从顶部对齐
                                child: NotificationListener<ScrollNotification>(
                                  onNotification: (ScrollNotification scrollInfo) {
                                    // ✅ 修复：reverse: true时，maxScrollExtent才是顶部（旧消息端）
                                    if (scrollInfo is ScrollEndNotification &&
                                        scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 50 &&  // 接近顶部
                                        _hasMoreMessages && 
                                        !_isLoadingMore &&
                                        _messages.isNotEmpty) {
                                      print('📢 触发上拉加载更多 - 滚动位置: ${scrollInfo.metrics.pixels}, maxScrollExtent: ${scrollInfo.metrics.maxScrollExtent}');
                                      _loadMoreMessages();
                                    }
                                    return false;
                                  },
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.all(20), // ✅ 增加内边距
                                    reverse: true, // ✅ 反转列表，让最新消息在底部
                                    shrinkWrap: true, // ✅ 收缩包装，根据内容调整大小
                                    physics: const BouncingScrollPhysics(), // ✅ 弹性滚动效果
                                    itemCount: _messages.length + (_isLoadingMore ? 1 : 0), // ✅ 加载更多时增加一个加载项
                                    itemBuilder: (context, index) {
                                      // ✅ 如果是加载项，显示加载提示
                                      if (index == _messages.length) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(
                                                      Color(0xFF80CBC4),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  '加载中...',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      final message = _messages[index];
                                      final isUser = message.messageType == 'user';

                                      return Align(
                                        alignment: isUser
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: GestureDetector(
                                          onLongPress: () {
                                            // ✅ 添加轻微震动反馈
                                            HapticFeedback.lightImpact();
                                            _showMessageOptions(context, message);
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 16,
                                            ), // ✅ 增加间距
                                            constraints: BoxConstraints(
                                              maxWidth:
                                                  MediaQuery.of(context).size.width *
                                                      0.75, // ✅ 最大宽度75%
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 14,
                                            ), // ✅ 增加内边距
                                            decoration: BoxDecoration(
                                              color: isUser
                                                  ? const Color(0xFF80CBC4)
                                                  : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(
                                                18,
                                              ), // ✅ 增加圆角
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(
                                                    0.05,
                                                  ),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              message.content,
                                              style: TextStyle(
                                                color: isUser
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: 15,
                                                height: 1.5, // ✅ 增加行高
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),

                            // 输入框区域 - 美化设计
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                20,
                              ), // ✅ 增加内边距
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, -3),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center, // ✅ 垂直居中对齐
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 50, // ✅ 固定输入框高度
                                      child: TextField(
                                        controller: _messageController,
                                        enabled: !_isWaitingForAI, // ✅ 等待AI回复时禁用输入
                                        maxLines: 1, // ✅ 强制单行
                                        minLines: 1,
                                        decoration: InputDecoration(
                                          hintText: _isWaitingForAI ? 'AI正在回复中...' : '输入消息...', // ✅ 动态提示文字
                                          hintStyle: TextStyle(
                                            color: _isWaitingForAI ? Colors.grey.shade300 : Colors.grey.shade400,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 14,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF80CBC4),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        onSubmitted: (_) => _sendMessage(),
                                      ),
                                    ),
                                  ), // ✅ Expanded 结束
                                  const SizedBox(width: 12),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF80CBC4),
                                          const Color(0xFFB39DDB),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF80CBC4,
                                          ).withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      onPressed: _isWaitingForAI ? null : _sendMessage, // ✅ 等待AI回复时禁用
                                      icon: _isWaitingForAI 
                                        ? SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.send, size: 22),
                                      color: Colors.white,
                                      style: IconButton.styleFrom(
                                        backgroundColor: _isWaitingForAI ? Colors.grey.shade400 : Colors.transparent,
                                        shadowColor: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ), // ✅ Expanded 结束
              ],
            ),
          ), // ✅ GestureDetector 结束
        ), // ✅ AnimatedContainer 结束
      ), // ✅ Positioned.fill 结束
    ], // ✅ Stack children 结束
  ), // ✅ Stack 结束
); // ✅ Scaffold 结束
  }

  /// 新对话视图（可以直接发消息）
  Widget _buildNewChatView() {
    return Column(
      children: [
        // 中间提示区域
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, const Color(0xFF80CBC4).withOpacity(0.03)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // AI图标
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF80CBC4), const Color(0xFFB39DDB)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF80CBC4).withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.smart_toy, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 20),

                  // 标题
                  const Text(
                    'AI 智能助手',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF80CBC4),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 副标题
                  Text(
                    '在下方输入消息开始对话',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 输入框区域 - 美化设计
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isWaitingForAI, // ✅ 等待AI回复时禁用输入
                    maxLines: 1,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: _isWaitingForAI ? 'AI正在回复中...' : '输入消息...', // ✅ 动态提示文字
                      hintStyle: TextStyle(
                        color: _isWaitingForAI ? Colors.grey.shade300 : Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFF80CBC4),
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF80CBC4), const Color(0xFFB39DDB)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF80CBC4).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _isWaitingForAI ? null : _sendMessage, // ✅ 等待AI回复时禁用
                  icon: _isWaitingForAI 
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send, size: 22),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: _isWaitingForAI ? Colors.grey.shade400 : Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 欢迎界面（新建会话时显示）
  Widget _buildWelcomeState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, const Color(0xFF80CBC4).withOpacity(0.05)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI图标
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF80CBC4), const Color(0xFFB39DDB)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF80CBC4).withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 32),

            // 标题
            const Text(
              'AI 智能助手',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF80CBC4),
              ),
            ),
            const SizedBox(height: 12),

            // 副标题
            Text(
              '开始新的对话吧',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 48),

            // 功能提示卡片
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildFeatureItem(
                    Icons.chat_bubble_outline,
                    '智能对话',
                    '与AI进行自然流畅的对话',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(
                    Icons.lightbulb_outline,
                    '创意灵感',
                    '获取灵感和创意建议',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(Icons.help_outline, '问题解答', '快速解答你的疑问'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 提示文字
            Text(
              '在下方输入框输入消息开始聊天',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),

            // ✅ 侧边栏提示
            if (!_isSidebarOpen)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF80CBC4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu, size: 16, color: const Color(0xFF80CBC4)),
                    const SizedBox(width: 8),
                    Text(
                      '点击左上角菜单按钮查看会话列表',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF80CBC4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 功能项
  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF80CBC4).withOpacity(0.1),
                const Color(0xFFB39DDB).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF80CBC4), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text('选择一个会话或创建新会话'));
  }
}
