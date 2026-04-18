import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/auth_models.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AutomaticKeepAliveClientMixin {
  UserInfo? _userInfo;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  bool get wantKeepAlive => false; // 不保持状态，每次进入都重建

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次页面可见时刷新
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userInfo = await ApiService.getUserInfo();
      if (mounted) {
        setState(() {
          _userInfo = userInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载失败: $e';
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService.logout();
        if (mounted) {
          // 跳转到登录页
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('退出失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showEditProfileDialog() {
    // 删除旧的统一编辑方法
  }

  void _showEditDialog(String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          '编辑${field}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5A7D7C),
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(
              field == '昵称' ? Icons.person_outline : 
              field == '邮箱' ? Icons.email_outlined : Icons.phone_outlined,
              color: const Color(0xFF80CBC4),
            ),
            filled: true,
            fillColor: const Color(0xFFFAFCFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF80CBC4), width: 2),
            ),
          ),
          keyboardType: field == '邮箱' ? TextInputType.emailAddress : 
                       field == '手机号' ? TextInputType.phone : TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();

              // 验证逻辑
              if (field == '昵称') {
                if (value.isEmpty || value.length < 2 || value.length > 20) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('昵称长度需在2-20字符之间')),
                  );
                  return;
                }
              } else if (field == '邮箱') {
                if (value.isNotEmpty &&
                    !RegExp(
                      r'^[\w-]+(\.[\w-]+)*@[\w-]+(\.[\w-]+)+$',
                    ).hasMatch(value)) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('邮箱格式不正确')));
                  return;
                }
              } else if (field == '手机号') {
                if (value.isNotEmpty &&
                    !RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('手机号格式不正确')));
                  return;
                }
              }

              try {
                UpdateUserInfoRequest request;
                if (field == '昵称') {
                  request = UpdateUserInfoRequest(userName: value);
                } else if (field == '邮箱') {
                  request = UpdateUserInfoRequest(
                    email: value.isEmpty ? null : value,
                  );
                } else {
                  request = UpdateUserInfoRequest(
                    phone: value.isEmpty ? null : value,
                  );
                }

                await ApiService.updateUserInfo(request);

                if (mounted) {
                  Navigator.pop(context);
                  _loadUserInfo();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('更新成功'),
                      backgroundColor: Color(0xFF80CBC4),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('更新失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF80CBC4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF80CBC4), Color(0xFFB39DDB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadUserInfo,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 用户信息卡片
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE0F2F1), Color(0xFFF9FAFB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF80CBC4).withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 默认头像
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF80CBC4),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // 用户名
                Text(
                  _userInfo?.userName ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5A7D7C),
                  ),
                ),
                const SizedBox(height: 8),

                // 用户ID
                Text(
                  'ID: ${_userInfo?.userId ?? ''}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 信息列表
          _buildInfoItem(
            icon: Icons.person_outline,
            label: '昵称',
            value: _userInfo?.userName ?? '',
            onTap: () => _showEditDialog('昵称', _userInfo?.userName ?? ''),
          ),
          _buildInfoItem(
            icon: Icons.email_outlined,
            label: '邮箱',
            value: _userInfo?.email ?? '未设置',
            onTap: () => _showEditDialog('邮箱', _userInfo?.email ?? ''),
          ),
          _buildInfoItem(
            icon: Icons.phone_outlined,
            label: '手机号',
            value: _userInfo?.phone ?? '未设置',
            onTap: () => _showEditDialog('手机号', _userInfo?.phone ?? ''),
          ),

          const SizedBox(height: 32),

          // 退出登录按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                '退出登录',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF80CBC4).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF80CBC4), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5A7D7C),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}
