import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../config/app_config.dart';

class ApiService {
  // 使用统一配置的API基础地址
  static const String baseUrl = AppConfig.apiBaseUrl;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _expiresTimeKey = 'expires_time';
  static const String _refreshExpiresTimeKey = 'refresh_expires_time';

  // Token刷新锁，防止并发刷新
  static bool _isRefreshing = false;
  static BuildContext? _contextForNavigation;

  /// 设置导航上下文（在应用启动时调用）
  static void setNavigationContext(BuildContext context) {
    _contextForNavigation = context;
  }

  /// 用户注册
  static Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final url = '$baseUrl/user/register';
      print('正在请求注册接口: $url');
      print('请求数据: ${jsonEncode(request.toJson())}');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('请求超时，请检查网络连接或API服务是否正常运行');
            },
          );

      print('响应状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(jsonDecode(response.body));
      } else {
        return AuthResponse(
          code: response.statusCode,
          message: '注册失败: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('注册请求异常: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('请求超时，请检查：\n1. API服务是否正常运行\n2. 网络连接是否正常\n3. API地址是否正确');
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw Exception(
          '无法连接到服务器，请检查：\n1. API服务是否启动\n2. API地址是否正确\n3. 防火墙是否阻止连接',
        );
      }
      throw Exception('网络错误: $e');
    }
  }

  /// 用户登录
  static Future<AuthResponse> login(LoginRequest request) async {
    try {
      final url = '$baseUrl/user/login';
      print('正在请求登录接口: $url');
      print('请求数据: ${jsonEncode(request.toJson())}');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('请求超时，请检查网络连接或API服务是否正常运行');
            },
          );

      print('响应状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final authResponse = AuthResponse.fromJson(jsonDecode(response.body));

        // ✅ 保存 token 信息，并修正过期时间为绝对时间戳
        if (authResponse.data != null) {
          final loginData = LoginData.fromJson(authResponse.data);
          
          // ✅ 关键修复：将相对时间转换为绝对时间戳
          // 后端返回的 expiresTime 和 refreshExpireTime 都是相对时间（毫秒）
          // 需要转换为绝对时间戳：当前时间 + 相对时间
          final now = DateTime.now().millisecondsSinceEpoch;
          final absoluteExpiresTime = now + loginData.expiresTime;
          final absoluteRefreshExpiresTime = loginData.refreshExpireTime != null 
              ? now + loginData.refreshExpireTime! 
              : null;
          
          print('🔧 Token时间转换:');
          print('   AccessToken相对时间: ${loginData.expiresTime}毫秒 (${loginData.expiresTime / 1000 / 60}分钟)');
          print('   AccessToken绝对过期时间: ${DateTime.fromMillisecondsSinceEpoch(absoluteExpiresTime)}');
          if (absoluteRefreshExpiresTime != null) {
            print('   RefreshToken相对时间: ${loginData.refreshExpireTime}毫秒 (${loginData.refreshExpireTime! / 1000 / 60}分钟)');
            print('   RefreshToken绝对过期时间: ${DateTime.fromMillisecondsSinceEpoch(absoluteRefreshExpiresTime)}');
          }
          
          // 创建新的LoginData对象，使用绝对时间戳
          final correctedLoginData = LoginData(
            accessToken: loginData.accessToken,
            refreshToken: loginData.refreshToken,
            expiresTime: absoluteExpiresTime, // ✅ 使用绝对时间戳
            refreshExpireTime: absoluteRefreshExpiresTime, // ✅ 使用绝对时间戳
          );
          
          await saveTokens(correctedLoginData);
        }

        return authResponse;
      } else {
        return AuthResponse(
          code: response.statusCode,
          message: '登录失败: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('登录请求异常: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('请求超时，请检查：\n1. API服务是否正常运行\n2. 网络连接是否正常\n3. API地址是否正确');
      } else if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw Exception(
          '无法连接到服务器，请检查：\n1. API服务是否启动\n2. API地址是否正确\n3. 防火墙是否阻止连接',
        );
      }
      throw Exception('网络错误: $e');
    }
  }

  /// 保存 Token 到本地存储
  static Future<void> saveTokens(LoginData loginData) async {
    try {
      print('\n💾 开始保存Token...');
      final prefs = await SharedPreferences.getInstance();
      
      // ✅ 先清除旧Token，避免使用上一个用户的Token
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_expiresTimeKey);
      await prefs.remove(_refreshExpiresTimeKey);
      print('   ✅ 已清除旧Token');
      
      // 再保存新Token
      await prefs.setString(_accessTokenKey, loginData.accessToken);
      await prefs.setString(_refreshTokenKey, loginData.refreshToken);
      await prefs.setInt(_expiresTimeKey, loginData.expiresTime);
      if (loginData.refreshExpireTime != null) {
        await prefs.setInt(_refreshExpiresTimeKey, loginData.refreshExpireTime!);
      }
      
      // 验证保存是否成功
      final savedAccessToken = prefs.getString(_accessTokenKey);
      final savedRefreshToken = prefs.getString(_refreshTokenKey);
      final savedExpiresTime = prefs.getInt(_expiresTimeKey);
      final savedRefreshExpiresTime = prefs.getInt(_refreshExpiresTimeKey);
      
      print('   ✅ Token保存成功:');
      print('      AccessToken: ${savedAccessToken != null ? "${savedAccessToken.substring(0, 20)}..." : "null"}');
      print('      RefreshToken: ${savedRefreshToken != null ? "${savedRefreshToken.substring(0, 20)}..." : "null"}');
      print('      AccessToken过期时间: $savedExpiresTime (${DateTime.fromMillisecondsSinceEpoch(savedExpiresTime ?? 0)})');
      if (savedRefreshExpiresTime != null) {
        print('      RefreshToken过期时间: $savedRefreshExpiresTime (${DateTime.fromMillisecondsSinceEpoch(savedRefreshExpiresTime)})');
      }
      print('💾 Token保存完成\n');
    } catch (e, stackTrace) {
      print('❌ Token保存失败: $e');
      print('堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  /// 获取 Access Token
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  /// 获取 Refresh Token
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// 检查是否已登录（Token过期时自动尝试刷新）
  static Future<bool> isLoggedIn() async {
    try {
      print('\n🔍 开始检查登录状态...');
      
      final accessToken = await getAccessToken();
      final storedRefreshToken = await getRefreshToken();
      final expiresTime = await getExpiresTime();
      final refreshExpiresTime = await getRefreshExpiresTime();

      print('📋 Token状态检查:');
      print('   AccessToken: ${accessToken != null ? "存在 (${accessToken.length}字符)" : "❌ 不存在"}');
      print('   RefreshToken: ${storedRefreshToken != null ? "存在 (${storedRefreshToken.length}字符)" : "❌ 不存在"}');
      print('   AccessToken过期时间: ${expiresTime != null ? DateTime.fromMillisecondsSinceEpoch(expiresTime).toString() : "❌ 不存在"}');
      if (refreshExpiresTime != null) {
        print('   RefreshToken过期时间: ${DateTime.fromMillisecondsSinceEpoch(refreshExpiresTime).toString()}');
      }
      
      // 检查基本数据是否存在
      if (accessToken == null || accessToken.isEmpty) {
        print('❌ AccessToken为空，未登录');
        return false;
      }
      
      if (expiresTime == null) {
        print('❌ AccessToken过期时间为空，未登录');
        return false;
      }

      // 检查AccessToken是否过期
      final now = DateTime.now().millisecondsSinceEpoch;
      final isExpired = now >= expiresTime;
      
      if (isExpired) {
        print('⚠️ AccessToken已过期');
        print('   当前时间: ${DateTime.fromMillisecondsSinceEpoch(now)}');
        print('   过期时间: ${DateTime.fromMillisecondsSinceEpoch(expiresTime)}');
        print('   已过时间: ${Duration(milliseconds: now - expiresTime)}');
        
        // ✅ 关键修复：检查RefreshToken是否存在且未过期
        if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
          print('❌ RefreshToken也为空，无法刷新，需要重新登录');
          return false;
        }
        
        // ✅ 检查RefreshToken是否过期
        if (refreshExpiresTime != null && now >= refreshExpiresTime) {
          print('❌ RefreshToken已过期，无法刷新，需要重新登录');
          print('   RefreshToken过期时间: ${DateTime.fromMillisecondsSinceEpoch(refreshExpiresTime)}');
          print('   已过时间: ${Duration(milliseconds: now - refreshExpiresTime)}');
          // 清除过期的Token
          await clearTokens();
          return false;
        }
        
        print('✅ RefreshToken有效，准备刷新...');
        print('   RefreshToken长度: ${storedRefreshToken.length}字符');
        if (refreshExpiresTime != null) {
          final remainingTime = Duration(milliseconds: refreshExpiresTime - now);
          print('   RefreshToken剩余时间: ${remainingTime.inDays}天${remainingTime.inHours % 24}小时');
        }
        
        // ✅ Token过期时，先尝试刷新
        final refreshSuccess = await refreshToken();
        
        print('📊 刷新结果: ${refreshSuccess ? "✅ 成功" : "❌ 失败"}');
        
        if (refreshSuccess) {
          print('✅ Token刷新成功，视为已登录');
          
          // ✅ 关键修复：二次验证，确保Token真的保存成功
          await Future.delayed(const Duration(milliseconds: 100)); // 短暂等待确保写入完成
          
          final newAccessToken = await getAccessToken();
          final newRefreshToken = await getRefreshToken();
          final newExpiresTime = await getExpiresTime();
          
          print('🔍 二次验证新Token:');
          print('   新AccessToken: ${newAccessToken != null ? "✅ 已保存 (${newAccessToken.length}字符)" : "❌ 未保存"}');
          print('   新RefreshToken: ${newRefreshToken != null ? "✅ 已保存 (${newRefreshToken.length}字符)" : "❌ 未保存"}');
          print('   新过期时间: ${newExpiresTime != null ? "✅ ${DateTime.fromMillisecondsSinceEpoch(newExpiresTime)}" : "❌ 未保存"}');
          
          if (newAccessToken == null || newAccessToken.isEmpty || newExpiresTime == null) {
            print('❌ 严重错误：刷新成功但Token未正确保存！');
            return false;
          }
          
          // ✅ 第三次验证：检查新Token是否有效
          final newNow = DateTime.now().millisecondsSinceEpoch;
          if (newNow >= newExpiresTime) {
            print('❌ 严重错误：新Token立即过期！');
            return false;
          }
          
          print('✅ 验证通过，Token有效');
          return true;
        } else {
          print('❌ Token刷新失败，需要重新登录');
          print('   可能原因:');
          print('   1. RefreshToken已过期或无效');
          print('   2. 网络连接失败或超时');
          print('   3. 服务器返回错误（401/500等）');
          print('   4. JSON解析失败');
          return false;
        }
      }
      
      final remainingTime = Duration(milliseconds: expiresTime - now);
      print('✅ Token有效，剩余时间: ${remainingTime.inHours}小时${remainingTime.inMinutes % 60}分钟${remainingTime.inSeconds % 60}秒');
      return true;
    } catch (e, stackTrace) {
      print('❌ Token检查异常: $e');
      print('堆栈跟踪: $stackTrace');
      print('   💡 这可能是导致意外跳转登录页的原因');
      return false;
    }
  }

  /// 获取过期时间
  static Future<int?> getExpiresTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_expiresTimeKey);
  }

  /// 获取RefreshToken过期时间
  static Future<int?> getRefreshExpiresTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_refreshExpiresTimeKey);
  }

  /// 清除 Token（登出）
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_expiresTimeKey);
    await prefs.remove(_refreshExpiresTimeKey);
  }

  /// 获取认证头
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 用于通知等待者刷新完成的Completer
  static Completer<bool>? _refreshCompleter;

  /// 刷新Token（无感知刷新）
  static Future<bool> refreshToken() async {
    print('\n🔄 ========== Token刷新流程开始 ==========');
    
    // 防止并发刷新 - 使用Completer机制
    if (_isRefreshing) {
      print('⚠️ Token正在刷新中，等待其他请求完成...');
      
      // ✅ 关键修复：如果有正在进行的刷新，等待它完成
      if (_refreshCompleter != null) {
        try {
          final result = await _refreshCompleter!.future;
          print('✅ 等待结束，其他请求已完成刷新，结果: ${result ? "成功" : "失败"}');
          
          // ✅ 验证Token是否真的刷新成功
          if (result) {
            final newAccessToken = await getAccessToken();
            final newExpiresTime = await getExpiresTime();
            
            if (newAccessToken != null && newExpiresTime != null) {
              final now = DateTime.now().millisecondsSinceEpoch;
              if (now < newExpiresTime) {
                print('✅ 验证通过：新Token有效');
                return true;
              } else {
                print('❌ 验证失败：新Token已过期');
                return false;
              }
            }
          }
          
          return result;
        } catch (e) {
          print('❌ 等待刷新完成时异常: $e');
          return false;
        }
      }
      
      return false;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();
    print('🔒 已设置刷新锁');

    try {
      final refreshToken = await getRefreshToken();
      
      if (refreshToken == null || refreshToken.isEmpty) {
        print('❌ 没有Refresh Token，无法刷新');
        _isRefreshing = false;
        _refreshCompleter!.complete(false);
        print('🔓 已释放刷新锁');
        return false;
      }

      print('📤 准备发送刷新请求...');
      print('   RefreshToken长度: ${refreshToken.length}字符');
      
      final url = '$baseUrl/user/refreshToken';
      print('🌐 请求URL: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'X-Refresh-Token': refreshToken,  // 添加Refresh Token到请求头
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('刷新Token请求超时（30秒）');
            },
          );

      print('📥 收到响应:');
      print('   状态码: ${response.statusCode}');
      print('   响应体: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(response.body);
          final apiResponse = AuthResponse.fromJson(jsonResponse);

          if (apiResponse.code == 200 && apiResponse.data != null) {
            print('✅ 服务器返回成功，开始保存新Token...');
            
            // ✅ 保存新的Token，并修正过期时间为绝对时间戳
            final loginData = LoginData.fromJson(apiResponse.data);
            
            // ✅ 将相对时间转换为绝对时间戳
            final now = DateTime.now().millisecondsSinceEpoch;
            final absoluteExpiresTime = now + loginData.expiresTime;
            final absoluteRefreshExpiresTime = loginData.refreshExpireTime != null 
                ? now + loginData.refreshExpireTime! 
                : null;
            
            print('🔧 Token时间转换:');
            print('   AccessToken相对时间: ${loginData.expiresTime}毫秒 (${loginData.expiresTime / 1000 / 60}分钟)');
            print('   AccessToken绝对过期时间: ${DateTime.fromMillisecondsSinceEpoch(absoluteExpiresTime)}');
            if (absoluteRefreshExpiresTime != null) {
              print('   RefreshToken相对时间: ${loginData.refreshExpireTime}毫秒 (${loginData.refreshExpireTime! / 1000 / 60}分钟)');
              print('   RefreshToken绝对过期时间: ${DateTime.fromMillisecondsSinceEpoch(absoluteRefreshExpiresTime)}');
            }
            
            final correctedLoginData = LoginData(
              accessToken: loginData.accessToken,
              refreshToken: loginData.refreshToken,
              expiresTime: absoluteExpiresTime, // ✅ 使用绝对时间戳
              refreshExpireTime: absoluteRefreshExpiresTime, // ✅ 使用绝对时间戳
            );
            
            await saveTokens(correctedLoginData);
            print('✅ Token刷新并保存成功');
            _isRefreshing = false;
            _refreshCompleter!.complete(true);
            print('🔓 已释放刷新锁');
            print('🔄 ========== Token刷新流程结束（成功）==========\n');
            return true;
          } else {
            print('❌ 服务器返回失败: code=${apiResponse.code}, message=${apiResponse.message}');
            _isRefreshing = false;
            _refreshCompleter!.complete(false);
            print('🔓 已释放刷新锁');
            print('🔄 ========== Token刷新流程结束（失败）==========\n');
            return false;
          }
        } catch (parseError) {
          print('❌ 解析响应JSON失败: $parseError');
          _isRefreshing = false;
          _refreshCompleter!.complete(false);
          print('🔓 已释放刷新锁');
          print('🔄 ========== Token刷新流程结束（异常）==========\n');
          return false;
        }
      } else {
        print('❌ HTTP请求失败: 状态码 ${response.statusCode}');
        print('   可能原因:');
        if (response.statusCode == 401) {
          print('   - RefreshToken已过期或无效');
        } else if (response.statusCode == 403) {
          print('   - 权限不足');
        } else if (response.statusCode >= 500) {
          print('   - 服务器内部错误');
        }
        _isRefreshing = false;
        _refreshCompleter!.complete(false);
        print('🔓 已释放刷新锁');
        print('🔄 ========== Token刷新流程结束（失败）==========\n');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Token刷新异常: $e');
      print('堆栈跟踪: $stackTrace');
      
      // ✅ 增强：详细记录异常类型
      if (e.toString().contains('TimeoutException')) {
        print('   💡 提示: 刷新请求超时（30秒）');
        print('   可能原因:');
        print('   - 网络连接不稳定');
        print('   - 服务器响应慢');
        print('   - 防火墙阻止');
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Failed host lookup')) {
        print('   💡 提示: 无法连接到服务器');
        print('   可能原因:');
        print('   - API地址配置错误');
        print('   - 网络未连接');
        print('   - 服务器未启动');
      } else if (e.toString().contains('HandshakeException')) {
        print('   💡 提示: SSL/TLS握手失败');
        print('   可能原因:');
        print('   - 证书问题');
        print('   - HTTPS配置错误');
      } else {
        print('   💡 未知异常类型: ${e.runtimeType}');
      }
      
      _isRefreshing = false;
      _refreshCompleter!.complete(false);
      print('🔓 已释放刷新锁');
      print('🔄 ========== Token刷新流程结束（异常）==========\n');
      return false;
    }
  }

  /// 处理401错误，尝试刷新Token
  static Future<bool> handleUnauthorized() async {
    print('检测到401错误，尝试刷新Token...');
    
    final success = await refreshToken();
    
    if (!success) {
      print('Token刷新失败，需要重新登录');
      _navigateToLogin();
      return false;
    }
    
    return true;
  }

  /// 跳转到登录页面
  static void _navigateToLogin() {
    if (_contextForNavigation != null && _contextForNavigation!.mounted) {
      // 清除Token
      clearTokens();
      
      // 显示提示
      ScaffoldMessenger.of(_contextForNavigation!).showSnackBar(
        const SnackBar(
          content: Text('登录已过期，请重新登录'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // 导航到登录页
      Navigator.of(_contextForNavigation!).pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    } else {
      print('无法导航到登录页：上下文无效');
    }
  }

  /// 执行带认证的HTTP请求（自动处理Token刷新）
  static Future<http.Response> _executeWithAuthRetry(
    Future<http.Response> Function() requestFunc,
  ) async {
    try {
      final response = await requestFunc();
      
      // 检查是否是401错误
      if (response.statusCode == 401) {
        print('收到401响应，尝试刷新Token...');
        
        // 尝试刷新Token
        final refreshSuccess = await handleUnauthorized();
        
        if (refreshSuccess) {
          // 刷新成功，重试原请求
          print('Token刷新成功，重试原请求...');
          final retryResponse = await requestFunc();
          return retryResponse;
        } else {
          // 刷新失败，抛出异常
          throw Exception('登录已过期，请重新登录');
        }
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// 查询账单明细列表
  static Future<List<BillDetail>> queryBillDetails(QueryBillRequest request) async {
    try {
      final url = '$baseUrl/bill/queryBillDetails';
      
      print('查询账单: $url');
      print('请求数据: ${jsonEncode(request.toJson())}');

      final response = await _executeWithAuthRetry(() async {
        final headers = await getAuthHeaders();
        return await http
            .post(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode(request.toJson()),
            )
            .timeout(const Duration(seconds: 30));
      });

      print('响应状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final apiResponse = ApiResponse<List<BillDetail>>.fromJson(
          jsonResponse,
          (data) => (data as List).map((item) => BillDetail.fromJson(item)).toList(),
        );

        if (apiResponse.code == 200 && apiResponse.data != null) {
          return apiResponse.data!;
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('查询失败: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('查询账单异常: $e');
      rethrow;
    }
  }

  /// 新增账单明细
  static Future<void> addBillDetails(AddBillRequest request) async {
    try {
      final url = '$baseUrl/bill/addBillDetails';

      print('新增账单: $url');
      print('请求数据: ${jsonEncode(request.toJson())}');

      final response = await _executeWithAuthRetry(() async {
        final headers = await getAuthHeaders();
        return await http
            .post(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode(request.toJson()),
            )
            .timeout(const Duration(seconds: 30));
      });

      print('响应状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(jsonResponse, (data) => data);
        
        if (apiResponse.code != 200) {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('新增失败: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('新增账单异常: $e');
      rethrow;
    }
  }

  /// 删除账单明细
  static Future<void> deleteBillDetails(String detailsId) async {
    try {
      final url = Uri.parse('$baseUrl/bill/deleteBillDetails').replace(
        queryParameters: {'detailsId': detailsId},
      );

      print('删除账单: $url');

      final response = await _executeWithAuthRetry(() async {
        final headers = await getAuthHeaders();
        return await http
            .delete(
              url,
              headers: headers,
            )
            .timeout(const Duration(seconds: 30));
      });

      print('响应状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(jsonResponse, (data) => data);
        
        if (apiResponse.code != 200) {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('删除失败: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('删除账单异常: $e');
      rethrow;
    }
  }

  /// 更新账单明细
  static Future<void> updateBillDetails(UpdateBillRequest request) async {
    try {
      final url = '$baseUrl/bill/updateBillDetails';

      print('更新账单: $url');
      print('请求数据: ${jsonEncode(request.toJson())}');

      final response = await _executeWithAuthRetry(() async {
        final headers = await getAuthHeaders();
        return await http
            .post(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode(request.toJson()),
            )
            .timeout(const Duration(seconds: 30));
      });

      print('响应状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final apiResponse = ApiResponse.fromJson(jsonResponse, (data) => data);
        
        if (apiResponse.code != 200) {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('更新失败: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('更新账单异常: $e');
      rethrow;
    }
  }

  /// 查询账单分类列表
  static Future<List<BillCategory>> queryBillCategory(int type) async {
    try {
      final url = Uri.parse('$baseUrl/bill/queryBillCategory').replace(
        queryParameters: {'type': type.toString()},
      );

      print('查询分类: $url');

      final response = await _executeWithAuthRetry(() async {
        final headers = await getAuthHeaders();
        return await http
            .get(
              url,
              headers: headers,
            )
            .timeout(const Duration(seconds: 30));
      });

      print('响应状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final apiResponse = ApiResponse<List<BillCategory>>.fromJson(
          jsonResponse,
          (data) => (data as List).map((item) => BillCategory.fromJson(item)).toList(),
        );

        if (apiResponse.code == 200 && apiResponse.data != null) {
          return apiResponse.data!;
        } else {
          throw Exception(apiResponse.message);
        }
      } else {
        throw Exception('查询分类失败: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('查询分类异常: $e');
      rethrow;
    }
  }

  /// 获取用户信息
  static Future<UserInfo> getUserInfo() async {
    try {
      final url = '$baseUrl/user/getUserInfo';
      print('正在请求获取用户信息接口: $url');

      final response = await _executeWithAuthRetry(() async {
        final headers = await getAuthHeaders();
        return await http
            .post(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(const Duration(seconds: 30));
      });

      print('响应状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final authResponse = AuthResponse.fromJson(jsonResponse);

        if (authResponse.code == 200 && authResponse.data != null) {
          return UserInfo.fromJson(authResponse.data);
        } else {
          throw Exception(authResponse.message);
        }
      } else {
        throw Exception('获取用户信息失败: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('获取用户信息异常: $e');
      rethrow;
    }
  }

  /// 更新用户信息
  static Future<void> updateUserInfo(UpdateUserInfoRequest request) async {
    try {
      final url = '$baseUrl/user/updateUserInfo';
      print('正在请求更新用户信息接口: $url');
      print('请求数据: ${jsonEncode(request.toJson())}');

      final response = await _executeWithAuthRetry(() async {
        final headers = await getAuthHeaders();
        headers['Content-Type'] = 'application/json';
        return await http
            .post(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode(request.toJson()),
            )
            .timeout(const Duration(seconds: 30));
      });

      print('响应状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final authResponse = AuthResponse.fromJson(jsonResponse);

        if (authResponse.code != 200) {
          throw Exception(authResponse.message);
        }
      } else {
        throw Exception('更新用户信息失败: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('更新用户信息异常: $e');
      rethrow;
    }
  }

  /// 用户登出
  static Future<void> logout() async {
    try {
      final url = '$baseUrl/user/logout';
      print('正在请求登出接口: $url');

      final response = await _executeWithAuthRetry(() async {
        final headers = await getAuthHeaders();
        return await http
            .post(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(const Duration(seconds: 30));
      });

      print('响应状态码: ${response.statusCode}');
      print('响应内容: ${response.body}');

      // 无论成功失败，都清除本地token
      await clearTokens();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final authResponse = AuthResponse.fromJson(jsonResponse);

        if (authResponse.code != 200) {
          print('登出接口返回错误: ${authResponse.message}');
        }
      }
    } catch (e) {
      print('登出异常: $e');
      // 即使出错也要清除本地token
      await clearTokens();
    }
  }
}
