import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ctrc/main.dart';

void main() {
  testWidgets('App renders sign in page', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CTRCApp()));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
