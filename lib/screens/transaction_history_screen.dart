import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/transaction_maintenance_service.dart';
import 'edit_transaction_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final Set<String> _busyIds = {};

  String _money(int value) {
    // Tránh lỗi copy nhầm ký tự ở biểu thức chính quy khi dán code.
    final digits = value.abs().toString();
    final chunks = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      final start = end < 3 ? 0 : end - 3;
      chunks.insert(0, digits.substring(start, end));
    }
    final formatted = chunks.join('.');
    return '$formatted đ';
  }

  String _date(dynamic value) {
    if (value is! Timestamp) return 'Không rõ thời gian';
    final dt = value.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _edit(
    String id,
    Map<String, dynamic> data,
  ) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditTransactionScreen(
          transactionId: id,
          initialData: data,
        ),
      ),
    );
    if (changed == true) _notify('Đã cập nhật giao dịch và số dư ví.');
  }

  Future<void> _delete(String id, Map<String, dynamic> data) async {
    final isExpense = data['type'] == 'expense';
    final amount = ((data['amount'] as num?) ?? 0).toInt();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa giao dịch?'),
        content: Text(
          '${isExpense ? 'Khoản chi' : 'Khoản thu'} '
          '${_money(amount)} sẽ bị xóa. '
          'Số dư ví sẽ được tính lại. Bạn có chắc chắn không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    setState(() => _busyIds.add(id));
    try {
      await TransactionMaintenanceService().deleteTransaction(id);
      _notify('Đã xóa giao dịch và cập nhật số dư ví.');
    } catch (error) {
      _notify('Xóa giao dịch thất bại: $error');
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
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

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(title: const Text('Lịch sử giao dịch')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Không thể tải lịch sử: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Chưa có giao dịch nào.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final expense = data['type'] == 'expense';
              final amount = ((data['amount'] as num?) ?? 0).toInt();
              final busy = _busyIds.contains(doc.id);
              final tone = expense ? Colors.red : Colors.green;
              return Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: tone.withValues(alpha: 0.10),
                      child: Icon(
                        expense ? Icons.arrow_upward : Icons.arrow_downward,
                        color: tone,
                      ),
                    ),
                    title: Text(
                      (data['category'] as String?) ?? 'Khác',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((data['note'] as String?) ?? ''),
                        Text(_date(data['createdAt'])),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${expense ? '-' : '+'}${_money(amount)}',
                          style: TextStyle(
                            color: tone,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PopupMenuButton<String>(
                          enabled: !busy,
                          tooltip: 'Tùy chọn giao dịch',
                          onSelected: (value) {
                            if (value == 'edit') {
                              _edit(doc.id, data);
                            } else if (value == 'delete') {
                              _delete(doc.id, data);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Sửa giao dịch'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Xóa giao dịch'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
