import 'package:balance/core/shared_widgets/password_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('password starts hidden and the eye button toggles it', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'secret123');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PasswordField(controller: controller)),
      ),
    );

    bool obscured() =>
        tester.widget<TextField>(find.byType(TextField)).obscureText;

    expect(obscured(), isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(), isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(obscured(), isTrue);
    expect(controller.text, 'secret123');
  });

  testWidgets('the eye button meets the 48 px touch target', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PasswordField(controller: controller)),
      ),
    );
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });
}
