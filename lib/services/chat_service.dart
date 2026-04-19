import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_models.dart';
import './api_service.dart';
import '../config/app_config.dart';

/// SSE事件类型
enum SseEventType { content, metadata }

/// SSE事件数据
class SseEvent {
  final SseEventType type;
  final String data;

  SseEvent({required this.type, required this.data});
}

/// AI聊天服务
class ChatService {
  // 使用统一配置的AI聊天API地址
  static const String baseUrl = AppConfig.chatApiPrefix;

  /// ✅ 执行带Token自动刷新的HTTP请求
  static Future<http.Response> _executeWithTokenRefresh(
    Future<http.Response> Function() requestFunc,
  ) async {
    try {
      final response = await requestFunc();
      
      // 检查是否是401错误（Token过期）
      if (response.statusCode == 401) {
        print('🔄 ChatService: 检测到401错误，尝试刷新Token...');
        
        // 调用ApiService的Token刷新逻辑
        final refreshSuccess = await ApiService.refreshToken();
        
        if (refreshSuccess) {
          print('✅ ChatService: Token刷新成功，准备重试原请求...');
          
          // ✅ 关键修复：刷新成功后，必须重新调用requestFunc来获取新的Token
          // 因为requestFunc是一个闭包，每次调用都会重新获取最新的AccessToken
          final retryResponse = await requestFunc();
          
          print('📊 重试结果 - 状态码: ${retryResponse.statusCode}');
          
          if (retryResponse.statusCode == 401) {
            // 如果重试仍然401，说明RefreshToken也失效了
            print('❌ ChatService: 重试后仍为401，RefreshToken可能已失效');
            await ApiService.clearTokens();
            throw Exception('登录已过期，请重新登录');
          }
          
          return retryResponse;
        } else {
          // 刷新失败，清除Token并抛出异常
          print('❌ ChatService: Token刷新失败，清除本地Token');
          await ApiService.clearTokens();
          throw Exception('登录已过期，请重新登录');
        }
      }
      
      return response;
    } catch (e) {
      print('❌ ChatService: HTTP请求异常: $e');
      rethrow;
    }
  }

  /// 获取或创建会话ID（首次发送消息时调用）
  static Future<String> getConversationId(String title) async {
    try {
      final url = Uri.parse('$baseUrl/getConversationId').replace(
        queryParameters: {'title': title},
      );

      print('创建会话: $url');

      // ✅ 使用带Token自动刷新的封装方法
      final response = await _executeWithTokenRefresh(() async {
        final token = await ApiService.getAccessToken();
        
        if (token == null || token.isEmpty) {
          throw Exception('未登录');
        }
        
        return await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));
      });

      print('创建会话响应状态码: ${response.statusCode}');
      print('创建会话响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final apiResponse = AuthResponse.fromJson(jsonResponse);
        
        if (apiResponse.code == 200 && apiResponse.data != null) {
          return apiResponse.data as String;
        } else {
          throw Exception('创建会话失败: ${apiResponse.message}');
        }
      } else {
        throw Exception('创建会话请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('创建会话异常: $e');
      rethrow;
    }
  }

