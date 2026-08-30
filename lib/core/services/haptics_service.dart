import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticsService {
  /// Short vibration for barcode scan match
  static Future<void> scanSuccess() async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 60);
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Success vibration pattern for audit completion / sale issuance
  static Future<void> actionSuccess() async {
    try {
      bool? hasCustom = await Vibration.hasCustomVibrationsSupport();
      if (hasCustom == true) {
        await Vibration.vibrate(pattern: [0, 80, 50, 120]);
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Warning vibration pattern for stock discrepancy / shortage
  static Future<void> warningDiscrepancy() async {
    try {
      bool? hasCustom = await Vibration.hasCustomVibrationsSupport();
      if (hasCustom == true) {
        await Vibration.vibrate(pattern: [0, 150, 100, 150]);
      } else {
        await HapticFeedback.vibrate();
      }
    } catch (_) {
      await HapticFeedback.vibrate();
    }
  }

  /// Error vibration
  static Future<void> error() async {
    try {
      bool? hasCustom = await Vibration.hasCustomVibrationsSupport();
      if (hasCustom == true) {
        await Vibration.vibrate(pattern: [0, 200, 100, 300]);
      } else {
        await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Light haptic feedback for button taps (Xiaomi X-axis motor optimized)
  static Future<void> lightImpact() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
