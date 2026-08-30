import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/nfc_service.dart';

class NfcScannerDialog extends StatefulWidget {
  const NfcScannerDialog({Key? key}) : super(key: key);

  @override
  State<NfcScannerDialog> createState() => _NfcScannerDialogState();
}

class _NfcScannerDialogState extends State<NfcScannerDialog> {
  String _statusMessage = 'قرب هاتف الاندرويد من شريحة الـ NFC أو الباليت...';
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _startNfcListening();
  }

  @override
  void dispose() {
    NfcService.stopNfcScan();
    super.dispose();
  }

  void _startNfcListening() async {
    await NfcService.startNfcScan(
      onTagDiscovered: (code) {
        if (mounted) {
          setState(() {
            _statusMessage = 'تم كشف الشريحة: $code';
            _isScanning = false;
          });
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              Navigator.pop(context, code);
            }
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _statusMessage = err;
            _isScanning = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
      ),
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.nfc, color: AppColors.primaryAccent, size: 28),
                const Text(
                  'قارئ شريحة NFC / RFID للباليتات',
                  style: TextStyle(
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

            const SizedBox(height: 24),

            // Animated Radar / Contactless Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryAccent.withOpacity(0.15),
                border: Border.all(color: AppColors.primaryAccent, width: 2),
              ),
              child: const Icon(
                Icons.contactless,
                size: 56,
                color: AppColors.primaryAccent,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              _statusMessage,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            if (_isScanning)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryAccent,
                ),
              ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'إلغاء المسح',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
