import 'package:intl/intl.dart';

/// 统一的时间解析工具，处理ISO 8601格式的时区问题
/// 返回DateTime对象，保持UTC标记
DateTime parseDateTime(String dateTimeStr) {
  try {
    // 检查是否为ISO 8601格式（包含T或Z）
    if (dateTimeStr.contains('T') || dateTimeStr.contains('Z')) {
      final dateTime = DateTime.parse(dateTimeStr);
      // 如果后端返回的是UTC时间（带Z或+00:00），保持UTC标记
      return dateTime.isUtc ? dateTime : dateTime.toUtc();
    }
    // 标准格式，当作本地时间处理
    return DateTime.parse(dateTimeStr);
  } catch (e) {
    print('解析时间失败: $e, 原始值: $dateTimeStr');
    return DateTime.now();
  }
}

class RegisterRequest {
  final String userId;
  final String userName;
  final String password;
  final String? email;
  final String? phone;

  RegisterRequest({
    required this.userId,
    required this.userName,
    required this.password,
    this.email,
    this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'password': password,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
    };
  }
}

class LoginRequest {
  final String userId;
  final String password;

  LoginRequest({
    required this.userId,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'password': password,
    };
  }
}

class AuthResponse {
  final int code;
  final String message;
  final dynamic data;

  AuthResponse({
    required this.code,
    required this.message,
    this.data,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      code: json['code'] ?? 0,
      message: json['message'] ?? '',
      data: json['data'],
    );
  }
}

// 用户信息模型
class UserInfo {
  final String userId;
  final String userName;
  final String? email;
  final String? phone;
  final String? icon;

  UserInfo({
    required this.userId,
    required this.userName,
    this.email,
    this.phone,
    this.icon,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      email: json['email'],
      phone: json['phone'],
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (icon != null) 'icon': icon,
    };
  }
}

// 更新用户信息请求
class UpdateUserInfoRequest {
  final String? userName;
  final String? email;
  final String? phone;
  final String? icon;
  final String? oldPassword;
  final String? newPassword;

  UpdateUserInfoRequest({
    this.userName,
    this.email,
    this.phone,
    this.icon,
    this.oldPassword,
    this.newPassword,
  });

  Map<String, dynamic> toJson() {
    return {
      if (userName != null) 'userName': userName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (icon != null) 'icon': icon,
      if (oldPassword != null) 'oldPassword': oldPassword,
      if (newPassword != null) 'newPassword': newPassword,
    };
  }
}

class LoginData {
  final String accessToken;
  final String refreshToken;
  final int expiresTime; // accessToken的持续时间（毫秒）
  final int? refreshExpireTime; // refreshToken的持续时间（毫秒）

  LoginData({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresTime,
    this.refreshExpireTime,
  });

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      expiresTime: json['expiresTime'],
      refreshExpireTime: json['refreshExpireTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresTime': expiresTime,
      if (refreshExpireTime != null) 'refreshExpireTime': refreshExpireTime,
    };
  }
}

// 统一响应包装类
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return ApiResponse(
      code: json['code'],
      message: json['message'],
      data: json['data'] != null ? fromJsonT(json['data']) : null,
    );
  }
}

// 账单明细模型
class BillDetail {
  final String detailsId;
  final String categoryId;
  final double amount;
  final int type; // 1-支出，2-收入
  final String remark;
  final String recordTime;
  final String name;
  final String icon;

  BillDetail({
    required this.detailsId,
    required this.categoryId,
    required this.amount,
    required this.type,
    required this.remark,
    required this.recordTime,
    required this.name,
    required this.icon,
  });

  factory BillDetail.fromJson(Map<String, dynamic> json) {
    return BillDetail(
      detailsId: json['detailsId'],
      categoryId: json['categoryId'],
      amount: (json['amount'] as num).toDouble(),
      type: json['type'],
      remark: json['remark'] ?? '',
      recordTime: json['recordTime'],
      name: json['name'],
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detailsId': detailsId,
      'categoryId': categoryId,
      'amount': amount,
      'type': type,
      'remark': remark,
      'recordTime': recordTime,
      'name': name,
      'icon': icon,
    };
  }
}

