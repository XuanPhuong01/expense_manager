
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/transaction_service.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() =>
      _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isSaving = false;

  String _type = 'expense';
  String _category = 'Ăn uống';
  String? _walletId;
  String? _walletName;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Xem trước thông tin giao dịch
  void _previewTransaction() {
    if (_formKey.currentState?.validate() != true) return;

    if (_walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví')),
      );
      return;
    }

    final amount = int.tryParse(_amountController.text);

    if (amount == null || amount <= 0) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xem trước giao dịch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Loại: ${_type == 'expense' ? 'Khoản chi' : 'Khoản thu'}',
            ),
            const SizedBox(height: 8),
            Text('Số tiền: $amount VND'),
            const SizedBox(height: 8),
            Text('Ví: ${_walletName ?? 'Chưa chọn'}'),
            const SizedBox(height: 8),
            Text('Danh mục: $_category'),
            const SizedBox(height: 8),
            Text('Ghi chú: ${_noteController.text.trim()}'),
            const SizedBox(height: 16),
            const Text(
              'Đây chỉ là bản xem trước. '
              'Giao dịch chưa được lưu vào Firebase.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // Lưu giao dịch vào Firebase
  Future<void> _saveTransaction() async {
    if (_isSaving) return;

    if (_formKey.currentState?.validate() != true) return;

    if (_walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví')),
      );
      return;
    }

    final amount = int.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await TransactionService().addTransaction(
        walletId: _walletId!,
        type: _type,
        amount: amount,
        category: _category,
        note: _noteController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lưu giao dịch thành công!'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lưu giao dịch thất bại: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập')),
      );
    }

    final wallets = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('wallets');

    final categories = _type == 'expense'
        ? [
            'Ăn uống',
            'Di chuyển',
            'Mua sắm',
            'Học tập',
            'Sức khỏe',
            'Khác',
          ]
        : [
            'Lương',
            'Thưởng',
            'Được tặng',
            'Thu nhập khác',
          ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        title: const Text('Thêm giao dịch'),
      ),
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
                  const Text(
                    'Loại giao dịch',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'expense',
                        label: Text('Khoản chi'),
                        icon: Icon(Icons.arrow_upward),
                      ),
                      ButtonSegment(
                        value: 'income',
                        label: Text('Khoản thu'),
                        icon: Icon(Icons.arrow_downward),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (values) {
                      setState(() {
                        _type = values.first;
                        _category = _type == 'expense'
                            ? 'Ăn uống'
                            : 'Lương';
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // Nhập số tiền
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Số tiền (VND)',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final amount = int.tryParse(value ?? '');

                      if (amount == null || amount <= 0) {
                        return 'Nhập số tiền lớn hơn 0';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Chọn ví từ Firestore
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: wallets.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Không thể tải ví');
                      }

                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return const Text(
                          'Bạn cần tạo ví trước khi thêm giao dịch.',
                        );
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: _walletId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Chọn ví',
                          prefixIcon: Icon(
                            Icons.account_balance_wallet,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        items: docs.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              doc.data()['name'] as String? ?? 'Ví',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _walletId = value;

                            if (value != null) {
                              final selected = docs.firstWhere(
                                (doc) => doc.id == value,
                              );

                              _walletName =
                                  selected.data()['name'] as String? ??
                                      'Ví';
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Vui lòng chọn ví';
                          }

                          return null;
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Chọn danh mục
                  DropdownButtonFormField<String>(
                    key: ValueKey(_type),
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  // Ghi chú
                  TextFormField(
                    controller: _noteController,
                    maxLength: 200,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      hintText: 'Ví dụ: Ăn trưa',
                      prefixIcon: Icon(Icons.edit_note),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Nút xem trước
                  FilledButton.icon(
                    onPressed: _previewTransaction,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Xem trước giao dịch'),
                  ),

                  const SizedBox(height: 12),

                  // Nút lưu giao dịch
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveTransaction,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving ? 'Đang lưu...' : 'Lưu giao dịch',
                    ),
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
