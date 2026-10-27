
import 'package:flutter/material.dart';

// 1. Điểm bắt đầu của ứng dụng
void main() {
  runApp(const ExpenseManagerApp());
}

// 2. Cấu hình chung cho ứng dụng
class ExpenseManagerApp extends StatelessWidget {
  const ExpenseManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý chi tiêu cá nhân',
      debugShowCheckedModeBanner: false,

      // Thiết lập màu sắc giao diện
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),

      // Màn hình đầu tiên
      home: const HomePage(),
    );
  }
}

// 3. Tạo màn hình trang chủ
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // Thanh tiêu đề phía trên
      appBar: AppBar(
        title: const Text('Tổng quan tài chính'),
        backgroundColor: Colors.white,
      ),

      // Nội dung chính của trang
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          const Text(
            'Xin chào! 👋',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Thẻ hiển thị số dư
          Card(
            color: const Color(0xFF0F766E),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Số dư hiện tại',
                    style: TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    '5.500.000 đ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Thu: +8.000.000 đ',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Chi: -2.500.000 đ',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Giao dịch gần đây',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // Giao dịch mẫu thứ nhất
          const Card(
            child: ListTile(
              leading: Icon(Icons.restaurant),
              title: Text('Ăn sáng'),
              subtitle: Text('Nhóm: Ăn uống'),
              trailing: Text('-40.000 đ'),
            ),
          ),

          // Giao dịch mẫu thứ hai
          const Card(
            child: ListTile(
              leading: Icon(Icons.shopping_bag),
              title: Text('Mua sắm'),
              subtitle: Text('Nhóm: Mua sắm'),
              trailing: Text('-150.000 đ'),
            ),
          ),
        ],
      ),

      // Nút thêm giao dịch
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Chức năng thêm giao dịch sẽ làm ở bài tiếp theo!',
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm giao dịch'),
      ),
    );
  }
}
