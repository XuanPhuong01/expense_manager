
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/main.dart';

void main() {
  testWidgets('Kiem tra man hinh ung dung', (WidgetTester tester) async {
    // Khoi chay giao dien
    await tester.pumpWidget(const MyApp());

    // Kiem tra ten ung dung
    expect(
      find.text('Quản lý chi tiêu cá nhân'),
      findsOneWidget,
    );

    // Kiem tra thong bao Firebase
    expect(
      find.text('Kết nối Firebase thành công!'),
      findsOneWidget,
    );
  });
}
