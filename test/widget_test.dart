
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/screens/login_screen.dart';

void main() {
  testWidgets('Kiem tra giao dien dang nhap', (tester) async {
    // Mo rieng man hinh dang nhap
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Kiem tra tieu de
    expect(
      find.text('Quản lý chi tiêu cá nhân'),
      findsOneWidget,
    );

    // Kiem tra nut dang nhap
    expect(
      find.text('ĐĂNG NHẬP'),
      findsOneWidget,
    );

    // Kiem tra co 2 o nhap Email va Mat khau
    expect(
      find.byType(TextFormField),
      findsNWidgets(2),
    );

    // Kiem tra lien ket dang ky tai khoan
    expect(
      find.text('Chưa có tài khoản? Đăng ký ngay'),
      findsOneWidget,
    );
  });

  testWidgets('Chuyen sang giao dien dang ky', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    final registerButton = find.text(
      'Chưa có tài khoản? Đăng ký ngay',
    );

    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    // Kiem tra giao dien dang ky
    expect(
      find.text('Đăng ký tài khoản'),
      findsOneWidget,
    );

    expect(
      find.text('ĐĂNG KÝ'),
      findsOneWidget,
    );

    // Dang ky can 3 o:
    // Email, Mat khau, Nhap lai mat khau
    expect(
      find.byType(TextFormField),
      findsNWidgets(3),
    );
  });
}
