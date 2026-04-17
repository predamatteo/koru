import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/app.dart';

void main() {
  testWidgets('KoruApp boots and shows app name', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KoruApp()));
    await tester.pumpAndSettle();
    expect(find.text('Koru'), findsOneWidget);
  });
}
