import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/budget_service.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetCategory {
  final String key;
  final String label;
  final IconData icon;

  const _BudgetCategory(this.key, this.label, this.icon);
}

class _BudgetScreenState extends State<BudgetScreen> {
  static const _blue = Color(0xFF4361EE);
  static const _background = Color(0xFFF4F7FF);
  static const _green = Color(0xFF139B72);
  static const _red = Color(0xFFE65A67);

  static const _categories = <_BudgetCategory>[
    _BudgetCategory('food', 'Ăn uống', Icons.restaurant_outlined),
    _BudgetCategory('transport', 'Di chuyển', Icons.directions_bus_outlined),
    _BudgetCategory('shopping', 'Mua sắm', Icons.shopping_bag_outlined),
    _BudgetCategory('education', 'Học tập', Icons.school_outlined),
    _BudgetCategory('health', 'Sức khỏe', Icons.health_and_safety_outlined),
    _BudgetCategory('other', 'Khác', Icons.category_outlined),
  ];

  final BudgetService _service = BudgetService();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String _money(int amount) {
    final digits = amount.abs().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '${amount < 0 ? '-' : ''}$digits đ';
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  Future<void> _editBudget(_BudgetCategory category, int? current) async {
    final selectedMonth = _month;
    final limit = await showDialog<int>(
      context: context,
      builder: (context) => _BudgetEditorDialog(
        categoryName: category.label,
        currentLimit: current,
      ),
    );
    if (limit == null || !mounted) return;

    try {
      await _service.saveBudget(
        month: selectedMonth,
        categoryKey: category.key,
        limit: limit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu ngân sách thành công')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu ngân sách: ${error.code}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu ngân sách: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Ngân sách',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.watchBudgets(_month),
        builder: (context, budgetsSnapshot) {
          if (budgetsSnapshot.hasError) {
            return const Center(
              child: Text('Không thể tải ngân sách. Kiểm tra Firestore Rules.'),
            );
          }
          if (!budgetsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final limits = <String, int>{};
          for (final doc in budgetsSnapshot.data!.docs) {
            final data = doc.data();
            final key = data['categoryKey'];
            final limit = data['limit'];
            if (key is String && limit is int && limit > 0) {
              limits[key] = limit;
            }
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _service.watchTransactions(_month),
            builder: (context, transactionsSnapshot) {
              if (transactionsSnapshot.hasError) {
                return const Center(
                  child: Text('Không thể tải giao dịch trong tháng.'),
                );
              }
              if (!transactionsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final spending = <String, int>{};
              for (final doc in transactionsSnapshot.data!.docs) {
                final data = doc.data();
                if (data['type'] != 'expense' || data['amount'] is! num) {
                  continue;
                }
                final categoryName = data['category'];
                for (final category in _categories) {
                  if (categoryName == category.label) {
                    spending[category.key] =
                        (spending[category.key] ?? 0) +
                        (data['amount'] as num).toInt();
                    break;
                  }
                }
              }

              final totalLimit = limits.values.fold<int>(
                0,
                (runningTotal, limit) => runningTotal + limit,
              );
              final totalUsed = limits.keys.fold<int>(
                0,
                (runningTotal, key) =>
                    runningTotal + (spending[key] ?? 0),
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _monthPicker(),
                  const SizedBox(height: 16),
                  _summaryCard(totalLimit, totalUsed),
                  const SizedBox(height: 20),
                  const Text(
                    'Ngân sách theo danh mục',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Số đã chi tự động tính từ giao dịch trong tháng.',
                    style: TextStyle(color: Color(0xFF718096), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  for (final category in _categories) ...[
                    _categoryCard(
                      category,
                      limit: limits[category.key],
                      spent: spending[category.key] ?? 0,
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Ngân sách là hạn mức dự kiến. Số đã chi lấy từ các '
                    'giao dịch, không trừ trực tiếp vào hạn mức và không '
                    'tính số dư ban đầu của ví là thu nhập.',
                    style: TextStyle(color: Color(0xFF718096), fontSize: 12),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _monthPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Tháng trước',
            onPressed: () => _moveMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              'Ngân sách tháng ${_month.month.toString().padLeft(2, '0')}/${_month.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Tháng sau',
            onPressed: () => _moveMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(int totalLimit, int totalUsed) {
    final hasBudget = totalLimit > 0;
    final remaining = totalLimit - totalUsed;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF283E87), _blue],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TỔNG HẠN MỨC ĐÃ ĐẶT',
            style: TextStyle(
              color: Color(0xFFDCE4FF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasBudget ? _money(totalLimit) : 'Chưa đặt ngân sách',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasBudget
                ? 'Đã chi: ${_money(totalUsed)}  •  '
                    '${remaining >= 0 ? 'Còn' : 'Vượt'}: ${_money(remaining.abs())}'
                : 'Chọn một danh mục bên dưới để bắt đầu.',
            style: const TextStyle(color: Color(0xFFE2E9FF)),
          ),
          if (hasBudget) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: (totalUsed / totalLimit).clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(12),
              color: remaining < 0 ? const Color(0xFFFFB4B4) : Colors.white,
              backgroundColor: const Color(0xFF7287DA),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryCard(
    _BudgetCategory category, {
    required int? limit,
    required int spent,
  }) {
    final ratio = limit == null ? 0.0 : spent / limit;
    final statusColor = ratio >= 1
        ? _red
        : ratio >= 0.8
            ? const Color(0xFFF59E0B)
            : _green;
    final status = ratio >= 1
        ? 'Đã đạt/vượt hạn mức'
        : ratio >= 0.8
            ? 'Sắp chạm hạn mức'
            : 'Trong hạn mức';

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE9EEFF),
                  child: Icon(category.icon, color: _blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        limit == null
                            ? 'Chưa đặt hạn mức • Đã chi ${_money(spent)}'
                            : 'Đã chi ${_money(spent)} / ${_money(limit)}',
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: limit == null ? 'Đặt ngân sách' : 'Sửa ngân sách',
                  onPressed: () => _editBudget(category, limit),
                  icon: Icon(
                    limit == null ? Icons.add_circle_outline : Icons.edit_outlined,
                    color: _blue,
                  ),
                ),
              ],
            ),
            if (limit != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                borderRadius: BorderRadius.circular(12),
                color: statusColor,
                backgroundColor: const Color(0xFFE8ECF5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.circle, size: 9, color: statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ),
                  Text(
                    '${(ratio * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BudgetEditorDialog extends StatefulWidget {
  const _BudgetEditorDialog({
    required this.categoryName,
    required this.currentLimit,
  });

  final String categoryName;
  final int? currentLimit;

  @override
  State<_BudgetEditorDialog> createState() => _BudgetEditorDialogState();
}

class _BudgetEditorDialogState extends State<_BudgetEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentLimit?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ngân sách ${widget.categoryName}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          decoration: const InputDecoration(
            labelText: 'Hạn mức (VND)',
            hintText: 'Ví dụ: 500000',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final amount = int.tryParse(value ?? '');
            if (amount == null || amount < 1000 || amount > 999999999999) {
              return 'Nhập từ 1.000 đến 999.999.999.999đ';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, int.parse(_controller.text));
          },
          child: const Text('Lưu hạn mức'),
        ),
      ],
    );
  }
}
