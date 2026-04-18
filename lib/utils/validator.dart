class Validator {
  // 密码验证正则表达式
  static final RegExp _passwordRegExp = RegExp(
    "^[a-zA-Z0-9!@#\$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>\\/?`~]+\$",
  );

  // 用户ID验证正则表达式
  static final RegExp _userIdRegExp = RegExp("^[a-zA-Z0-9_@#\$%^&*!]+\$");

  // 邮箱验证正则表达式
  static final RegExp _emailRegExp = RegExp("^[\\w-]+(\\.[\\w-]+)*@[\\w-]+(\\.[\\w-]+)+\$");

  // 手机号验证正则表达式
  static final RegExp _phoneRegExp = RegExp("^1[3-9]\\d{9}\$");

  /// 验证用户ID (2-20字符,字母数字特殊字符)
  static String? validateUserId(String? value) {
    if (value == null || value.isEmpty) {
      return '用户ID不能为空';
    }
    if (value.length < 2 || value.length > 20) {
      return '用户ID长度必须在2-20字符之间';
    }
    if (!_userIdRegExp.hasMatch(value)) {
      return '用户ID只能包含字母、数字和特殊字符';
    }
    return null;
  }

  /// 验证用户名 (2-20字符)
  static String? validateUserName(String? value) {
    if (value == null || value.isEmpty) {
      return '用户名不能为空';
    }
    if (value.length < 2 || value.length > 20) {
      return '用户名长度必须在2-20字符之间';
    }
    return null;
  }

  /// 验证密码 (8-20字符,字母数字特殊字符)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '密码不能为空';
    }
    if (value.length < 8 || value.length > 20) {
      return '密码长度必须在8-20字符之间';
    }
    if (!_passwordRegExp.hasMatch(value)) {
      return '密码只能包含字母、数字和特殊字符';
    }
    return null;
  }

  /// 验证确认密码
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return '请再次输入密码';
    }
    if (value != password) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  /// 验证邮箱 (可选)
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null; // 邮箱是可选的
    }
    if (!_emailRegExp.hasMatch(value)) {
      return '请输入有效的邮箱地址';
    }
    return null;
  }

  /// 验证手机号 (可选)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // 手机号是可选的
    }
    if (!_phoneRegExp.hasMatch(value)) {
      return '请输入有效的手机号码';
    }
    return null;
  }
}
