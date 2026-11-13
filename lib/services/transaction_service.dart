
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addTransaction({
    required String walletId,
    required String type,
    required int amount,
    required String category,
    required String note,
  }) async {
    // 1. Kiểm tra người dùng đăng nhập
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Bạn chưa đăng nhập.');
    }

    // 2. Kiểm tra dữ liệu đầu vào
    if (walletId.isEmpty || amount <= 0) {
      throw ArgumentError('Thông tin giao dịch không hợp lệ.');
    }

    if (type != 'expense' && type != 'income') {
      throw ArgumentError('Loại giao dịch không hợp lệ.');
    }

    if (category.trim().isEmpty) {
      throw ArgumentError('Vui lòng chọn danh mục.');
    }

    // 3. Tham chiếu đến ví
    final walletRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('wallets')
        .doc(walletId);

    // 4. Chuẩn bị document giao dịch mới
    final transactionRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .doc();

    // 5. Lưu giao dịch và cập nhật ví cùng nhau
    await _firestore.runTransaction((transaction) async {
      final walletSnapshot =
          await transaction.get(walletRef);

      if (!walletSnapshot.exists) {
        throw StateError('Ví không tồn tại.');
      }

      final walletData = walletSnapshot.data()!;
      final currentBalance = walletData['balance'];

      if (currentBalance is! num) {
        throw StateError('Dữ liệu số dư ví không hợp lệ.');
      }

      // Khoản chi làm giảm tiền, khoản thu làm tăng tiền
      final change = type == 'expense' ? -amount : amount;

      final newBalance = currentBalance.toInt() + change;

      // Ghi giao dịch mới
      transaction.set(transactionRef, {
        'walletId': walletId,
        'type': type,
        'amount': amount,
        'category': category.trim(),
        'note': note.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Cập nhật số dư ví
    transaction.update(walletRef, {
  'balance': newBalance,
  'lastTransactionId': transactionRef.id,
  'updatedAt': FieldValue.serverTimestamp(),
});
    });
  }
}
