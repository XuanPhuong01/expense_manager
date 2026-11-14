import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/transaction_model.dart';

// Man hinh thong ke su dung du lieu giao dich that tu Firestore.
// Khong tinh initialBalance thanh thu nhap trong thang.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const _blue = Color(0xFF4361EE);
  static const _green = Color(0xFF139B72);
  static const _red = Color(0xFFE65A67);
  static const _ink = Color(0xFF19243A);
  static const _muted = Color(0xFF718096);
  static const _background = Color(0xFFF4F7FF);
  static const _categoryColors = <Color>[
    Color(0xFF5474F5),
    Color(0xFFF5A34B),
    Color(0xFF20B69A),
    Color(0xFFAD7CF5),
    Color(0xFFEF718B),
    Color(0xFF5AB6CE),
  ];

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedWalletId;

  String _money(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '${negative ? '-' : ''}$grouped ₫';
  }

  void _changeMonth(int months) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + months,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập để xem thống kê.')),
      );
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final start = DateTime(_selectedMonth.year, _selectedMonth.month);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1);

    // Chi truy van giao dich trong thang, khong doc toan bo lich su.
    final transactionsStream = userRef
        .collection('transactions')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .snapshots();

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Thống kê thu chi', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: userRef.collection('wallets').snapshots(),
        builder: (context, walletsSnapshot) {
          if (walletsSnapshot.hasError) {
            return const Center(child: Text('Không thể tải danh sách ví.'));
          }
          if (!walletsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final wallets = walletsSnapshot.data!.docs;
          final chosenWalletId = _selectedWalletId != null &&
                  wallets.any((wallet) => wallet.id == _selectedWalletId)
              ? _selectedWalletId
              : null;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: transactionsStream,
            builder: (context, transactionsSnapshot) {
              if (transactionsSnapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Không thể tải thống kê. Hãy kiểm tra mạng và quyền Firestore.'),
                  ),
                );
              }
              if (!transactionsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = <MoneyTransaction>[];
              for (final doc in transactionsSnapshot.data!.docs) {
                try {
                  final item = MoneyTransaction.fromDocument(doc);
                  if (chosenWalletId == null || item.walletId == chosenWalletId) {
                    items.add(item);
                  }
                } catch (_) {
                  // Bo qua document sai cau truc; khong lam hong ca man hinh.
                }
              }
              final report = _MonthlyReport.fromTransactions(items);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                children: [
                  _buildFilters(wallets, chosenWalletId),
                  const SizedBox(height: 18),
                  _buildHero(report),
                  const SizedBox(height: 18),
                  _buildWeeklyCard(report),
                  const SizedBox(height: 18),
                  _buildCategoryCard(report),
                  const SizedBox(height: 18),
                  _buildInsights(report),
                  const SizedBox(height: 12),
                  const Text(
                    'Lưu ý: Chênh lệch thu − chi trong tháng không phải là số dư ví. '
                    'Số dư ban đầu của ví không được tính vào tổng thu.',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> wallets,
    String? chosenWalletId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TỔNG QUAN', style: TextStyle(
          color: _muted, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 12,
        )),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Tháng trước',
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        'Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tháng sau',
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: chosenWalletId ?? 'all',
                    style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Tất cả ví', overflow: TextOverflow.ellipsis)),
                      ...wallets.map((doc) => DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              doc.data()['name'] as String? ?? 'Ví',
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedWalletId = value == 'all' ? null : value);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHero(_MonthlyReport report) {
    final difference = report.income - report.expense;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D3276), Color(0xFF4361EE)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: _blue.withValues(alpha: 0.20), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_graph_rounded, color: Color(0xFFB8C7FF), size: 18),
              SizedBox(width: 8),
              Text('CHÊNH LỆCH THU − CHI', style: TextStyle(
                color: Color(0xFFD7E0FF), fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w600,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${difference > 0 ? '+' : ''}${_money(difference)}',
            style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text('Tổng thu trừ tổng chi trong kỳ',
              style: TextStyle(color: Color(0xFFC9D6FF), fontSize: 12)),
          const SizedBox(height: 18),
          const Divider(color: Color(0x55FFFFFF), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _heroMetric('TỔNG THU', _money(report.income), Icons.south_west, const Color(0xFFA6F0CD))),
              const SizedBox(width: 10),
              Expanded(child: _heroMetric('TỔNG CHI', _money(report.expense), Icons.north_east, const Color(0xFFFFC1C9))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String label, String value, IconData icon, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Color(0xFFD7E0FF), fontSize: 11)),
        ]),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _buildWeeklyCard(_MonthlyReport report) {
    final maxValue = math.max(
      1,
      math.max(
        report.weeklyIncome.reduce(math.max),
        report.weeklyExpense.reduce(math.max),
      ),
    );
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading('Dòng tiền theo tuần', Icons.bar_chart_rounded),
          const SizedBox(height: 4),
          const Text('So sánh thu và chi theo từng khoảng 7 ngày',
              style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(5, (i) {
              final inValue = report.weeklyIncome[i];
              final outValue = report.weeklyExpense[i];
              return Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 112,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _bar(inValue, maxValue, _green),
                          const SizedBox(width: 5),
                          _bar(outValue, maxValue, _red),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Tuần ${i + 1}', style: const TextStyle(color: _muted, fontSize: 10)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 15),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legendDot(_green, 'Thu'),
            const SizedBox(width: 20),
            _legendDot(_red, 'Chi'),
          ]),
        ],
      ),
    );
  }

  Widget _bar(int value, int maxValue, Color color) {
    final height = value == 0 ? 5.0 : math.max(8.0, 104 * value / maxValue);
    return Tooltip(
      message: _money(value),
      child: Container(
        width: 15,
        height: height,
        decoration: BoxDecoration(
          color: value == 0 ? color.withValues(alpha: 0.16) : color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String name) {
    return Row(children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(name, style: const TextStyle(color: _muted, fontSize: 12)),
    ]);
  }

  Widget _buildCategoryCard(_MonthlyReport report) {
    final entries = report.categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading('Chi tiêu theo danh mục', Icons.donut_large_rounded),
          const SizedBox(height: 4),
          const Text('Danh mục chi nhiều nhất được xếp lên đầu',
              style: TextStyle(color: _muted, fontSize: 12)),
          if (entries.isEmpty) ...[
            const SizedBox(height: 20),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('Chưa có khoản chi trong kỳ này',
                    style: TextStyle(color: _muted)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 18),
            Center(
              child: SizedBox(
                width: 168,
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(168, 168),
                      painter: _DonutPainter(
                        amounts: entries.map((e) => e.value).toList(),
                        colors: List.generate(entries.length, (i) => _categoryColors[i % _categoryColors.length]),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Tổng chi', style: TextStyle(color: _muted, fontSize: 11)),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(_money(report.expense),
                              style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < entries.length; i++) ...[
              _categoryRow(
                entries[i].key,
                entries[i].value,
                report.expense,
                _categoryColors[i % _categoryColors.length],
              ),
              if (i != entries.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(String category, int value, int total, Color color) {
    final ratio = total == 0 ? 0.0 : value / total;
    return Column(
      children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Text(_money(value), style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('${(ratio * 100).round()}%', style: const TextStyle(color: _muted, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: const Color(0xFFEDF1F7),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildInsights(_MonthlyReport report) {
    String insight;
    if (report.count == 0) {
      insight = 'Chưa có giao dịch trong tháng này. Hãy thêm một khoản thu hoặc chi để xem phân tích.';
    } else if (report.income == 0 && report.expense > 0) {
      insight = 'Bạn đã ghi nhận ${_money(report.expense)} tiền chi, nhưng chưa có khoản thu nào trong kỳ.';
    } else if (report.expense == 0) {
      insight = 'Tháng này có ${_money(report.income)} tiền thu và chưa ghi nhận khoản chi nào.';
    } else {
      final ratio = (report.expense / report.income * 100).round();
      final biggest = report.categories.entries.reduce((a, b) => a.value >= b.value ? a : b);
      insight = 'Chi tiêu bằng $ratio% khoản thu đã ghi nhận. Danh mục chi nhiều nhất là ${biggest.key} (${_money(biggest.value)}).';
    }
    return _panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF2D9), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFBF7D10)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Góc nhìn nhanh',
                    style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(insight, style: const TextStyle(color: _muted, height: 1.5, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String text, IconData icon) {
    return Row(children: [
      Icon(icon, size: 20, color: _blue),
      const SizedBox(width: 9),
      Expanded(child: Text(text,
          style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800))),
    ]);
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(
          color: Color(0x0B213A72), blurRadius: 16, offset: Offset(0, 5),
        )],
      ),
      child: child,
    );
  }
}

class _MonthlyReport {
  _MonthlyReport({
    required this.income,
    required this.expense,
    required this.count,
    required this.categories,
    required this.weeklyIncome,
    required this.weeklyExpense,
  });

  final int income;
  final int expense;
  final int count;
  final Map<String, int> categories;
  final List<int> weeklyIncome;
  final List<int> weeklyExpense;

  factory _MonthlyReport.fromTransactions(List<MoneyTransaction> items) {
    var income = 0;
    var expense = 0;
    final categories = <String, int>{};
    final weeklyIncome = List<int>.filled(5, 0);
    final weeklyExpense = List<int>.filled(5, 0);

    for (final item in items) {
      if (item.amount <= 0) continue;
      final week = math.min(4, ((item.createdAt?.toLocal().day ?? 1) - 1) ~/ 7);
      if (item.isIncome) {
        income += item.amount;
        weeklyIncome[week] += item.amount;
      } else if (item.isExpense) {
        expense += item.amount;
        weeklyExpense[week] += item.amount;
        final category = item.category.trim().isEmpty ? 'Khác' : item.category;
        categories[category] = (categories[category] ?? 0) + item.amount;
      }
    }

    return _MonthlyReport(
      income: income,
      expense: expense,
      count: items.length,
      categories: categories,
      weeklyIncome: weeklyIncome,
      weeklyExpense: weeklyExpense,
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.amounts, required this.colors});

  final List<int> amounts;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2 - 12);
    final total = amounts.fold<int>(
  0,
  (currentTotal, value) => currentTotal + value,
);
    final basePaint = Paint()
      ..color = const Color(0xFFECF0F8)
      ..strokeWidth = 17
      ..style = PaintingStyle.stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, basePaint);
    if (total == 0) return;

    var start = -math.pi / 2;
    for (var i = 0; i < amounts.length; i++) {
      final sweep = 2 * math.pi * amounts[i] / total;
      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = 17
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}
