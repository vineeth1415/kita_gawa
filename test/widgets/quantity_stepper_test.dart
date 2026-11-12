import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_app/utils/validators.dart';
import 'package:inventory_app/widgets/quantity_stepper.dart';

/// Regression cover for the quantity field.
///
/// The validator used to live on a separate, deliberately-invisible
/// TextFormField styled with `fontSize: 0`. That tripped a Flutter assertion
/// (`fontSize == null || fontSize > 0`) and crashed the screen the moment it
/// was opened on a device. It now sits on the stepper's own field, and these
/// tests render the widget so a repeat would fail here rather than in
/// someone's hands.
void main() {
  Widget host(Widget child, {GlobalKey<FormState>? formKey}) => MaterialApp(
    home: Scaffold(
      body: Form(key: formKey, child: child),
    ),
  );

  testWidgets('renders without tripping a paint-time assertion', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(QuantityStepper(controller: controller)));

    expect(tester.takeException(), isNull);
    expect(find.text('1'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });

  testWidgets('the plus and minus buttons change the value', (tester) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(QuantityStepper(controller: controller)));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(controller.text, '2');

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(controller.text, '1');
  });

  testWidgets('will not step below the minimum', (tester) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(QuantityStepper(controller: controller)));

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(controller.text, '1', reason: 'min defaults to 1');
  });

  testWidgets('will not step above a max, as dispatch sets it', (
    tester,
  ) async {
    final controller = TextEditingController(text: '4');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(QuantityStepper(controller: controller, max: 5)),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(controller.text, '5');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(controller.text, '5', reason: 'capped at the available stock');
  });

  testWidgets('surfaces a validation message on the visible field', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        QuantityStepper(
          controller: controller,
          validator: validatePositiveQuantity,
        ),
        formKey: formKey,
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Quantity must be greater than zero'), findsOneWidget);

    controller.text = '3';
    expect(formKey.currentState!.validate(), isTrue);
  });
}
