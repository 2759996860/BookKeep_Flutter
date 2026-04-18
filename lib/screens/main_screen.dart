import 'package:flutter/material.dart';
import 'home_page.dart';
import 'chat_page.dart';
import 'profile_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0; // 0: AI聊天, 1: 账单, 2: 我
  
  // ✅ 添加动画控制器用于Tab切换动画
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // ✅ 用于触发账单页面刷新的信号
  final ValueNotifier<int> _billRefreshSignal = ValueNotifier<int>(0);

  final List<Widget> _pages = [];
  
  @override
  void initState() {
    super.initState();
    // ✅ 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _animationController.forward();
    
    // ✅ 初始化页面列表，传递刷新信号给HomePage
    _pages.addAll([
      const ChatPage(),
      HomePage(billRefreshSignal: _billRefreshSignal),
      const ProfilePage(),
    ]);
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _billRefreshSignal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('MainScreen build: currentIndex = $_currentIndex');

    return Scaffold(
      // ✅ 使用IndexedStack保持页面状态，不使用AnimatedSwitcher避免重建
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          print('Tab tapped: $index');
          
          setState(() {
            _currentIndex = index;
          });
          
          // ✅ 重置并播放淡入动画
          _animationController.reset();
          _animationController.forward();
          
          // ✅ 如果切换到账单Tab，发送刷新信号
          if (index == 1) {
            _billRefreshSignal.value++;
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white, // ✅ 白色背景
        selectedItemColor: const Color(0xFF80CBC4), // ✅ 莫兰迪青绿
        unselectedItemColor: Colors.grey.shade500, // ✅ 柔和灰色
        selectedFontSize: 12,
        unselectedFontSize: 12,
        // ✅ 添加选中项的缩放动画
        selectedIconTheme: const IconThemeData(size: 26),
        unselectedIconTheme: const IconThemeData(size: 22),
        // ✅ 添加选中指示器
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 8, // ✅ 阴影效果
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
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我',
          ),
        ],
      ),
    );
  }
}
