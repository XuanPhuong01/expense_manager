import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Doc va luu han muc ngan sach. So da chi duoc tinh tu transactions.
class BudgetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _collection(String name) {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Ban can dang nhap de su dung ngan sach.');
    }
    return _db.collection('users').doc(user.uid).collection(name);
  }

  static String monthKey(DateTime month) {
    final value = month.month.toString().padLeft(2, '0');
    return '${month.year}-$value';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBudgets(DateTime month) {
    return _collection('budgets')
        .where('month', isEqualTo: monthKey(month))
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTransactions(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return _collection('transactions')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .snapshots();
  }

  Future<void> saveBudget({
    required DateTime month,
    required String categoryKey,
    required int limit,
  }) async {
    const allowedKeys = {
      'food', 'transport', 'shopping', 'education', 'health', 'other',
    };
    if (!allowedKeys.contains(categoryKey) ||
        limit < 1000 ||
        limit > 999999999999) {
      throw ArgumentError('Han muc ngan sach khong hop le.');
    }

    final key = monthKey(month);
    // ID xac dinh: moi thang va danh muc chi co mot ngan sach.
    await _collection('budgets').doc('${key}_$categoryKey').set({
      'month': key,
      'categoryKey': categoryKey,
      'limit': limit,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
