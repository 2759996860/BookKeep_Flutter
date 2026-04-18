import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/api_service.dart';
import '../models/auth_models.dart';

class HomePage extends StatefulWidget {
  final ValueNotifier<int>? billRefreshSignal;

  const HomePage({super.key, this.billRefreshSignal});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _selectedMonth = DateTime.now();
  List<BillDetail> _allBills = [];
  Map<String, List<BillDetail>> _groupedBills = {};
  bool _isLoading = false;
  
  // 分类图标映射
  static const Map<String, String> _categoryIcons = {
    // 支出分类 (type=1)
    'CO0000': '📦',
    'CO0001': '🍔',
    'CO0002': '🚗',
    'CO0003': '🛍️',
    'CO0004': '💡',
    'CO0005': '🏠',
    'CO0006': '🎮',
    'CO0007': '🏥',
    'CO0008': '🛡️',
    'CO0009': '🎁',
    'CO0010': '💪',
    'CO0011': '✈️',
    'CO0012': '❤️',
    'CO0013': '💇',
    'CO0014': '🐕',
    // 收入分类 (type=2)
    'IO0000': '📦',
    'IO0001': '💰',
    'IO0002': '🏆',
    'IO0003': '📈',
    'IO0004': '🎁',
    'IO0005': '↩️',
    'IO0006': '🎰',
  };

  @override
  void initState() {
    super.initState();
    // ✅ 初始化中文日期格式
    initializeDateFormatting('zh_CN', null);
    _loadBills();
    
    // 监听刷新信号
    widget.billRefreshSignal?.addListener(_onRefreshSignal);
  }

  @override
  void dispose() {
    widget.billRefreshSignal?.removeListener(_onRefreshSignal);
    super.dispose();
  }

  void _onRefreshSignal() {
    if (mounted) {
      _loadBills();
    }
  }

  Future<void> _loadBills() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final startTime = DateFormat('yyyy-MM-dd').format(
        DateTime(_selectedMonth.year, _selectedMonth.month, 1),
      );
      final endTime = DateFormat('yyyy-MM-dd').format(
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
      );

      final request = QueryBillRequest(
        startTime: startTime,
        endTime: endTime,
      );

      final bills = await ApiService.queryBillDetails(request);
      
      if (!mounted) return;

      // 按日期分组
      final grouped = <String, List<BillDetail>>{};
      for (var bill in bills) {
        if (!grouped.containsKey(bill.recordTime)) {
          grouped[bill.recordTime] = [];
        }
        grouped[bill.recordTime]!.add(bill);
      }

      // 按日期降序排序
      final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
      final sortedGrouped = <String, List<BillDetail>>{};
      for (var key in sortedKeys) {
        sortedGrouped[key] = grouped[key]!;
      }

      setState(() {
        _allBills = bills;
        _groupedBills = sortedGrouped;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showError('加载失败: $e');
    }
  }

  double _calculateDailyIncome(List<BillDetail> bills) {
    return bills
        .where((b) => b.type == 2)
        .fold(0.0, (sum, b) => sum + b.amount);
  }

  double _calculateDailyExpense(List<BillDetail> bills) {
    return bills
        .where((b) => b.type == 1)
        .fold(0.0, (sum, b) => sum + b.amount);
  }

  double _calculateMonthlyIncome() {
    return _allBills
        .where((b) => b.type == 2)
        .fold(0.0, (sum, b) => sum + b.amount);
  }

  double _calculateMonthlyExpense() {
    return _allBills
        .where((b) => b.type == 1)
        .fold(0.0, (sum, b) => sum + b.amount);
  }

  String _getCategoryIcon(String categoryId) {
    return _categoryIcons[categoryId] ?? '📄';
  }

