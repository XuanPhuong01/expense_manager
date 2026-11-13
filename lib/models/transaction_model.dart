
import 'package:cloud_firestore/cloud_firestore.dart';

class MoneyTransaction {
  final String id;
  final String walletId;
  final String type;
  final int amount;
  final String category;
  final String note;
  final DateTime? createdAt;

  const MoneyTransaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.category,
    required this.note,
    this.createdAt,
  });

  factory MoneyTransaction.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return MoneyTransaction(
      id: document.id,
      walletId: data['walletId'] as String,
      type: data['type'] as String,
      amount: (data['amount'] as num).toInt(),
      category: data['category'] as String? ?? '',
      note: data['note'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
}
