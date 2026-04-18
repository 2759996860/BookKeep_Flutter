import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '理财小助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        // ✅ 添加全局页面转场动画
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      // ✅ 使用onGenerateRoute统一管理所有路由
      onGenerateRoute: (settings) {
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            // 初始化导航上下文
            ApiService.setNavigationContext(context);
            
            Widget page;
            switch (settings.name) {
              case '/login':
                page = const LoginScreen();
                break;
              case '/home':
                page = const MainScreen();
                break;
              case '/':
              default:
                // ✅ 根路径：检查Token有效性，自动跳转到对应页面
                return FutureBuilder<bool>(
                  future: _checkTokenAndNavigate(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF6366F1),
                              ),
                              SizedBox(height: 16),
                              Text(
                                '正在验证登录状态...',
                                style: TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    // Token有效，进入主页
                    if (snapshot.hasData && snapshot.data == true) {
                      print('✅ Token有效，直接进入主页');
                      return const MainScreen();
                    }
                    
                    // Token无效或过期，进入登录页
                    print('❌ Token无效，进入登录页');
                    return const LoginScreen();
                  },
                );
            }
            
            return page;
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // ✅ 淡入 + 轻微上滑效果
            var tween = Tween(begin: const Offset(0.0, 0.05), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeInOutCubic));
            var offsetAnimation = animation.drive(tween);
            
            var fadeAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
            );

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(opacity: fadeAnimation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
        );
      },
    );
  }
  
  /// ✅ 检查Token并决定导航目标
  Future<bool> _checkTokenAndNavigate() async {
    try {
      print('\n========== 应用启动 - Token检查开始 ==========');
      
      // 先获取原始Token数据
      final accessToken = await ApiService.getAccessToken();
      final refreshToken = await ApiService.getRefreshToken();
      final expiresTime = await ApiService.getExpiresTime();
      
      print('📋 原始Token数据:');
      print('   AccessToken: ${accessToken != null ? "${accessToken.substring(0, 20)}..." : "null"}');
      print('   RefreshToken: ${refreshToken != null ? "${refreshToken.substring(0, 20)}..." : "null"}');
      print('   ExpiresTime: ${expiresTime ?? "null"}');
      
      if (expiresTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final expireDate = DateTime.fromMillisecondsSinceEpoch(expiresTime);
        final nowDate = DateTime.fromMillisecondsSinceEpoch(now);
        final isExpired = now >= expiresTime;
        
        print('⏰ 时间信息:');
        print('   当前时间: $nowDate');
        print('   过期时间: $expireDate');
        print('   是否过期: ${isExpired ? "❌ 已过期" : "✅ 未过期"}');
        
        if (!isExpired) {
          final remainingTime = Duration(milliseconds: expiresTime - now);
          print('   剩余时间: ${remainingTime.inHours}小时${remainingTime.inMinutes % 60}分钟${remainingTime.inSeconds % 60}秒');
        }
      }
      
      // 调用isLoggedIn检查
      final isLoggedIn = await ApiService.isLoggedIn();
      print('\n🔐 最终检查结果: ${isLoggedIn ? "✅ 已登录" : "❌ 未登录"}');
      print('========== Token检查结束 ==========\n');
      
      return isLoggedIn;
    } catch (e, stackTrace) {
      print('❌ Token检查异常: $e');
      print('堆栈跟踪: $stackTrace');
      print('========== Token检查结束 ==========\n');
      return false;
    }
  }
}
