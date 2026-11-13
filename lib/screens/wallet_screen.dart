
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'transaction_screen.dart';
// ==========================================
// MAN HINH QUAN LY VI TIEN
// ==========================================

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  // Dinh dang so tien: 500000 -> 500.000
  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]}.',
    );
  }

  // ==========================================
  // CHUC NANG 1: THEM VI MOI
  // ==========================================

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
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lưu ví: ${e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // CHUC NANG 2: CHINH SUA VI
  // ==========================================

  Future<void> _editWallet(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> walletRef,
    String currentName,
    String currentType,
  ) async {
    // Mo hop thoai chinh sua vi
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _EditWalletDialog(
        name: currentName,
        type: currentType,
      ),
    );

    // Neu nguoi dung nhan Huy
    if (result == null || !context.mounted) return;

    try {
      // Cap nhat thong tin tren Firestore
      await walletRef.update({
        'name': result['name'],
        'type': result['type'],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật ví thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể cập nhật ví: ${e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // GIAO DIEN DANH SACH VI
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Vui lòng đăng nhập'),
        ),
      );
    }

    // Lay danh sach vi theo UID
    final wallets = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('wallets');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),

      appBar: AppBar(
        title: const Text(
          'Ví của tôi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF4F7FF),
        actions: [

IconButton(
  tooltip: 'Thêm giao dịch',
  icon: const Icon(Icons.receipt_long),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TransactionScreen(),
      ),
    );
  },
),

          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),

      // Doc du lieu Firestore theo thoi gian thuc
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: wallets.snapshots(),
        builder: (context, snapshot) {
          // Xu ly loi doc du lieu
          if (snapshot.hasError) {
            return const Center(
              child: Text('Không thể tải danh sách ví'),
            );
          }

          // Hien thi loading
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final documents = snapshot.data!.docs;

          // Neu chua co vi
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Nhấn Thêm ví để bắt đầu',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          // Hien thi danh sach vi
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              final data = document.data();

              final name =
                  data['name'] as String? ?? 'Ví';

              final type =
                  data['type'] as String? ?? 'cash';

              final balance =
                  (data['balance'] as num?)?.toInt() ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  // NHAN VAO VI DE CHINH SUA
                  onTap: () => _editWallet(
                    context,
                    document.reference,
                    name,
                    type,
                  ),

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
                      fontSize: 16,
                    ),
                  ),

                  subtitle: Text(
                    type == 'bank'
                        ? 'Tài khoản ngân hàng'
                        : 'Tiền mặt',
                  ),

                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_formatMoney(balance)} đ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4361EE),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Chỉnh sửa',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      // Nut them vi moi
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWallet(context),
        backgroundColor: const Color(0xFF4361EE),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm ví'),
      ),
    );
  }
}

// ==========================================
// HOP THOAI TAO VI MOI
// ==========================================

class _CreateWalletDialog extends StatefulWidget {
  const _CreateWalletDialog();

  @override
  State<_CreateWalletDialog> createState() =>
      _CreateWalletDialogState();
}

class _CreateWalletDialogState
    extends State<_CreateWalletDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  final _balanceController = TextEditingController(
    text: '0',
  );

  String _type = 'cash';

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final balance = int.parse(
      _balanceController.text,
    );

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
              // Ten vi
              TextFormField(
                controller: _nameController,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Tên ví',
                  hintText: 'Ví dụ: Ví tiền mặt',
                  prefixIcon: Icon(Icons.wallet_outlined),
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

              // Loai vi
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
                    setState(() {
                      _type = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 16),

              // So du ban dau
              TextFormField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: const InputDecoration(
                  labelText: 'Số dư ban đầu (VND)',
                  prefixIcon: Icon(Icons.payments_outlined),
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

// ==========================================
// HOP THOAI CHINH SUA VI
// ==========================================

class _EditWalletDialog extends StatefulWidget {
  final String name;
  final String type;

  const _EditWalletDialog({
    required this.name,
    required this.type,
  });

  @override
  State<_EditWalletDialog> createState() =>
      _EditWalletDialogState();
}

class _EditWalletDialogState
    extends State<_EditWalletDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late String _type;

  @override
  void initState() {
    super.initState();

    // Hien thi thong tin vi cu
    _nameController = TextEditingController(
      text: widget.name,
    );

    _type = widget.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Tra thong tin moi ve WalletScreen
    Navigator.of(context).pop(<String, String>{
      'name': _nameController.text.trim(),
      'type': _type,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chỉnh sửa ví'),

      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sua ten vi
              TextFormField(
                controller: _nameController,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Tên ví',
                  prefixIcon: Icon(Icons.edit_outlined),
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

              // Sua loai vi
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
                    setState(() {
                      _type = value;
                    });
                  }
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
          child: const Text('Lưu thay đổi'),
        ),
      ],
    );
  }
}
