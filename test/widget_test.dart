import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BoardGameApp());
    expect(find.text('ARCHEON'), findsOneWidget);
  });
}
