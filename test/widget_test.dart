
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/main.dart';

void main() {
  // Bài kiểm thử: màn hình trang chủ có hiển thị đúng không?
  testWidgets(
    'Kiem tra man hinh trang chu',
    (WidgetTester tester) async {

      // Khởi chạy ứng dụng trong môi trường kiểm thử
      await tester.pumpWidget(const ExpenseManagerApp());

      // Kiểm tra tiêu đề trang chủ
      expect(
        find.text('Tổng quan tài chính'),
        findsOneWidget,
      );

      // Kiểm tra dòng chữ số dư
      expect(
        find.text('Số dư hiện tại'),
        findsOneWidget,
      );
    },
  );
}