  Future<void> _selectMonth() async {
    int selectedYear = _selectedMonth.year;
    int selectedMonth = _selectedMonth.month;
    
    final now = DateTime.now();
    final minYear = now.year - 4;
    final maxYear = now.year;
    
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 判断当前选择的年月是否超过当前时间
            final isSelectedValid = selectedYear < now.year || 
                (selectedYear == now.year && selectedMonth <= now.month);
            
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: EdgeInsets.zero,
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 头部：显示当前选择
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$selectedYear年${selectedMonth.toString().padLeft(2, '0')}月',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelectedValid ? const Color(0xFF5A7D7C) : Colors.red.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 年份点击选择
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            '年：',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5A7D7C),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final result = await showDialog<int>(
                                  context: context,
                                  builder: (ctx) {
                                    return AlertDialog(
                                      title: const Text('选择年份'),
                                      content: SizedBox(
                                        width: 200,
                                        height: 300,
                                        child: ListView.builder(
                                          itemCount: 5,
                                          itemBuilder: (context, index) {
                                            final year = maxYear - index;
                                            return ListTile(
                                              title: Text('$year'),
                                              selected: year == selectedYear,
                                              onTap: () => Navigator.pop(ctx, year),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                                if (result != null) {
                                  setState(() {
                                    selectedYear = result;
                                    // 如果选择当年，月份不能超过当前月
                                    if (selectedYear == now.year && selectedMonth > now.month) {
                                      selectedMonth = now.month;
                                    }
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFCFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Center(
                                  child: Text(
                                    '$selectedYear',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF5A7D7C),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 月份点击选择
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text(
                            '月：',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5A7D7C),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final result = await showDialog<int>(
                                  context: context,
                                  builder: (ctx) {
                                    return AlertDialog(
                                      title: const Text('选择月份'),
                                      content: SizedBox(
                                        width: 200,
                                        height: 300,
                                        child: ListView.builder(
                                          itemCount: selectedYear == now.year ? now.month : 12,
                                          itemBuilder: (context, index) {
                                            final month = index + 1;
                                            return ListTile(
                                              title: Text('${month.toString().padLeft(2, '0')}月'),
                                              selected: month == selectedMonth,
                                              onTap: () => Navigator.pop(ctx, month),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                                if (result != null) {
                                  setState(() {
                                    selectedMonth = result;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFCFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Center(
                                  child: Text(
                                    '${selectedMonth.toString().padLeft(2, '0')}月',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF5A7D7C),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 按钮
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF5A7D7C),
                                side: const BorderSide(color: Color(0xFF80CBC4)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSelectedValid ? () {
                                Navigator.pop(
                                  context,
                                  DateTime(selectedYear, selectedMonth),
                                );
                              } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelectedValid ? const Color(0xFF80CBC4) : Colors.grey.shade300,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('确定'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadBills();
    }
  }

  void _showAddBillDialog() {
    showDialog(
      context: context,
      builder: (context) => AddBillDialog(
        onSuccess: () {
          _loadBills();
        },
      ),
    );
  }

  void _showEditBillDialog(BillDetail bill) {
    showDialog(
      context: context,
      builder: (context) => EditBillDialog(
        bill: bill,
        onSuccess: () {
          _loadBills();
        },
      ),
    );
  }

  Future<void> _deleteBill(String detailsId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条账单吗？'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService.deleteBillDetails(detailsId);
        if (mounted) {
          _showMessage('删除成功');
          _loadBills();
        }
      } catch (e) {
        if (mounted) {
          _showError('删除失败: $e');
        }
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF80CBC4),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 左箭头：上个月
            InkWell(
              onTap: () {
                setState(() {
                  if (_selectedMonth.month == 1) {
                    _selectedMonth = DateTime(_selectedMonth.year - 1, 12);
                  } else {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  }
                });
                _loadBills();
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 4),
            
            // 年月显示区域（支持点击弹窗和滑动切换）
            GestureDetector(
              onTap: _selectMonth,
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! < 0) {
                  // 左滑：下个月
                  final nextMonth = _selectedMonth.month == 12
                      ? DateTime(_selectedMonth.year + 1, 1)
                      : DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  if (!nextMonth.isAfter(DateTime.now())) {
                    setState(() {
                      _selectedMonth = nextMonth;
                    });
                    _loadBills();
                  }
                } else if (details.primaryVelocity! > 0) {
                  // 右滑：上个月
                  final fiveYearsAgo = DateTime(DateTime.now().year - 4, 1);
                  final prevMonth = _selectedMonth.month == 1
                      ? DateTime(_selectedMonth.year - 1, 12)
                      : DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  if (!prevMonth.isBefore(fiveYearsAgo)) {
                    setState(() {
                      _selectedMonth = prevMonth;
                    });
                    _loadBills();
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('yyyy').format(_selectedMonth),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      '年',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('MM').format(_selectedMonth),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      '月',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            
            // 右箭头：下个月（限制不能超过当前月份）
            InkWell(
              onTap: () {
                final nextMonth = _selectedMonth.month == 12
                    ? DateTime(_selectedMonth.year + 1, 1)
                    : DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                if (!nextMonth.isAfter(DateTime.now())) {
                  setState(() {
                    _selectedMonth = nextMonth;
                  });
                  _loadBills();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.chevron_right,
                  color: _selectedMonth.isAfter(DateTime.now().subtract(Duration(days: DateTime.now().day)))
                      ? Colors.white.withOpacity(0.3)
                      : Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
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
      body: Column(
        children: [
          // 月度统计卡片
          _buildMonthlySummary(),
          
          // 账单列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedBills.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadBills,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _groupedBills.length,
                          itemBuilder: (context, index) {
                            final date = _groupedBills.keys.elementAt(index);
                            final bills = _groupedBills[date]!;
                            return _buildDailyCard(date, bills);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBillDialog,
        backgroundColor: const Color(0xFF80CBC4),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
    );
  }

  Widget _buildMonthlySummary() {
    final income = _calculateMonthlyIncome();
    final expense = _calculateMonthlyExpense();
    final balance = income - expense;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F2F1), Color(0xFFEDE7F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80CBC4).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF80CBC4).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('收入', income, Colors.green.shade700),
              _buildStatItem('支出', expense, Colors.red.shade700),
              _buildStatItem('结余', balance, const Color(0xFF5A7D7C)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyCard(String date, List<BillDetail> bills) {
    final income = _calculateDailyIncome(bills);
    final expense = _calculateDailyExpense(bills);
    
    // 处理时区：统一处理并转换为本地时间
    DateTime dateTime;
    try {
      dateTime = DateTime.parse(date);
      // 转换为本地时间用于显示
      dateTime = dateTime.toLocal();
    } catch (e) {
      dateTime = DateTime.now();
    }
    
    final monthDay = DateFormat('MM月dd日', 'zh_CN').format(dateTime);
    final weekDay = DateFormat('E', 'zh_CN').format(dateTime).replaceAll('星期', '');

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF80CBC4).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期头部
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0F2F1), Color(0xFFF9FAFB)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Text(
                          monthDay,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5A7D7C),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          weekDay,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF80CBC4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (income > 0)
                          Flexible(
                            child: Text(
                              '收 ¥${income.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (income > 0 && expense > 0)
                          const SizedBox(width: 6),
                        if (expense > 0)
                          Flexible(
                            child: Text(
                              '支 ¥${expense.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 账单列表
            ...bills.map((bill) => _buildBillItem(bill)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBillItem(BillDetail bill) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEditBillDialog(bill),
        onLongPress: () {
          HapticFeedback.lightImpact();
          _deleteBill(bill.detailsId);
        },
        splashColor: const Color(0xFF80CBC4).withOpacity(0.15),
        highlightColor: const Color(0xFF80CBC4).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.grey.shade200,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // 图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bill.type == 1
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _getCategoryIcon(bill.categoryId),
                    style: const TextStyle(
                      fontSize: 24,
                      fontFamily: 'Segoe UI Emoji',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (bill.remark.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        bill.remark,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // 金额
              Text(
                '${bill.type == 1 ? '-' : '+'}¥${bill.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: bill.type == 1 ? Colors.red.shade700 : Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无账单记录',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮添加新账单',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// 自定义日历选择器
class CustomCalendarPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const CustomCalendarPicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<CustomCalendarPicker> createState() => _CustomCalendarPickerState();
}

class _CustomCalendarPickerState extends State<CustomCalendarPicker> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _selectedDate = widget.initialDate;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _selectDay(int day) {
    setState(() {
      _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, day);
    });
  }

  bool _isSelectable(int day) {
    final date = DateTime(_currentMonth.year, _currentMonth.month, day);
    return !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final startingOffset = (firstWeekday % 7);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部导航
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2F1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _previousMonth,
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF5A7D7C)),
                  ),
                  Text(
                    DateFormat('yyyy年MM月').format(_currentMonth),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5A7D7C),
                    ),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right, color: Color(0xFF5A7D7C)),
                  ),
                ],
              ),
            ),
            
            // 星期标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['日', '一', '二', '三', '四', '五', '六'].map((day) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF80CBC4),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            // 日期网格
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1.0,
                ),
                itemCount: 42,
                itemBuilder: (context, index) {
                  final dayOffset = index - startingOffset;
                  if (dayOffset < 0 || dayOffset >= daysInMonth) {
                    return const SizedBox.shrink();
                  }

                  final day = dayOffset + 1;
                  final isSelectable = _isSelectable(day);
                  final isSelected = _selectedDate.day == day &&
                      _selectedDate.month == _currentMonth.month &&
                      _selectedDate.year == _currentMonth.year;

                  return GestureDetector(
                    onTap: isSelectable ? () => _selectDay(day) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF80CBC4)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: !isSelectable
                                ? Colors.grey.shade300
                                : isSelected
                                    ? Colors.white
                                    : const Color(0xFF5A7D7C),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // 按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5A7D7C),
                        side: const BorderSide(color: Color(0xFF80CBC4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _selectedDate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF80CBC4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('确定'),
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
}

// 添加账单对话框
class AddBillDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const AddBillDialog({super.key, required this.onSuccess});

  @override
  State<AddBillDialog> createState() => _AddBillDialogState();
}

class _AddBillDialogState extends State<AddBillDialog> {
  int _selectedType = 1; // 1-支出，2-收入
  String? _selectedCategoryId;
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final _remarkController = TextEditingController();
  List<BillCategory> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ApiService.queryBillCategory(_selectedType);
      if (mounted) {
        setState(() {
          _categories = categories;
          if (categories.isNotEmpty) {
            _selectedCategoryId = categories.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载分类失败: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => CustomCalendarPicker(
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null) {
      _showDialogError('请选择分类');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showDialogError('请输入有效金额');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = AddBillRequest(
        categoryId: _selectedCategoryId!,
        amount: amount,
        recordTime: DateFormat('yyyy-MM-dd').format(_selectedDate),
        remark: _remarkController.text.trim().isEmpty
            ? null
            : _remarkController.text.trim(),
      );

      await ApiService.addBillDetails(request);
      
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showDialogError('添加失败: $e');
      }
    }
  }

  void _showDialogError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '确定',
              style: TextStyle(color: Color(0xFF80CBC4)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: const Color(0xFF5A7D7C),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '新增账单',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5A7D7C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 类型选择
              const Text(
                '类型',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A7D7C),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(1, '支出', Colors.red.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeButton(2, '收入', Colors.green.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 分类选择
              const Text(
                '分类',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A7D7C),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  final isSelected = _selectedCategoryId == category.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = category.id;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF80CBC4)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF80CBC4)
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              
              // 金额输入
              const Text(
                '金额',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A7D7C),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '请输入金额',
                  prefixText: '¥ ',
                  filled: true,
                  fillColor: const Color(0xFFFAFCFB),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF80CBC4),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 日期选择
              const Text(
                '日期',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A7D7C),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFCFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Color(0xFF80CBC4),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 备注输入
              const Text(
                '备注（可选）',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A7D7C),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _remarkController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '添加备注信息',
                  filled: true,
                  fillColor: const Color(0xFFFAFCFB),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF80CBC4),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // 按钮组
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5A7D7C),
                        side: const BorderSide(
                          color: Color(0xFF80CBC4),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF80CBC4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                        shadowColor: const Color(0xFF80CBC4).withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '保存',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(int type, String label, Color color) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedCategoryId = null;
        });
        _loadCategories();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isSelected ? color : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

// 编辑账单对话框
class EditBillDialog extends StatefulWidget {
  final BillDetail bill;
  final VoidCallback onSuccess;

  const EditBillDialog({
    super.key,
    required this.bill,
    required this.onSuccess,
  });

  @override
  State<EditBillDialog> createState() => _EditBillDialogState();
}

class _EditBillDialogState extends State<EditBillDialog> {
  late int _selectedType;
  String? _selectedCategoryId;
  late TextEditingController _amountController;
  late DateTime _selectedDate;
  late TextEditingController _remarkController;
  List<BillCategory> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.bill.type;
    _selectedCategoryId = widget.bill.categoryId;
    _amountController = TextEditingController(text: widget.bill.amount.toString());
    // 处理时区：统一处理并转换为本地时间
    try {
      final dateTime = DateTime.parse(widget.bill.recordTime);
      _selectedDate = dateTime.toLocal();
    } catch (e) {
      print('解析recordTime失败: $e');
      _selectedDate = DateTime.now();
    }
    _remarkController = TextEditingController(text: widget.bill.remark);
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ApiService.queryBillCategory(_selectedType);
      if (mounted) {
        setState(() {
          _categories = categories;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载分类失败: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => CustomCalendarPicker(
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = UpdateBillRequest(
        billDetailsId: widget.bill.detailsId,
        categoryId: _selectedCategoryId,
        amount: amount,
        recordTime: DateFormat('yyyy-MM-dd').format(_selectedDate),
        remark: _remarkController.text.trim().isEmpty
            ? null
            : _remarkController.text.trim(),
      );

      await ApiService.updateBillDetails(request);
      
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    }
  }

  void _showDialogError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '确定',
              style: TextStyle(color: Color(0xFF80CBC4)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    color: const Color(0xFF5A7D7C),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '编辑账单',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5A7D7C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // 类型选择
              const Text(
                '类型',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A7D7C),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(1, '支出', Colors.red.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeButton(2, '收入', Colors.green.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 分类选择
              const Text(
                '分类',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A7D7C),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  final isSelected = _selectedCategoryId == category.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = category.id;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF80CBC4)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF80CBC4)
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              
              // 金额输入
              const Text(
                '金额',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A7D7C),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '请输入金额',
                  prefixText: '¥ ',
                  filled: true,
                  fillColor: const Color(0xFFFAFCFB),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF80CBC4),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 日期选择
              const Text(
                '日期',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A7D7C),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFCFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Color(0xFF80CBC4),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 备注输入
              const Text(
                '备注（可选）',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A7D7C),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _remarkController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '添加备注信息',
                  filled: true,
                  fillColor: const Color(0xFFFAFCFB),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF80CBC4),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // 按钮组
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5A7D7C),
                        side: const BorderSide(
                          color: Color(0xFF80CBC4),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF80CBC4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                        shadowColor: const Color(0xFF80CBC4).withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              '保存',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(int type, String label, Color color) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedCategoryId = null;
        });
        _loadCategories();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isSelected ? color : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
