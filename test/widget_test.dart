import 'package:flutter_test/flutter_test.dart';

import 'package:smf_app/app/main.dart';

void main() {
  testWidgets('Alarm shell smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmfApp());

    expect(find.text('アラーム設定'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('データ'), findsNothing);

    await tester.tap(find.text('グラフ'));
    await tester.pumpAndSettle();

    expect(find.text('データ'), findsOneWidget);
    expect(find.text('23:58'), findsOneWidget);
  });
}
