import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/main.dart';

void main() {
  testWidgets('App shows bottom navigation with 6 tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const IreneHelperApp());

    // Should show all 6 tab labels
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Exercise'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Skincare'), findsOneWidget);
  });
}
