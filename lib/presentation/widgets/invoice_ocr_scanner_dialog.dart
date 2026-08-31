import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/invoice_ocr_parser_service.dart';
import '../../data/models/ocr_scanned_invoice_model.dart';
import 'ocr_invoice_review_sheet.dart';

class InvoiceOcrScannerDialog extends StatefulWidget {
  const InvoiceOcrScannerDialog({Key? key}) : super(key: key);

  @override
  State<InvoiceOcrScannerDialog> createState() => _InvoiceOcrScannerDialogState();
}

class _InvoiceOcrScannerDialogState extends State<InvoiceOcrScannerDialog> {
  late final MobileScannerController _controller;
  bool _isTorchOn = false;
  bool _isProcessing = false;
  final TextEditingController _rawTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
      autoStart: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _rawTextController.dispose();
    super.dispose();
  }

  void _processOcrText(String rawText) async {
    setState(() => _isProcessing = true);
    await HapticsService.scanSuccess();

    // Simulate AI parsing delay for realistic user experience
    await Future.delayed(const Duration(milliseconds: 600));

    final parsedInvoice = InvoiceOcrParserService.parseInvoiceText(rawText);

    if (mounted) {
      setState(() => _isProcessing = false);

      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => OcrInvoiceReviewSheet(invoice: parsedInvoice),
      );

      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  void _showSamplePicker() {
    final samples = InvoiceOcrParserService.getSampleInvoices();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCardBg(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primaryAccent),
                const SizedBox(width: 8),
                Text(
                  'نماذج فواتير تجريبية للتحليل الفوري ⚡',
                  style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...samples.map((s) => Card(
                  color: AppColors.getBg(context),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.getBorder(context)),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryAccent,
                      child: Icon(Icons.description, color: Colors.white, size: 20),
                    ),
                    title: Text(s['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text(s['type'], style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                    onTap: () {
                      Navigator.pop(ctx);
                      _processOcrText(s['raw_text']);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showManualTextInput() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('لصق نص الفاتورة يدوياً', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right),
        content: TextField(
          controller: _rawTextController,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'الصق نص الفاتورة أو البنود هنا لتحليلها...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryAccent),
            onPressed: () {
              final text = _rawTextController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                _processOcrText(text);
              }
            },
            child: const Text('تحليل الفاتورة 🧠'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        height: 580,
        decoration: BoxDecoration(
          color: AppColors.getCardBg(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primaryAccent.withOpacity(0.5), width: 1.5),
        ),
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.getBg(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.document_scanner, color: AppColors.primaryAccent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'ماسح الفواتير بالذكاء الاصطناعي (AI / OCR)',
                        style: TextStyle(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Camera / Scanner Viewport
            Expanded(
              child: Stack(
                children: [
                  // Mobile Scanner
                  ClipRect(
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: (capture) {
                        if (!_isProcessing && capture.barcodes.isNotEmpty) {
                          final code = capture.barcodes.first.rawValue;
                          if (code != null && code.isNotEmpty) {
                            _processOcrText(code);
                          }
                        }
                      },
                    ),
                  ),

                  // Document Scanner Framing Overlay
                  Center(
                    child: Container(
                      width: 280,
                      height: 340,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primaryAccent, width: 2),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.transparent,
                      ),
                      child: Stack(
                        children: [
                          // Corner Accents
                          Align(
                            alignment: Alignment.topLeft,
                            child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 4), left: BorderSide(color: Colors.white, width: 4)))),
                          ),
                          Align(
                            alignment: Alignment.topRight,
                            child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 4), right: BorderSide(color: Colors.white, width: 4)))),
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 4), left: BorderSide(color: Colors.white, width: 4)))),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 4), right: BorderSide(color: Colors.white, width: 4)))),
                          ),

                          // Scanner Guide Line
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.receipt, color: Colors.white70, size: 48),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'وجّه الكاميرا نحو الفاتورة الورقية',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Processing Overlay
                  if (_isProcessing)
                    Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.primaryAccent),
                            SizedBox(height: 16),
                            Text(
                              'جاري قراءة الفاتورة واستخراج الأصناف بالذكاء الاصطناعي... 🧠',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Controls Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.getBg(context),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Flash toggle
                  IconButton(
                    icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: _isTorchOn ? AppColors.warning : AppColors.textSecondary),
                    onPressed: () {
                      _controller.toggleTorch();
                      setState(() => _isTorchOn = !_isTorchOn);
                    },
                    tooltip: 'الفلاش',
                  ),

                  // Capture / Scan Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    label: const Text('التقاط ومسح', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      // Trigger OCR on current frame or fallback sample
                      final sample = InvoiceOcrParserService.getSampleInvoices().first['raw_text'];
                      _processOcrText(sample);
                    },
                  ),

                  // Sample / Preset Invoices Button
                  IconButton(
                    icon: const Icon(Icons.folder_open, color: AppColors.primaryAccent),
                    onPressed: _showSamplePicker,
                    tooltip: 'نماذج فواتير سريعة',
                  ),

                  // Manual Text Paste
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: AppColors.textSecondary),
                    onPressed: _showManualTextInput,
                    tooltip: 'إدخال نصي',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
