import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/transaction_maintenance_service.dart';

class EditTransactionScreen extends StatefulWidget {
  const EditTransactionScreen({
    super.key,
    required this.transactionId,
    required this.initialData,
  });

  final String transactionId;
  final Map<String, dynamic> initialData;

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _type;
  late String _category;
  bool _saving = false;

  static const _expenseCategories = [
    'Ăn uống', 'Di chuyển', 'Mua sắm', 'Học tập', 'Sức khỏe', 'Khác',
  ];
  static const _incomeCategories = [
    'Lương', 'Thưởng', 'Được tặng', 'Thu nhập khác',
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _type = data['type'] == 'income' ? 'income' : 'expense';
    _category = (data['category'] as String?) ??
        (_type == 'expense' ? 'Khác' : 'Thu nhập khác');
    _amountController = TextEditingController(
      text: ((data['amount'] as num?) ?? 0).toInt().toString(),
    );
    _noteController = TextEditingController(
      text: (data['note'] as String?) ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _formKey.currentState?.validate() != true) return;
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null) return;
    setState(() => _saving = true);
    try {
      await TransactionMaintenanceService().updateTransaction(
        transactionId: widget.transactionId,
        type: _type,
        amount: amount,
        category: _category,
        note: _noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể sửa giao dịch: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = _type == 'expense'
        ? _expenseCategories
        : _incomeCategories;
    // Giữ danh mục cũ nếu giao dịch đã tạo bằng bản app khác.
    final categories = choices.contains(_category)
        ? choices
        : <String>[_category, ...choices];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(title: const Text('Sửa giao dịch')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Loại giao dịch',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'expense',
                        label: Text('Khoản chi'),
                      ),
                      ButtonSegment(
                        value: 'income',
                        label: Text('Khoản thu'),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: _saving
                        ? null
                        : (value) => setState(() {
                              _type = value.first;
                              _category = _type == 'expense'
                                  ? 'Ăn uống'
                                  : 'Lương';
                            }),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _amountController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Số tiền (VND)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final amount = int.tryParse(value ?? '');
                      if (amount == null || amount <= 0 ||
                          amount > 999999999999) {
                        return 'Hãy nhập số tiền hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_type),
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục',
                      border: OutlineInputBorder(),
                    ),
                    items: categories.map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        )).toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _category = value!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    enabled: !_saving,
                    maxLength: 200,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Giữ nguyên ví và ngày tạo giao dịch. Khi sửa số tiền, '
                    'ứng dụng tự tính lại số dư ví.',
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Lưu thay đổi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
