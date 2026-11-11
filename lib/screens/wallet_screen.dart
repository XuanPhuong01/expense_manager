
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]}.',
    );
  }

  Future<void> _addWallet(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final wallet = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _CreateWalletDialog(),
    );

    if (wallet == null || !context.mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('wallets')
          .add({
            ...wallet,
            'currency': 'VND',
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo ví thành công!'),
        ),
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lưu ví: ${e.code}'),
        ),
      );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ví của tôi'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: wallets.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Không thể tải danh sách ví'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final documents = snapshot.data!.docs;

          if (documents.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 76,
                    color: Color(0xFF4361EE),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Bạn chưa có ví tiền nào',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text('Nhấn Thêm ví để bắt đầu'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final data = documents[index].data();

              final name = data['name'] as String? ?? 'Ví';
              final type = data['type'] as String? ?? 'cash';
              final balance =
                  (data['balance'] as num?)?.toInt() ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE3E9FF),
                    child: Icon(
                      type == 'bank'
                          ? Icons.account_balance
                          : Icons.wallet,
                      color: const Color(0xFF4361EE),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    type == 'bank'
                        ? 'Tài khoản ngân hàng'
                        : 'Tiền mặt',
                  ),
                  trailing: Text(
                    '${_formatMoney(balance)} đ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4361EE),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWallet(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm ví'),
      ),
    );
  }
}

class _CreateWalletDialog extends StatefulWidget {
  const _CreateWalletDialog();

  @override
  State<_CreateWalletDialog> createState() =>
      _CreateWalletDialogState();
}

class _CreateWalletDialogState extends State<_CreateWalletDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');

  String _type = 'cash';

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final balance = int.parse(_balanceController.text);

    Navigator.of(context).pop({
      'name': _nameController.text.trim(),
      'type': _type,
      'initialBalance': balance,
      'balance': balance,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo ví mới'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Tên ví',
                  hintText: 'Ví dụ: Ví tiền mặt',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Vui lòng nhập tên ví';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Loại ví',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'cash',
                    child: Text('Tiền mặt'),
                  ),
                  DropdownMenuItem(
                    value: 'bank',
                    child: Text('Ngân hàng'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _type = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: const InputDecoration(
                  labelText: 'Số dư ban đầu (VND)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập số dư';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Số tiền không hợp lệ';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Lưu ví'),
        ),
      ],
    );
  }
}
