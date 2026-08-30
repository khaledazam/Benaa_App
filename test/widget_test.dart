import 'package:flutter_test/flutter_test.dart';
import 'package:benaa_flutter_mobile/main.dart';

void main() {
  testWidgets('Benaa Inventory App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BenaaInventoryApp());
    expect(find.byType(BenaaInventoryApp), findsOneWidget);
  });
}
