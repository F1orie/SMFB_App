import 'package:flutter_test/flutter_test.dart';

import 'package:smf_app/app/main.dart';

void main() {
  testWidgets('Alarm shell smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmfApp());

    expect(find.text('アラーム設定'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('データ'), findsNothing);

    await tester.tap(find.text('グラフ'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('データ'), findsOneWidget);
  });
}
