/// 应用配置
class AppConfig {
  /// API基础URL
  /// Android模拟器: http://10.0.2.2:8080 (10.0.2.2是模拟器访问宿主机的特殊地址)
  /// iOS模拟器/真机: http://192.168.1.6:8080
  static const String apiBaseUrl = 'http://192.168.1.6:8080';

  /// 用户相关接口前缀
  static const String userApiPrefix = '$apiBaseUrl/user';

  /// 账单相关接口前缀
  static const String billApiPrefix = '$apiBaseUrl/bill';

  /// AI聊天相关接口前缀
  static const String chatApiPrefix = '$apiBaseUrl/chat';
}
