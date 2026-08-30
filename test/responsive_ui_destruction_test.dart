import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:benaa_flutter_mobile/presentation/providers/inventory_provider.dart';
import 'package:benaa_flutter_mobile/presentation/providers/theme_provider.dart';
import 'package:benaa_flutter_mobile/presentation/screens/dashboard_screen.dart';
import 'package:benaa_flutter_mobile/presentation/screens/local_stock_screen.dart';
import 'package:benaa_flutter_mobile/presentation/screens/sales_issuance_screen.dart';
import 'package:benaa_flutter_mobile/presentation/screens/transfers_list_screen.dart';
import 'package:benaa_flutter_mobile/presentation/screens/returns_management_screen.dart';
import 'package:benaa_flutter_mobile/presentation/screens/stock_audit_screen.dart';
import 'package:benaa_flutter_mobile/presentation/screens/sync_manager_screen.dart';
import 'package:benaa_flutter_mobile/presentation/widgets/customer_payment_dialog.dart';
import 'package:benaa_flutter_mobile/presentation/widgets/customer_statement_dialog.dart';
import 'package:benaa_flutter_mobile/presentation/widgets/absher_hawsu_dialog.dart';
import 'package:benaa_flutter_mobile/presentation/widgets/packaging_unit_converter_dialog.dart';

Widget createTestApp(
  Widget child, {
  Size size = const Size(360, 800),
  TextDirection textDirection = TextDirection.rtl,
  double textScale = 1.0,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => InventoryProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: textDirection,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaleFactor: textScale,
            viewInsets: viewInsets,
          ),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const viewports = {
    'Small Phone (320x568)': Size(320, 568),
    'Standard Phone (360x800)': Size(360, 800),
    'Large Phone (390x844)': Size(390, 844),
    'Large Android (412x915)': Size(412, 915),
    'Tablet (600x960)': Size(600, 960),
    'Large Tablet (800x1280)': Size(800, 1280),
    'Landscape Phone (800x360)': Size(800, 360),
    'Landscape Tablet (1280x800)': Size(1280, 800),
  };

  group('Benaa Flutter — Multi-Viewport Responsive UI Destruction Tests', () {
    for (var entry in viewports.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('Viewport: $name — DashboardScreen', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? errorDetails;
        final origOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errorDetails = details;
        };

        await tester.pumpWidget(createTestApp(const DashboardScreen(), size: size));
        await tester.pumpAndSettle();

        FlutterError.onError = origOnError;
        if (errorDetails != null) {
          debugPrint('DEBUG ERROR DIAGNOSTICS:\n${errorDetails?.toDiagnosticsNode().toStringDeep()}');
        }

        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Viewport: $name — LocalStockScreen', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestApp(const LocalStockScreen(), size: size));
        await tester.pumpAndSettle();

        expect(find.byType(LocalStockScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Viewport: $name — SalesIssuanceScreen', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestApp(const SalesIssuanceScreen(), size: size));
        await tester.pumpAndSettle();

        expect(find.byType(SalesIssuanceScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Viewport: $name — TransfersListScreen', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestApp(const TransfersListScreen(), size: size));
        await tester.pumpAndSettle();

        expect(find.byType(TransfersListScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Viewport: $name — ReturnsManagementScreen', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestApp(const ReturnsManagementScreen(), size: size));
        await tester.pumpAndSettle();

        expect(find.byType(ReturnsManagementScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Viewport: $name — StockAuditScreen', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestApp(const StockAuditScreen(), size: size));
        await tester.pumpAndSettle();

        expect(find.byType(StockAuditScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Viewport: $name — SyncManagerScreen', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestApp(const SyncManagerScreen(), size: size));
        await tester.pumpAndSettle();

        expect(find.byType(SyncManagerScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Responsive Dialog: CustomerPaymentDialog at 320x568', (tester) async {
      const smallSize = Size(320, 568);
      tester.view.physicalSize = smallSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog(context: ctx, builder: (_) => const CustomerPaymentDialog()),
                child: const Text('Open Payment'),
              ),
            ),
          ),
        ),
        size: smallSize,
      ));
      await tester.tap(find.text('Open Payment'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerPaymentDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive Dialog: CustomerStatementDialog at 320x568', (tester) async {
      const smallSize = Size(320, 568);
      tester.view.physicalSize = smallSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog(context: ctx, builder: (_) => const CustomerStatementDialog()),
                child: const Text('Open Statement'),
              ),
            ),
          ),
        ),
        size: smallSize,
      ));
      await tester.tap(find.text('Open Statement'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerStatementDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive Dialog: AbsherHawsuDialog at 320x568', (tester) async {
      const smallSize = Size(320, 568);
      tester.view.physicalSize = smallSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog(context: ctx, builder: (_) => const AbsherHawsuDialog()),
                child: const Text('Open Absher'),
              ),
            ),
          ),
        ),
        size: smallSize,
      ));
      await tester.tap(find.text('Open Absher'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AbsherHawsuDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive Dialog: PackagingUnitConverterDialog at 320x568', (tester) async {
      const smallSize = Size(320, 568);
      tester.view.physicalSize = smallSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog(context: ctx, builder: (_) => const PackagingUnitConverterDialog(items: [])),
                child: const Text('Open Converter'),
              ),
            ),
          ),
        ),
        size: smallSize,
      ));
      await tester.tap(find.text('Open Converter'));
      await tester.pumpAndSettle();

      expect(find.byType(PackagingUnitConverterDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Keyboard Pop-up Simulation (bottom insets: 320px)', (tester) async {
      const size = Size(360, 800);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        const SalesIssuanceScreen(),
        size: size,
        viewInsets: const EdgeInsets.only(bottom: 320),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SalesIssuanceScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Font Scale Accessibility Test (textScaleFactor: 1.5)', (tester) async {
      const size = Size(360, 800);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        const DashboardScreen(),
        size: size,
        textScale: 1.5,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LTR / English Directionality Test', (tester) async {
      const size = Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        const DashboardScreen(),
        size: size,
        textDirection: TextDirection.ltr,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
