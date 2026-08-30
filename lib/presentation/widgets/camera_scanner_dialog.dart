import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/notification_service.dart';

class CameraScannerDialog extends StatefulWidget {
  final String title;

  const CameraScannerDialog({
    Key? key,
    this.title = 'مسح الباركود بالكاميرا',
  }) : super(key: key);

  @override
  State<CameraScannerDialog> createState() => _CameraScannerDialogState();
}

class _CameraScannerDialogState extends State<CameraScannerDialog> {
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
      autoStart: true,
    );
  }

  bool _isScanned = false;
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String code = barcodes.first.rawValue!;
      setState(() {
        _isScanned = true;
      });

      // Trigger Android hardware vibration
      await HapticsService.scanSuccess();

      // Trigger local Android notification
      await NotificationService.showScanNotification(
        barcode: code,
        itemName: 'صنف تم مسحه ضوئياً',
        statusText: 'تم الكشف بواسطة كاميرا الموبايل بنجاح',
      );

      if (mounted) {
        Navigator.pop(context, code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            // Header with flashlight and camera flip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, state, child) {
                        return IconButton(
                          icon: Icon(
                            state.torchState == TorchState.on
                                ? Icons.flash_on
                                : Icons.flash_off,
                            color: state.torchState == TorchState.on
                                ? Colors.amber
                                : AppColors.textSecondary,
                          ),
                          onPressed: () => _controller.toggleTorch(),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cameraswitch, color: AppColors.textSecondary),
                      onPressed: () => _controller.switchCamera(),
                    ),
                  ],
                ),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Camera Viewfinder Box
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error, child) {
                        return Container(
                          color: Colors.black87,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.camera_alt_outlined, color: AppColors.warning, size: 48),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'يرجى تفعيل إذن الكاميرا في إعدادات الهاتف لاستخدام مسح الباركود',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('إعادة تشغيل الكاميرا'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryAccent,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                    onPressed: () => _controller.start(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Target Viewfinder Frame Overlay
                    Container(
                      width: 220,
                      height: 160,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primaryAccent, width: 2.5),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Container(
                              height: 2,
                              color: AppColors.danger.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.qr_code_scanner, color: AppColors.success, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'وجه الكاميرا نحو الباركود',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Manual fallback input
            Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    final val = _manualController.text.trim();
                    if (val.isNotEmpty) {
                      HapticsService.scanSuccess();
                      Navigator.pop(context, val);
                    }
                  },
                  child: const Text('إدخال'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _manualController,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'أو اكتب الباركود يدوياً...',
                      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