  /// 获取会话列表
  static Future<List<ChatConversation>> getConversations() async {
    try {
      print('ChatService: 开始获取会话列表...');

      final url = Uri.parse('$baseUrl/getConversations');
      print('ChatService: 请求URL: $url');

      final startTime = DateTime.now();
      
      // ✅ 使用带Token自动刷新的封装方法
      final response = await _executeWithTokenRefresh(() async {
        final token = await ApiService.getAccessToken();
        
        if (token == null || token.isEmpty) {
          throw Exception('未登录');
        }
        
        return await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
      });

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('ChatService: 响应状态码: ${response.statusCode}, 耗时: ${duration.inMilliseconds}ms');
      print('ChatService: 响应内容: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final apiResponse = AuthResponse.fromJson(jsonResponse);
        
        if (apiResponse.code == 200 && apiResponse.data != null) {
          final List<dynamic> data = apiResponse.data;
          print('ChatService: 解析到 ${data.length} 个会话');
          return data.map((item) => ChatConversation.fromJson(item)).toList();
        } else {
          throw Exception('获取会话列表失败: ${apiResponse.message}');
        }
      } else {
        throw Exception('获取会话列表请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('ChatService: 获取会话列表异常: $e');
      rethrow;
    }
  }

  /// 删除会话
  static Future<void> deleteConversation(String conversationId) async {
    try {
      final url = Uri.parse('$baseUrl/deleteConversation').replace(
        queryParameters: {'conversationId': conversationId},
      );

      print('删除会话: $url');

      // ✅ 使用带Token自动刷新的封装方法
      final response = await _executeWithTokenRefresh(() async {
        final token = await ApiService.getAccessToken();
        
        if (token == null || token.isEmpty) {
          throw Exception('未登录');
        }
        
        return await http.delete(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));
      });

      print('删除会话响应状态码: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('删除会话请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('删除会话异常: $e');
      rethrow;
    }
  }

  /// 更新会话标题
  static Future<void> updateConversationTitle(String conversationId, String title) async {
    try {
      final url = Uri.parse('$baseUrl/updateConversationTitle').replace(
        queryParameters: {
          'conversationId': conversationId,
          'title': title,
        },
      );

      print('更新会话标题: $url');

      // ✅ 使用带Token自动刷新的封装方法
      final response = await _executeWithTokenRefresh(() async {
        final token = await ApiService.getAccessToken();
        
        if (token == null || token.isEmpty) {
          throw Exception('未登录');
        }
        
        return await http.put(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));
      });

      print('更新会话标题响应状态码: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('更新会话标题请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('更新会话标题异常: $e');
      rethrow;
    }
  }

  /// 置顶会话
  static Future<void> pinConversation(String conversationId) async {
    try {
      final url = Uri.parse('$baseUrl/pinConversation').replace(
        queryParameters: {'conversationId': conversationId},
      );

      print('置顶会话: $url');

      // ✅ 使用带Token自动刷新的封装方法
      final response = await _executeWithTokenRefresh(() async {
        final token = await ApiService.getAccessToken();
        
        if (token == null || token.isEmpty) {
          throw Exception('未登录');
        }
        
        return await http.put(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));
      });

      print('置顶会话响应状态码: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('置顶会话请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('置顶会话异常: $e');
      rethrow;
    }
  }

  /// 获取消息列表（分页）
  static Future<Map<String, dynamic>> getMessageList({
    required String conversationId,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    try {
      print('ChatService: 开始获取消息列表...');

      final url = Uri.parse('$baseUrl/getMessageList').replace(
        queryParameters: {
          'conversationId': conversationId,
          'pageNum': pageNum.toString(),
          'pageSize': pageSize.toString(),
        },
      );

      print('ChatService: 请求URL: $url');

      final startTime = DateTime.now();
      
      // ✅ 使用带Token自动刷新的封装方法
      final response = await _executeWithTokenRefresh(() async {
        final token = await ApiService.getAccessToken();
        
        if (token == null || token.isEmpty) {
          throw Exception('未登录');
        }
        
        return await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
      });

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('ChatService: 响应状态码: ${response.statusCode}, 耗时: ${duration.inMilliseconds}ms');
      print('ChatService: 响应内容: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final apiResponse = AuthResponse.fromJson(jsonResponse);
        
        if (apiResponse.code == 200 && apiResponse.data != null) {
          final data = apiResponse.data as Map<String, dynamic>;
          final List<dynamic> records = data['records'] ?? [];
          
          print('ChatService: 解析到 ${records.length} 条消息');
          print('ChatService: 分页信息 - total: ${data['total']}, current: ${data['current']}, pages: ${data['pages']}');
          
          return {
            'messages': records.map((item) => ChatMessage.fromJson(item)).toList(),
            'total': data['total'] as int? ?? 0,
            'current': data['current'] as int? ?? 1,
            'pages': data['pages'] as int? ?? 1,
            'size': data['size'] as int? ?? 20,
          };
        } else {
          throw Exception('获取消息列表失败: ${apiResponse.message}');
        }
      } else {
        throw Exception('获取消息列表请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('ChatService: 获取消息列表异常: $e');
      rethrow;
    }
  }

  /// 删除消息
  static Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      final url = Uri.parse('$baseUrl/deleteMessage').replace(
        queryParameters: {
          'conversationId': conversationId,
          'messageId': messageId,
        },
      );

      print('删除消息: $url');

      // ✅ 使用带Token自动刷新的封装方法
      final response = await _executeWithTokenRefresh(() async {
        final token = await ApiService.getAccessToken();
        
        if (token == null || token.isEmpty) {
          throw Exception('未登录');
        }
        
        return await http.delete(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 30));
      });

      print('删除消息响应状态码: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('删除消息请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('删除消息异常: $e');
      rethrow;
    }
  }

  static Stream<SseEvent> streamChat(StreamChatRequest request) async* {
    try {
      final token = await ApiService.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('未登录');
      }

      final url = Uri.parse('$baseUrl/stream');

      print('开始流式对话: $url');
      print('请求参数: ${jsonEncode(request.toJson())}');

      final client = http.Client();
      final httpRequest = http.Request('POST', url);
      httpRequest.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });
      httpRequest.body = jsonEncode(request.toJson());

      final response = await client.send(httpRequest);

      print('流式对话响应状态码: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('流式对话请求失败: ${response.statusCode}');
      }

      // ✅ 处理SSE流 - 支持metadata事件
      StringBuffer buffer = StringBuffer();
      String? currentEvent; // 当前事件类型
      
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        print('📥 收到原始chunk: ${chunk.length} bytes');
        
        buffer.write(chunk);
        
        final content = buffer.toString();
        final lines = content.split('\n');
        
        if (content.endsWith('\n')) {
          buffer.clear();
        } else {
          buffer.clear();
          buffer.write(lines.last);
          lines.removeLast();
        }
        
        for (final line in lines) {
          print('🔍 解析行: "$line" (长度: ${line.length})');
          final trimmedLine = line.trim();
          
          if (trimmedLine.isEmpty) {
            print('   ⚪ 空行，跳过');
            continue;
          }
          
          // 检查是否是event行
          if (trimmedLine.startsWith('event:')) {
            currentEvent = trimmedLine.substring(6).trim();
            print('   🏷️ 检测到事件类型: $currentEvent');
            continue;
          }
          
          // 检查是否是data行
          if (trimmedLine.startsWith('data:')) {
            String data = trimmedLine.substring(5).trim();
            
            print('   📄 检测到数据行，内容长度: ${data.length}');
            
            // 跳过[DONE]标记
            if (data == '[DONE]') {
              print('   ⏹️ 检测到[DONE]标记');
              continue;
            }
            
            print('   📄 数据内容预览: ${data.length > 100 ? data.substring(0, 100) + "..." : data}');
            print('   📄 当前事件类型: $currentEvent');
            
            // 如果是metadata事件，解析JSON
            if (currentEvent == 'metadata') {
              print('📦 收到metadata事件: $data');
              yield SseEvent(type: SseEventType.metadata, data: data);
              currentEvent = null; // 重置事件类型
            } else {
              // 普通内容
              yield SseEvent(type: SseEventType.content, data: data);
            }
          } else {
            // 不是data:开头，也不是event:开头，可能是纯文本或其他格式
            print('   ❓ 非标准SSE格式行，尝试作为内容处理');
            if (!trimmedLine.startsWith(':')) { // 不是注释
              yield SseEvent(type: SseEventType.content, data: trimmedLine);
            }
          }
        }
      }
      
      print('✅ SSE流已结束，共处理所有chunk');
      client.close();
    } catch (e) {
      print('流式对话异常: $e');
      rethrow;
    }
  }
}
