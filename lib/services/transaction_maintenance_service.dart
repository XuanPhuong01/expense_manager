import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Sửa/xóa giao dịch và đồng bộ số dư ví trong cùng Firestore Transaction.
/// Giữ nguyên ví và createdAt khi sửa (không chuyển ví ở phiên bản này).
class TransactionMaintenanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _transactions(String uid) =>
      _db.collection('users').doc(uid).collection('transactions');

  CollectionReference<Map<String, dynamic>> _wallets(String uid) =>
      _db.collection('users').doc(uid).collection('wallets');

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Bạn cần đăng nhập để quản lý giao dịch.');
    }
    return uid;
  }

  int _signed(String type, int amount) =>
      type == 'expense' ? -amount : amount;

  void _checkInput({
    required String type,
    required int amount,
    required String category,
    required String note,
  }) {
    if (!['expense', 'income'].contains(type)) {
      throw ArgumentError('Loại giao dịch không hợp lệ.');
    }
    if (amount <= 0 || amount > 999999999999) {
      throw ArgumentError('Số tiền phải lớn hơn 0 và trong giới hạn.');
    }
    if (category.trim().isEmpty || category.length > 40) {
      throw ArgumentError('Danh mục không hợp lệ.');
    }
    if (note.length > 200) {
      throw ArgumentError('Ghi chú không được quá 200 ký tự.');
    }
  }

  Future<void> updateTransaction({
    required String transactionId,
    required String type,
    required int amount,
    required String category,
    required String note,
  }) async {
    final safeCategory = category.trim();
    final safeNote = note.trim();
    _checkInput(
      type: type,
      amount: amount,
      category: safeCategory,
      note: safeNote,
    );
    final uid = _requireUid();
    final transactionRef = _transactions(uid).doc(transactionId);

    await _db.runTransaction((transaction) async {
      // Firestore yêu cầu hoàn thành các thao tác đọc trước khi ghi.
      final transactionSnap = await transaction.get(transactionRef);
      if (!transactionSnap.exists) {
        throw StateError('Giao dịch không còn tồn tại.');
      }
      final old = transactionSnap.data()!;
      final walletId = old['walletId'] as String;
      final walletRef = _wallets(uid).doc(walletId);
      final walletSnap = await transaction.get(walletRef);
      if (!walletSnap.exists) {
        throw StateError('Ví của giao dịch đã bị xóa.');
      }

      final oldAmount = (old['amount'] as num).toInt();
      final oldType = old['type'] as String;
      final currentBalance =
          (walletSnap.data()!['balance'] as num).toInt();
      final restored = currentBalance - _signed(oldType, oldAmount);
      final newBalance = restored + _signed(type, amount);

      transaction.update(transactionRef, {
        'type': type,
        'amount': amount,
        'category': safeCategory,
        'note': safeNote,
      });
      transaction.update(walletRef, {
        'balance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastTransactionId': transactionId,
      });
    });
  }

  Future<void> deleteTransaction(String transactionId) async {
    final uid = _requireUid();
    final transactionRef = _transactions(uid).doc(transactionId);

    await _db.runTransaction((transaction) async {
      final transactionSnap = await transaction.get(transactionRef);
      if (!transactionSnap.exists) {
        throw StateError('Giao dịch đã bị xóa trước đó.');
      }
      final old = transactionSnap.data()!;
      final walletId = old['walletId'] as String;
      final walletRef = _wallets(uid).doc(walletId);
      final walletSnap = await transaction.get(walletRef);
      if (!walletSnap.exists) {
        throw StateError('Ví của giao dịch đã bị xóa.');
      }
      final oldAmount = (old['amount'] as num).toInt();
      final oldType = old['type'] as String;
      final currentBalance =
          (walletSnap.data()!['balance'] as num).toInt();
      final restoredBalance = currentBalance - _signed(oldType, oldAmount);

      transaction.delete(transactionRef);
      transaction.update(walletRef, {
        'balance': restoredBalance,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastTransactionId': transactionId,
      });
    });
  }
}
