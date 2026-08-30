import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/bluetooth_printer_service.dart';

class PrinterSelectionDialog extends StatefulWidget {
  const PrinterSelectionDialog({Key? key}) : super(key: key);

  @override
  State<PrinterSelectionDialog> createState() => _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<PrinterSelectionDialog> {
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isLoading = true;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() async {
    setState(() => _isLoading = true);
    final devices = await BluetoothPrinterService.getPairedDevices();
    final connected = await BluetoothPrinterService.isConnected();
    setState(() {
      _devices = devices;
      _isConnected = connected;
      _isLoading = false;
    });
  }

  void _connectDevice(BluetoothDevice device) async {
    setState(() => _isLoading = true);
    bool success = await BluetoothPrinterService.connect(device);
    setState(() {
      _selectedDevice = device;
      _isConnected = success;
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? AppColors.success : AppColors.danger,
          content: Text(
            success
                ? 'تم الاتصال بطابعة البلوتوث الحرارية (${device.name}) بنجاح!'
                : 'تعذر الاتصال بالطابعة، تأكد من تشغيل البلوتوث بالطابعة.',
          ),
        ),
      );
      if (success) {
        Navigator.pop(context, true);
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
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        height: 420,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.print, color: AppColors.primaryAccent),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? AppColors.success.withOpacity(0.2)
                            : AppColors.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isConnected ? 'متصل بالطابعة' : 'غير متصل',
                        style: TextStyle(
                          color: _isConnected ? AppColors.success : AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'طابعة البلوتوث المحمولة',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const Divider(color: AppColors.borderDark, height: 20),

            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primaryAccent),
                ),
              )
            else if (_devices.isEmpty)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'لم يتم العثور على طابعات بلوتوث مقترنة بالهاتف.\nيرجى اقتران الطابعة من إعدادات بلوتوث الهاتف أولاً.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (ctx, idx) {
                    final dev = _devices[idx];
                    return Card(
                      color: AppColors.bgDark,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _selectedDevice == dev
                              ? AppColors.primaryAccent
                              : AppColors.borderDark,
                        ),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.bluetooth_connected, color: AppColors.primaryAccent),
                        title: Text(
                          dev.name ?? 'طابعة حرارية غير معروفة',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        subtitle: Text(
                          dev.address ?? '',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () => _connectDevice(dev),
                          child: const Text('اتصال'),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('إعادة البحث'),
                  onPressed: _loadDevices,
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