// 账单分类模型
class BillCategory {
  final String id;
  final String name;
  final int type; // 1-支出，2-收入
  final String icon;
  final DateTime createdTime;
  final DateTime updatedTime;

  BillCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.createdTime,
    required this.updatedTime,
  });

  factory BillCategory.fromJson(Map<String, dynamic> json) {
    return BillCategory(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      icon: json['icon'],
      createdTime: parseDateTime(json['createdTime']),
      updatedTime: parseDateTime(json['updatedTime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
      'createdTime': createdTime.toIso8601String(),
      'updatedTime': updatedTime.toIso8601String(),
    };
  }
}

// 查询账单请求模型
class QueryBillRequest {
  final String? categoryId;
  final int? type;
  final String startTime;
  final String endTime;
  final int? sortType;

  QueryBillRequest({
    this.categoryId,
    this.type,
    required this.startTime,
    required this.endTime,
    this.sortType,
  });

  Map<String, dynamic> toJson() {
    return {
      if (categoryId != null) 'categoryId': categoryId,
      if (type != null) 'type': type,
      'startTime': startTime,
      'endTime': endTime,
      if (sortType != null) 'sortType': sortType,
    };
  }
}

// 新增账单请求模型
class AddBillRequest {
  final String categoryId;
  final double amount;
  final String recordTime;
  final String? remark;

  AddBillRequest({
    required this.categoryId,
    required this.amount,
    required this.recordTime,
    this.remark,
  });

  Map<String, dynamic> toJson() {
    return {
      'categoryId': categoryId,
      'amount': amount,
      'recordTime': recordTime,
      if (remark != null) 'remark': remark,
    };
  }
}

// 更新账单请求模型
class UpdateBillRequest {
  final String billDetailsId;
  final String? categoryId;
  final double? amount;
  final String? recordTime;
  final String? remark;

  UpdateBillRequest({
    required this.billDetailsId,
    this.categoryId,
    this.amount,
    this.recordTime,
    this.remark,
  });

  Map<String, dynamic> toJson() {
    return {
      'billDetailsId': billDetailsId,
      if (categoryId != null) 'categoryId': categoryId,
      if (amount != null) 'amount': amount,
      if (recordTime != null) 'recordTime': recordTime,
      if (remark != null) 'remark': remark,
    };
  }
}

// ==================== AI聊天相关模型 ====================

/// 会话信息
class ChatConversation {
  final String id;  // 会话UUID
  final String title;  // 会话标题
  final String userId;  // 用户ID
  final DateTime createdTime;  // 创建时间
  final DateTime updatedTime;  // 更新时间

  ChatConversation({
    required this.id,
    required this.title,
    required this.userId,
    required this.createdTime,
    required this.updatedTime,
  });

  /// 是否置顶（根据业务逻辑判断，后端未返回此字段）
  bool get isPinned => false;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      title: json['title'] as String,
      userId: json['userId'] as String,
      createdTime: parseDateTime(json['createdTime'] as String),
      updatedTime: parseDateTime(json['updatedTime'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'userId': userId,
      'createdTime': createdTime.toIso8601String(),
      'updatedTime': updatedTime.toIso8601String(),
    };
  }
}

/// 消息信息
class ChatMessage {
  final String id;  // 消息UUID
  final String conversationId;  // 会话业务UUID
  final String messageType;  // user/assistant/system
  final String content;  // 消息内容
  final int sortOrder;  // 排序顺序
  final DateTime createdTime;  // 创建时间
  final DateTime updatedTime;  // 更新时间

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.messageType,
    required this.content,
    required this.sortOrder,
    required this.createdTime,
    required this.updatedTime,
  });

  /// 兼容旧代码的角色字段
  String get role => messageType == 'user' ? 'user' : 'assistant';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      messageType: json['messageType'] as String,
      content: json['content'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdTime: parseDateTime(json['createdTime'] as String),
      updatedTime: parseDateTime(json['updatedTime'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'messageType': messageType,
      'content': content,
      'sortOrder': sortOrder,
      'createdTime': createdTime.toIso8601String(),
      'updatedTime': updatedTime.toIso8601String(),
    };
  }
}

/// 流式对话请求
class StreamChatRequest {
  final String conversationId;
  final String message;

  StreamChatRequest({
    required this.conversationId,
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'message': message,
    };
  }
}
