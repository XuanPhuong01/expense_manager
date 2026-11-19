import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Du lieu OCR tra ve cho man hinh them giao dich (chua tu luu Firebase).
class ReceiptScanResult {
  const ReceiptScanResult({
    required this.amount,
    required this.recognizedText,
  });

  final int amount;
  final String recognizedText;
}

class _MoneyCandidate {
  const _MoneyCandidate({
    required this.amount,
    required this.rect,
    required this.line,
  });

  final int amount;
  final Rect rect;
  final TextLine line;
}

class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final TextEditingController _amountController = TextEditingController();

  String? _imagePath;
  String _recognizedText = '';
  bool _isProcessing = false;
  String _scanMessage = 'Hãy chọn một ảnh hóa đơn để nhận dạng.';

  @override
  void dispose() {
    _amountController.dispose();
    unawaited(_recognizer.close());
    super.dispose();
  }

  // Chuyển nhãn có dấu về không dấu để đối chiếu ổn định hơn.
  String _normalizeLabel(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[àáảãạăằắẳẵặâầấẩẫậ]'), 'a')
        .replaceAll(RegExp(r'[èéẻẽẹêềếểễệ]'), 'e')
        .replaceAll(RegExp(r'[ìíỉĩị]'), 'i')
        .replaceAll(RegExp(r'[òóỏõọôồốổỗộơờớởỡợ]'), 'o')
        .replaceAll(RegExp(r'[ùúủũụưừứửữự]'), 'u')
        .replaceAll(RegExp(r'[ỳýỷỹỵ]'), 'y')
        .replaceAll('đ', 'd');
  }

  // Xếp ưu tiên nhãn thanh toán; tuyệt đối không coi
  // "HÓA ĐƠN THANH TOÁN" là nhãn tổng tiền.
  int _labelPriority(String raw) {
    final text = _normalizeLabel(raw);
    if (text.contains('hoa don') ||
        text.contains('so hd') ||
        text.contains('giam gia') ||
        text.contains('chiet khau') ||
        text.contains('tien thua') ||
        text.contains('tien tra lai') ||
        text.contains('khach dua') ||
        text.contains('don gia')) {
      return 0;
    }

    if (RegExp(r't\s*\.\s*cong').hasMatch(text) ||
        text.contains('tong cong') ||
        text.contains('tong thanh toan') ||
        text.contains('tong tien') ||
        text.contains('phai tra') ||
        text.contains('thuc tra') ||
        text.contains('grand total') ||
        text.contains('amount due')) {
      return 5;
    }
    if (text.contains('tien mat')) return 4;
    if (text.contains('thanh toan') ||
        RegExp(r'\btotal\b').hasMatch(text)) {
      return 3;
    }
    return 0;
  }

  // Chỉ xét số tiền có dấu phân cách hàng nghìn (225,000 hoặc 225.000).
  // Không tự coi số hóa đơn 0002, giờ 235900 hay số lượng 2 là tiền.
  List<_MoneyCandidate> _extractMoney(List<TextLine> lines) {
    final moneyPattern = RegExp(r'\d{1,3}(?:[.,]\d{3})+');
    final digitPattern = RegExp(r'\d');
    final result = <_MoneyCandidate>[];

    void addMatches(String text, Rect rect, TextLine line) {
      for (final match in moneyPattern.allMatches(text)) {
        // Không lấy một phần của số dài hoặc chuỗi có dấu phân cách lạ.
        if (match.start > 0 &&
            digitPattern.hasMatch(text[match.start - 1])) {
          continue;
        }
        if (match.end < text.length &&
            digitPattern.hasMatch(text[match.end])) {
          continue;
        }
        final number = int.tryParse(
          match.group(0)!.replaceAll(RegExp(r'[.,]'), ''),
        );
        if (number != null && number >= 1000 && number <= 999999999999) {
          result.add(_MoneyCandidate(
            amount: number,
            rect: rect,
            line: line,
          ));
        }
      }
    }

    for (final line in lines) {
      // Phần tử (element) cho vị trí chính xác hơn cả dòng OCR.
      final before = result.length;
      for (final element in line.elements) {
        addMatches(element.text, element.boundingBox, line);
      }
      // Một số máy chia 225,000 thành nhiều element: dùng dòng dự phòng.
      if (result.length == before) {
        addMatches(line.text, line.boundingBox, line);
      }
    }
    return result;
  }

  // Ghép nhãn "T.Cộng"/"TIỀN MẶT" với con số ở CÙNG HÀNG trên ảnh.
  // ML Kit có thể đọc các cột theo thứ tự khác nhau trong recognized.text,
  // vì vậy không dựa vào "dòng tiếp theo" như phiên bản cũ.
  int? _suggestTotal(RecognizedText recognized) {
    final lines = <TextLine>[
      for (final block in recognized.blocks) ...block.lines,
    ];
    final amounts = _extractMoney(lines);
    if (amounts.isEmpty) return null;

    _MoneyCandidate? best;
    var bestScore = -1;

    for (final label in lines) {
      final priority = _labelPriority(label.text);
      if (priority == 0) continue;

      for (final candidate in amounts) {
        final sameLine = identical(candidate.line, label);
        final verticalGap =
            (candidate.rect.center.dy - label.boundingBox.center.dy).abs();
        final lineHeight = label.boundingBox.height > candidate.rect.height
            ? label.boundingBox.height
            : candidate.rect.height;
        final sameRow = verticalGap <= lineHeight * 0.75 + 7;
        if (!sameLine && !sameRow) continue;
        if (!sameLine && candidate.rect.right < label.boundingBox.left) {
          continue;
        }

        // Nhãn T.Cộng ưu tiên hơn "tiền mặt", giá trị cùng dòng/cùng hàng.
        final score = priority * 1000 +
            (sameLine ? 50 : 0) +
            (candidate.rect.center.dx > label.boundingBox.center.dx ? 15 : 0) -
            verticalGap.round();
        if (score > bestScore ||
            (score == bestScore &&
                (best == null || candidate.rect.right > best.rect.right))) {
          bestScore = score;
          best = candidate;
        }
      }
    }
    // Không có nhãn hợp lệ gắn với số tiền: để trống, không đoán bừa.
    return best?.amount;
  }

  bool get _canConfirm {
    final amount = int.tryParse(_amountController.text.trim());
    return !_isProcessing &&
        _recognizedText.isNotEmpty &&
        amount != null &&
        amount > 0 &&
        amount <= 999999999999;
  }

  Future<void> _pickAndRecognize(ImageSource source) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (!mounted || image == null) return;

      setState(() {
        _imagePath = image.path;
        _recognizedText = '';
        _scanMessage = '';
        _amountController.clear();
      });

      final inputImage = InputImage.fromFilePath(image.path);
      final recognized = await _recognizer.processImage(inputImage);
      if (!mounted) return;

      final text = recognized.text.trim();
      final suggestedAmount = _suggestTotal(recognized);
      setState(() {
        _recognizedText = text;
        if (suggestedAmount != null) {
          _amountController.text = suggestedAmount.toString();
          _scanMessage = 'Đã gợi ý tổng tiền. Hãy đối chiếu với ảnh trước khi lưu.';
        } else {
          _scanMessage = 'Chưa xác định chắc chắn tổng thanh toán. '
              'Vui lòng nhập số tiền theo hóa đơn.';
        }
      });

      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không đọc được chữ. Hãy thử ảnh rõ hơn.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể quét hóa đơn: $error')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _confirm() {
    final amount = int.tryParse(_amountController.text.trim());
    if (_recognizedText.isEmpty || amount == null || amount <= 0 ||
        amount > 999999999999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng kiểm tra ảnh và nhập số tiền hợp lệ.')),
      );
      return;
    }
    Navigator.of(context).pop(
      ReceiptScanResult(amount: amount, recognizedText: _recognizedText),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét hóa đơn OCR')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Chọn ảnh hóa đơn rõ nét. Ứng dụng sẽ đọc chữ và gợi ý số tiền; '
              'bạn luôn có thể sửa trước khi lưu.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickAndRecognize(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Chụp ảnh'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickAndRecognize(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Chọn ảnh'),
                  ),
                ),
              ],
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_imagePath != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_imagePath!),
                  height: 230,
                  fit: BoxFit.contain,
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              enabled: !_isProcessing,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Tổng tiền (VND) - kiểm tra lại',
                hintText: 'Ví dụ: 125000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _scanMessage,
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            const Text('Văn bản OCR:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(
              _recognizedText.isEmpty
                  ? 'Chưa có kết quả. Hãy chọn một ảnh hóa đơn.'
                  : _recognizedText,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _canConfirm ? _confirm : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Xác nhận kết quả OCR'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bước này chưa ghi vào Firestore. Kết quả sẽ được chuyển '
              'về màn hình Thêm giao dịch sau khi bạn xác nhận.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
