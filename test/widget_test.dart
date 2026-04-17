import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koru/app.dart';

void main() {
  testWidgets('KoruApp boots and shows Home tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KoruApp()));
    await tester.pumpAndSettle();
    // Home tab è initial location; la AppBar mostra "Home"
    expect(find.text('Home'), findsWidgets);
  });
}
